#!/bin/sh
#  -*-tcl-*-\
exec wish "$0" ${1:+"$@"}

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# Pre-compute signal shapes in a directory tree
# Syntax:
#  ComputeShape.tcl $path [-shp $shp_path]
# For each sound signal in the directory or any subdirectory,
# compute the shape and store it in $shp_path (default to /var/tmp)

# Load Snack & Transcriber libraries
set base [file dir [file dir [file join [pwd] [info script]]]]
lappend auto_path $base [file dir $base]
set vsnack [package require snack]
if {[package vcompare $vsnack 1.7] < 0} {
  error "Found Snack package version $vsnack; needs 1.7 or higher"
}
catch {
  package require snacksphere
}
catch {
  package require snackogg
}
package require trans 1.5

# Default path for looking for sound files
set path "."

# List of authorized sound extensions
set exts {".au" ".wav" ".snd" ".sph" ".sig" ".sd" ".smp" ".aif" ".aiff" ".mp3" ".raw" ".ogg"}

# Default path for storing shapes
set shp_path "/var/tmp"

# Process sound files
proc Process {path} {
  global exts

  puts "Computing shapes within directory $path:"
  foreach file [lsort [glob [file join $path *]]] {
    if {[file isdirectory $file]} {
      Process $file
      continue
    }
    set ext [file extension $file]
    set type [SoundFileType $file]
    if {[lsearch -exact $exts $ext] >= 0 || $type != "RAW"} {
      set snd [sound -file $file]
      set shapeName [LookForShape $file]
      set shp [sound -file $shapeName \
		   -frequency 100 -channels 2 -format LIN8]
      if {![$snd shape $shp -check 1]} {
	puts " + $file ($type)"
	$snd shape $shp -format MULAW
	$shp write $shapeName -fileformat WAV
      }
      $snd destroy
      $shp destroy
    }
  }
}

# Sound file type according to Snack automatic detection (RAW, WAV,...)
proc SoundFileType {fileName} {
  if {[catch {
    set s [sound -file $fileName]
    set t [lindex [$s info] 6]
    $s destroy
  }]} {
    set t "RAW"
  }
  return $t
}

proc LookForShape {sigName} {
  global v
  
  set base [file root [file tail $sigName]]
  set ext "shape"
  
  # Search for an existing matching shape
  # (in default dir, shp sub-dir or signal dir)
  foreach path [concat $::shp_path "shp ../shp ."] {
    # Relative paths are relative to signal path
    set path [file join [file dirname $sigName] $path]
    set shape [file join $path $base.$ext]
    # Verify that the shape is newer than the signal
    if {[file isfile $shape] && [file readable $shape] 
	&& [file mtime $shape] >= [file mtime $sigName]} {
      return $shape
    }
  }
  # Return new shape name in default shape path
  set shape [file join $::shp_path $base.$ext]
  file delete $shape
  return $shape
}

# Parse line arguments
for {set i 0} {$i < [llength $argv]} {incr i} {
  set val [lindex $argv $i]
  switch -glob -- $val {
    "-shp" {
      set shp_path [lindex $argv [incr i]]
    }
    "-*" {
      return -code error "unsupported command line option $val"
    }
    default {
      set path $val
    }
  }
}

Process $path
exit
