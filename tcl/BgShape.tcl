#!/bin/sh
#  -*-tcl-*-\
exec wish "$0" ${1:+"$@"}

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

###############################################################

# Syntax: BgShape.tcl $signal_name $shape_name
# returns $shape_name if it succeeds, else the error message

# This script is launched as a background sub-process and computes a
# min/max shape at a centi-second scale of the whole signal in order
# to make signal display at low resolutions go faster within Transcriber.

# load snack and trans packages.
set base [file dir [file dir [info script]]]
lappend auto_path $base [file dir $base]
set vsnack [package require snack]
if {[package vcompare $vsnack 1.7] < 0} {
  error "Found Snack package version $vsnack; needs 1.7 or higher"
}
catch {
  package require snacksphere
}
package require trans 1.5

proc Main {sigName shapeName {rate 16000} {channels 1} {header 0}} {
  sound s -file $sigName -guessproperties 1 -frequency $rate -channels $channels -skiphead $header
  sound shp
  s shape shp -format MULAW
  shp write $shapeName -fileformat WAV
  puts $shapeName
  #exit
  destroy .
}

eval Main $argv
