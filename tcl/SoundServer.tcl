#!/bin/sh
#  -*-tcl-*-\
exec wish8.0 "$0" ${1:+"$@"}

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# Sound file server through sockets
#
# Syntax :
#    SoundServer.tcl [server_port]
#
# Action :
#    Open sound file and dialog with client through sockets, returning
#    result of sound commands along with error flag.

# Get libraries
set base [file dir [file dir [file join [pwd] [info script]]]]
lappend auto_path $base [file dir $base]
set vsnack [package require snack]
if {[package vcompare $vsnack 1.7] < 0} {
  error "Found Snack package version $vsnack; needs 1.7 or higher"
}
catch {
  # in Snack 1.7, snackSphere package was renamed snacksphere
  package require snacksphere
}
#package require trans 1.5

# Default port
set port 8032

# Default path for storing shapes
set shp_path "/var/tmp"

# Authorized signal base pathname
set basename "/data/sounds"

# List of authorized sound extensions
set exts {".au" ".wav" ".snd" ".sph" ".sig" ".sd" ".smp" ".aif" ".aiff" ".mp3" ".raw"}

# Debug mode
set debug 0

# For header dump
sound header

# Socket server
proc SocketServer {port} {
   Msg "Sound server port $port"
   if [catch {
      set ::servsock [socket -server SocketAccept $port]
      #vwait forever
   } error] {
      puts $error
      exit
   }
}

# Connection to server
proc SocketAccept {sock addr port} {
   # We could reject here foreign hosts or have some restricted list
   Msg "Accept $sock from $addr port $port"
   fconfigure $sock -buffering full -translation binary
   fileevent $sock readable [list FirstCmd $sock]
}

# First command has to be "sound [options]"
proc FirstCmd {sock} {
   Busy $sock ""
   set line ""
   if {[catch {gets $sock line} error] || ([string length $line]==0)} {
      #Msg "in $sock line $line error $error"
      Close $sock
   } else {
      set line [string trimright $line \r]
      Msg $line
      switch [lindex $line 0] {
	 "sound" {
	    # Test that access is authorized for this file
	    array set opt {-file "" -load "" -channel ""}
	    array set opt [lrange $line 1 end]

            # Join with basename
            set opt(-file) [file join $::basename $opt(-file)]

	    # Test that pathname/extension for soundfile is authorized
	    if {$opt(-load) != "" || $opt(-channel) != ""
		|| [lsearch -exact [file split $opt(-file)] ".."] >= 0
		|| ![string match $::basename/* [file dirname $opt(-file)]/]
		|| [lsearch -exact $::exts [file extension $opt(-file)]] < 0
		|| ![file exists $opt(-file)]} {
	       ExecCmd $sock [list error "Can't open remote file $opt(-file)"]
	       Close $sock
	    } else {
               unset opt(-load)
               unset opt(-channel)
	       set snd [ExecCmd $sock [concat "sound" [array get opt]]]
               if {$::debug} {puts "[$snd info]"}
	       fileevent $sock readable [list NextCmd $sock $snd]
	    }
	 } 
	 default {
	    ExecCmd $sock [list error "Wrong command: $line"]
	    Close $sock
	 }
      }
   }
   Free
}

proc NextCmd {sock snd} {

   Busy $sock $snd

   set error "eof $sock"
   if {[catch {fconfigure $sock} error]
       || [eof $sock] 
       || [catch {gets $sock line} error]} {
      Close $sock $snd
   } else {
      set line [string trimright $line \r]
      if {[string length $line]!=0} {
	 Msg "$line"
	 switch -glob -- [lindex $line 0] {
	    "dump" {
	       global v
	       set v(-start) 0
	       set v(-end) -1
	       set v(-byteorder) $::tcl_platform(byteOrder)
	       array set v [lrange $line 1 end]
	       if {$v(-end)<0} {
		  set v(-end) [$snd length]
	       }
               if {$::debug} {puts "$snd dump -start $v(-start) -end $v(-end) -byteorder $v(-byteorder)"}
	       puts $sock "CODE ok LEN -1"
               # puts empty header with informations on signal
	       set b 2; # samplesize for lin16
	       set c [$snd cget -channels]
	       set f [$snd cget -frequency]
	       set nb [expr $b*$c*($v(-end)-$v(-start)+1)]
               #header conf -frequency $f -channels $c -format lin16
               #puts -nonewline $sock [header data -fileformat WAV]
	       puts -nonewline $sock [binary format a4ia8issiissa4i "RIFF" [expr 36+$nb] "WAVEfmt " 16 1 $c $f [expr $b*$c*$f] [expr $b*$c] [expr 8*$b] "data" $nb]
	       flush $sock
	       fconfigure $sock -blocking 0 
	       fileevent $sock writable [list PlayHandler $sock $snd]
	    }
	    "rshape" {
	       ExecCmd $sock "CompShape $snd"
	    }
	    "shape" -
	    "datasamples" -
	    "cget" -
	    "order" -
	    "info" -
	    "length" -
	    "stop" {
	       ExecCmd $sock [concat $snd $line]
	    }
	    "play" {
	       # filter playback command
	       set v(-start) 0
	       set v(-end) -1
	       set v(-devicerate) ""
	       array set v [lrange $line 1 end]
	       if {$v(-end)<0} {
		  set v(-end) [$snd length]
	       }
	       ExecCmd $sock [concat $snd "play" "-start" $v(-start) "-end" $v(-end)]
	    }
	    "elapsedTime" - "active" - "play_gain" {
	      ExecCmd $sock [concat "audio" $line]
	    }
	    "destroy" {
	       catch {shp$snd destroy}
	       ExecCmd $sock "$snd destroy"
	    }
	    default {
	       ExecCmd $sock [list error "Non authorized sub-command [lindex $line 0]"]
	    }
	 }
      }
   }

   Free
}

# Execute command and write result to the socket channel in the format :
#   CODE $code LEN $len <RETURN> $result
proc ExecCmd {sock cmd} {
   if {$::debug} {puts "$cmd"}
   if [catch {eval $cmd} res] {
      set code "error" 
   } else {
      set code "ok"
   }
   set len [string length $res]
   puts $sock "CODE $code LEN $len"
   puts -nonewline $sock $res
   flush $sock
   if {$::debug} {
      if {[lindex $cmd 1] == "shape" || [lindex $cmd 1] == "datasamples"} {
         puts " => ($code) ..."
      } else {
         puts " => ($code) $res"
      }
   }
   return $res
}

proc PlayHandler {sock snd} {
   global v

   Busy $sock $snd
   Msg "playing"

   if {$v(-start) >= $v(-end) || [catch {
      set end $v(-end)
      if {$end > [expr $v(-start) + 10000]} {
	 set end [expr $v(-start) + 10000]
      }
      #puts "playing $snd $v(start) $end => $sock"
     puts -nonewline $sock [$snd datasamples -start $v(-start) -end [expr $end-1] -byteorder $v(-byteorder)]
      flush $sock
      set v(-start) $end
   }]} {
      Close $sock $snd
   }

   Free
}

# Taken from Signal.tcl
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

proc CompShape {snd} {
   set shapeName [LookForShape [$snd cget -file]]
   set shp [sound shp$snd -file $shapeName \
		-frequency 100 -channels 2 -format LIN8]
   if {![$snd shape $shp -check 1]} {
      Msg "computing shape $shapeName"
      $snd shape $shp
      $shp write $shapeName -fileformat WAV
   }
   return $shp
}

proc Busy {sock {snd ""}} {
   set ::busy 1
   if {[catch {
      set ::peer [lindex [fconfigure $sock -peername] 1]
   }]} {
      set ::peer ""
   }
   if {$snd == "" || [catch {
      set ::name [$snd cget -file]
   }]} {
      set ::name ""
   }
   update idletasks
}

proc Close {sock {snd ""}} {
   Msg "closing connection"
   catch {shp$snd destroy}
   catch {$snd destroy}
   catch {close $sock}
}

proc Msg {txt} {
   set ::msg $txt
   update idletasks
}

proc Free {} {
   set ::busy 0
}

proc Quit {} {
   catch {close $::servsock}
   exit
}

proc Restart {} {
   catch {close $::servsock}
   SocketServer $::port
}

proc Interface {} {
   wm title . "Transcriber's Sound Server"
   wm protocol . WM_DELETE_WINDOW {Quit}

   set w [frame .top -relief raised -bd 1]
   pack $w -side top -fill both -expand true
   
   foreach i {1 2 3} n {
      "Port" "Shape storage" "Authorized signal paths"
   } var {port shp_path basename} {
      pack [frame $w.$i] -side top -fill x
      label $w.$i.l -text "$n:" -width 20 -anchor e
      pack $w.$i.l -side left -padx 1m -pady 1m
      entry $w.$i.e -textvariable $var -width 30
      pack $w.$i.e -side left -padx 1m -pady 1m -fill x -expand true
   }
   
   set w [frame .mid -relief raised -bd 1]
   pack $w -side top -fill both -expand true
   
   pack [frame $w.1] -side top -fill x
   label $w.1.l1 -text "Client:" -width 10
   label $w.1.l2 -textvariable peer -width 20 -relief sunken -anchor w
   pack $w.1.l1 $w.1.l2 -side left -padx 1m -pady 1m

   pack [frame $w.2] -side top -fill x
   label $w.2.l3 -text "Sound:" -width 10
   label $w.2.l4 -textvariable name -width 40 -relief sunken -anchor w
   pack $w.2.l3 $w.2.l4 -side left -padx 1m -pady 1m
   pack $w.2.l4 -fill x -expand true

   pack [frame $w.3] -side top -fill x
   checkbutton $w.3.c -text busy -var busy -anchor w
   pack $w.3.c -side left -padx 1m -pady 1m
   label $w.3.m -textvariable msg -width 40 -relief sunken -anchor w
   pack $w.3.m -side left -padx 1m -pady 1m -fill x -expand true
   
   set w [frame .bot -relief raised -bd 1]
   pack $w -side top -fill x

   button $w.r -text Restart -command Restart
   button $w.q -text Quit -command Quit
   pack $w.r $w.q -side left -expand true -padx 3m -pady 2m
}

# Parse line arguments
foreach {option value} $argv {
   switch -- $option {
      "-shape" {
	 set shp_path $value
      }
      "-port" {
	 set port $value
      }
      "-base" {
	 set basename $value
      }
      "-debug" {
	 set debug 1
      }
      default {
	 puts "unsupported command line option '$option'"
         puts "Syntax: $argv0 ?-shape $shp_path? ?-port $port ?-base $basename? ?-debug?"
         exit 1
      }
   }
}

# Start file server; if port already in use return else loop
Interface
SocketServer $port
