# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

###############################################################

# if mode != reset, keep current signal size and cursor position
proc EmptySignal {{mode "reset"}} {
   global v

   if {[info exists v(sig,cmd)] && $v(sig,cmd) != ""} {
      foreach wavfm $v(wavfm,list) {
	 $wavfm config -sound "" -shape ""
      }
      catch {$v(sig,cmd) destroy}
      if {$mode == "reset"} {
        StopAndRewind
      } else {
	PauseAudio
      }
   }
   # forget configuration for player
   catch {player config -file ""}
   set v(sig,cmd) ""
   if {$mode == "reset"} {
     set v(sig,min) 0
     set v(sig,base) 0
     # If possible, empty signal has the length of current transcription
     if {[catch {
       set episode [$v(trans,root) getChilds "element" "Episode"]
       set sec [lindex [$episode getChilds "element" "Section"] end]
       set v(sig,len) [$sec getAttr "endTime"]
     }]} {
       set v(sig,len) 10
     }
   }
   set v(sig,name) ""
   UpdateShortName
   set v(sig,desc) "Signal:\tnone\nDuration:\t[Tim2Str $v(sig,len)]\n"
   catch {$v(shape,cmd) destroy}
   set v(shape,cmd) ""
   ConfigAllWavfm
   if {$mode == "reset"} {
     SetSelection 0 0
     #$v(tk,gain) set 0
     NewGain 0
     MW_Reset
   }
}

# Open audio file
proc Signal {name {mode "reset"}} {
   global v

   # Forget previous signal, open new sound and set values
   EmptySignal $mode
   set sound [OpenSound $name]
   set v(sig,len) [$sound length -unit seconds]
   set v(sig,cmd) $sound
   set v(sig,name) $name
   UpdateShortName
   set stereo [lindex {"" "mono" "stereo" "" "quad"}  [$sound cget -channels]]
   set v(sig,desc) "Signal:\t$name\nDuration:\t[Tim2Str $v(sig,len)]\nFormat:\t[$sound cget -format] [format %g [expr [$sound cget -frequency]/1000.0]] kHz $stereo"

   # Add on top of list of sound paths
   if {! $v(sig,remote)} {
      set path [file dirname $name]
      lsuppress v(path,sounds) $path
      set v(path,sounds) [concat $path $v(path,sounds)]
   }

   # Centi-second shape pre-calculation in another process
   # for files longer than 20 sec (by default)
   # If shape inactive, should forbid global view of signal.
   # If v(shape,bg) is true, calculation is done in background.
   # For remote sounds, no background process implemented.
   set v(shape,cmd) ""
   if {$v(shape,wanted) && $v(sig,len) >= $v(shape,min)} {
      if {! $v(sig,remote)} {
	 set shapeName [LookForShape $name]
	 set shp [snack::sound -file $shapeName \
		      -frequency 100 -channels 2 -format LIN8]
	 if {[$sound shape $shp -check 1]} {
	    set v(shape,cmd) $shp
	 } else {
	    file delete -force $shapeName
	    if {$v(shape,bg)} {
	       $shp destroy

	       # abort (possibly) current subprocess before relaunching
	       ShapeAbort
	       
	       # launch sub-process
	       set bg [open "| [info nameofexecutable] [file join $v(path,tcl) BgShape.tcl] $name $shapeName $v(sig,rate) $v(sig,channels) $v(sig,header)"]
	       fileevent $bg readable [list ShapeDone $bg $sound $name $shapeName]
	       set v(shape,bgchan) $bg
	       
	       # User-friendly info box about current process
	       toplevel .shp -cursor watch
	       wm title .shp "Shape info"
	       label .shp.l -text "Currently computing global shape for signal\n[file tail $name]"
	       button .shp.b -text "Abort" -command ShapeAbort
	       pack .shp.l -fill both -expand true -padx 3m -pady 2m
	       pack .shp.b -padx 3m -pady 2m
	       
	    } else {
	       DisplayMessage "Computing signal shape. Please wait..."
	       update
	       $sound shape $shp -format MULAW
	       $shp write $shapeName -fileformat WAV
	       set v(shape,cmd) $shp
	       DisplayMessage ""
	    }
	 }
      } else {
	 set v(shape,cmd) [$sound rshape]
      }
   }
   if {$v(shape,cmd) != ""} {
      append v(sig,desc) "\nShape:\tyes"
   } else {
      append v(sig,desc) "\nShape:\tno"
   }

   # Synchronize end times between signal and transcription
   set nb [expr [GetSegmtNb seg0]-1]
   if {$nb >= 0} {
      set begin [GetSegmtField seg0 $nb -begin]
      set end [GetSegmtField seg0 $nb -end]
      if {$mode == "reset" && $begin >= $v(sig,len)
	|| $mode != "reset" && $end >= $v(sig,len)} {
	 # There are breakpoints after end of signal: keep previous end time
	 set v(sig,len) $end
	 foreach wavfm $v(wavfm,list) {
	    SynchroWidgets $wavfm
	 }
       } else {
	 # Move transcription end time to its new value
	 set endId [GetSegmtField seg0 $nb -endId]
	 Synchro::ModifyTime $endId $v(sig,len)
	 Synchro::UpdateTimeTags $endId
      }
   }

   ConfigAllWavfm
   update

   if {$mode != "switch"} {
     MW_AddFile $v(sig,name)
   }

   if {$v(play,auto)} {
      PlayFromBegin
   }
}

# When background process for computing shape is over, verify
# we still work on the same signal and update shape state
proc ShapeDone {channel sound sigName shapeName} {
   global v

   set res [string trim [read $channel]]
   if {![catch {
      close $channel
   } err]
       && $v(sig,cmd) == $sound
       && $v(sig,name) == $sigName
       && $res == $shapeName
    } {
      set v(shape,cmd) [snack::sound -file $shapeName -frequency 100 -channels 2]
      foreach wavfm $v(wavfm,list) {
	$wavfm config -shape $v(shape,cmd)
      } 
      DisplayMessage "Signal shape is now available!"
      append v(sig,desc) "\nShape:\tyes"
   } else {
      puts "error $res"; puts $err
      DisplayMessage "Signal shape not available, sorry..."
      append v(sig,desc) "\nShape:\tno"
   }
   unset v(shape,bgchan)
   destroy .shp
}

# Upon user request, abort background shape calculation by killing
# sub-process and removing temporary file (for UNIX only)
proc ShapeAbort {} {
   global v
   if [info exists v(shape,bgchan)] {
      set tmpshp $v(path,shape)/tmp[pid $v(shape,bgchan)].shape
      # What should it be for Windows NT ?
      exec kill -9 [pid $v(shape,bgchan)]
      catch {
	 close $v(shape,bgchan)
      }
      catch {
	 file delete $tmpshp
      }
      unset v(shape,bgchan)
      destroy .shp
   }
}

proc LookForShape {sigName} {
   global v

   set base [file root [file tail $sigName]]
   set ext "shape"

   # Search for an existing matching shape
   # (in default dir, shp sub-dir or signal dir)
   foreach path [concat $v(path,shape) "shp ../shp ."] {
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
   set shape [file join $v(path,shape) $base.$ext]
   file delete $shape
   return $shape
}

# Try to find a sound file bearing the name given in the "audio_filename"
# episode field or the same base name as the transcription;
# open it if it succeeds.
proc LookForSignal {transName sigName {base1 {}} {mode "reset"}} {
   global v

   # First try to read the signal if name is given
   if {$sigName != "" && ![catch {
      Signal $sigName $mode
   }]} {
      return
   }

   # Basename can be in the root tag, or the same as the transcription
   if {$base1 != ""} {
      lappend names $base1
   }
   set base2 [file root [file tail $transName]]
   if {$base2 != $base1 && $base2 != ""} {
      lappend names $base2
   }
   # Do we really need to open a different sound file ?
   if {[lsearch -exact $names [file root [file tail $v(sig,name)]]] >= 0} {
     if {$mode == "reset"} {
       MW_Reset
       MW_AddFile $v(sig,name)
     }
     return
   }
   # List of paths to search in
   set paths [concat [list [file dirname $transName]] $v(path,sounds)]
   # Search for a matching sound file
   foreach name $names {
      foreach path $paths {
	 foreach file [glob -nocomplain -- [file join $path $name].*] {
	   set ext [string tolower [file extension $file]]
	   if {[lsearch -exact $v(ext,snd) $ext] >= 0} {
	       if {[catch {
		  Signal $file $mode
	       }]} {
		  EmptySignal $mode
	       }
	       return
	    }
	 }
	 # Should we search recursively in sub-directories ? use lower case ?
      }
   }
   # We didn't find any adapted sound file, so we choose an empty signal
   EmptySignal $mode
}

# Sound file type according to Snack automatic detection (RAW, WAV,...)
proc SoundFileType {fileName} {
   if {[catch {
      set s [snack::sound -file $fileName]
      set t [lindex [$s info] 6]
      $s destroy
   }]} {
      set t "RAW"
   }
   return $t
}

# Open audio file through selection box or with simple entry
proc OpenAudioFile {{mode "reset"}} {
   global v audiopen

   if {$v(sig,remote)} {
      set audiopen $v(sig,name)
      set f .audiopen
      CreateModal $f "Open remote audio file"
      set g [frame $f.top -relief raised -bd 1]
      pack $g -fill both -expand true -side top
      EntryFrame $g.nam "Signal name" audiopen
      $g.nam.ent conf -width 30
      if {[OkCancelModal $f $f] != "OK"} {
	 set audiopen ""
      }
   } else {
      set types [subst {
	 {"Audio files" {$v(ext,snd)}}
	 {"All files"   {*}}
      }]
      set path [lindex $v(path,sounds) 0]
      if {$path == ""} {
	 set path $v(trans,path)
      }
      if {![file isdir $path]} {
	 set path [pwd]
      }
      set audiopen [tk_getOpenFile -filetypes $types \
		  -initialdir $path -title "Open audio file"]
   }
   if {$audiopen != ""} {
      Signal $audiopen $mode
      UpdateFilename
   }
   unset audiopen
}

# Choose every configurable option for sound files
proc ConfigureAudioFile {} {
   global v

   foreach name {
      sig,name sig,remote sig,server sig,port
      sig,rate sig,channels sig,header
      shape,wanted shape,bg path,shape
      play,auto playbackMode playbackPause playbackBeep playbackBefore
   } {
      set initv($name) $v($name)
   }

   set f .audioconf
   CreateModal $f "Audio file options"

   # Configuration for remote access - currently hidden
   set g [frame $f.rem -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   checkbutton $g.chk -text "Remote file access" -variable v(sig,remote) -anchor w -padx 3m -command "FrameState $g.frem \$v(sig,remote)"
   pack $g.chk -side top -fill x -expand true
   set h [frame $g.frem]
   EntryFrame $h.ser "Server" v(sig,server)
   EntryFrame $h.por "Port" v(sig,port)
   pack $h.ser $h.por -side left -expand true -fill x
   pack $h -side top -fill x -expand true
   FrameState $h $v(sig,remote)

   # Configuration for remote playback
   set g [frame $f.rpb -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   checkbutton $g.chk -text "Remote playback" -variable v(playbackRemote) -anchor w -padx 3m -command "FrameState $g.frem \$v(playbackRemote)"
   pack $g.chk -side top -fill x -expand true
   set h [frame $g.frem]
   EntryFrame $h.ser "Server" v(playbackServer)
   EntryFrame $h.por "Port" v(playbackPort)
   pack $h.ser $h.por -side left -expand true -fill x
   pack $h -side top -fill x -expand true
   FrameState $h $v(playbackRemote)

   # Configuration for raw sound files
   set g [frame $f.raw -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   set h [frame $g.1]
   label $h.l -text [Local "Default settings for raw sound files:"] -anchor w
   pack $h.l -side left -fill x -expand true -padx 3m
   MenuEntryFrame $h.rat "Rate" v(sig,rate) {8000 11025 16000 22050 32000 44100 48000}; $h.rat.ent conf -width 6; pack $h.rat.ent -expand false
   pack $h.l $h.rat -side left -fill x -expand true -padx 3m
   pack $h -fill both -expand true -side top
   set h [frame $g.2]
   MenuFrame $h.cha "Channels" v(sig,channels) {"mono" "stereo" "quad"}
   EntryFrame $h.head "Header size" v(sig,header); $h.head.ent conf -width 6
   pack $h.cha $h.head -side left -fill x -expand true
   pack $h -fill both -expand true -side top

   # Configuration for sound shapes
   set g [frame $f.shp -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   checkbutton $g.shp -text [Local "Compute low-resolution shape for long sound files"] -variable v(shape,wanted) -anchor w -padx 3m -command "FrameState $g.1 \$v(shape,wanted)"
   set h [frame $g.1]
   pack $g.shp $g.1 -side top -fill x
   if {$::tcl_platform(platform) != "windows"} {
      checkbutton $h.bg -text [Local "Do shape computation in background"] -variable v(shape,bg) -anchor w -padx 3m
      pack $h.bg
   }
   EntryFrame $h.en1 "Store signal shapes in" v(path,shape)
   catch {
    pack $h.bg $h.en1 -side top -fill x
   }
   FrameState $h $v(shape,wanted)

   # Configuration for playback
   set g [frame $f.pla -relief raised -bd 1]
   pack $g -fill both -expand true -side top
#    MenuFrame $g.mode "Playback mode" v(playbackMode) {
#       "Continuous playback"
#       "Pause at segment boundaries"
#       "Beep at segment boundaries"
#       "Stop at next segment boundary"
#       "Loop on segment or selection after pause"
#    } {"continuous" "pause" "beep" "stop" "loop"}
   EntryFrame $g.del "Pause duration (in seconds)" v(playbackPause); $g.del.ent conf -width 6; pack $g.del.ent -expand false
   EntryFrame $g.bip "Beep sound file" v(playbackBeep)
   button $g.bip.but -text [Local "Browse..."] -command {BrowseBeep}; pack $g.bip.but -side right -padx 1m -fill x -expand true
   EntryFrame $g.before "Go back before playing (in seconds)" v(playbackBefore); $g.before.ent conf -width 6; pack $g.before.ent -expand false
   checkbutton $g.en4 -text [Local "Automatic selection playback"] -variable v(play,auto) -anchor w -padx 3m -pady 2m
   pack $g.en4 -side top -expand true -fill x

   set answer [OkCancelModal $f $f]
   if {$answer == "OK"} {
      # If some modif can apply to the current sound file, reload it
      if {$v(sig,name) != "" && $v(sig,cmd) != ""} {
	 if {$v(shape,wanted) != $initv(shape,wanted)
	     || $v(sig,remote) != $initv(sig,remote)
	     || $v(sig,server) != $initv(sig,server)
	     || $v(sig,port) != $initv(sig,port)
	  } {
	    Signal $v(sig,name) "switch"
	 } elseif {[lindex [$v(sig,cmd) info] 6] == "RAW"
		   && ($v(sig,rate) != $initv(sig,rate)
		       || $v(sig,channels) != $initv(sig,channels)  
		       || $v(sig,header) != $initv(sig,header))
		   } {
	    # when raw files config changes, remove shape just in case
	    file delete [LookForShape $v(sig,name)]
	    Signal $v(sig,name) "switch"
	 }
      }
   } else {
      array set v [array get initv]
   }
}

proc BrowseBeep {} {
   global v

   if {[file readable $v(playbackBeep)]} {
      set dir [file dir $v(playbackBeep)]
      set file [file tail $v(playbackBeep)]
   } else {
      set dir ""
      set file ""
   }
   set choice [tk_getOpenFile -filetypes {
      {"Audio files" {.au .wav .snd}}
      {"All files"   {*}}
   } -title [Local "Choose beep file"] -initialdir $dir -initialfile $file]
   if {$choice != ""} {
      set v(playbackBeep) $choice
   }
}

###############################################################

# OpenSound
#   Opens a sound file (on the local host or on a file server via sockets
#   if v(sig,remote) is true)
#   Returns a Snack sound command (either locally or via a socket)

proc OpenSound {name {player 0}} {
   global v

   if {$player} {
     foreach {remote server port} [list $v(playbackRemote) $v(playbackServer) $v(playbackPort)] break
   } else {
     foreach {remote server port} [list $v(sig,remote) $v(sig,server) $v(sig,port)] break
   }
   if {! $remote} {
      if {![file exists $name]} {
	 return -code error "Sound file $name doesn't exist"
      }
      # Open sound file on localhost
      set sound [snack::sound -file $name -channels $v(sig,channels) -frequency $v(sig,rate) -skiphead $v(sig,header) -guessproperties 1]
   } else {
      # Open socket connection on file server
      if [catch {socket $server $port} channel] {
	 error "Couldn't open file server on $server \n($channel)"
      }
      fconfigure $channel -buffering full -translation binary

      # Create tcl command for file access
      if {$player} {
	set sound rplayer
      } else {
	if {![info exists v(proc,id)]} {
	  set v(proc,id) 0
	} else {
	  incr v(proc,id)
	}
	set sound rsound$v(proc,id)
      }
      proc $sound {cmd args} "eval SoundClient $sound $channel \$cmd \$args"

      # Open audio file on server with format options
      eval $sound "sound -file [list $name] -channels $v(sig,channels) -frequency $v(sig,rate) -skiphead $v(sig,header) -guessproperties 1"
   }
   return $sound
}

# Function for remote sound file management.
# Command is sent to the socket channel.
# The answer from the socket must be in the format:
#   CODE code LEN len <RETURN>
# followed by the $len bytes result; $code can be "ok" or "error"
# and an error is raised in the last case.
proc SoundClient {proc channel cmd args} {
   global $proc v

   #puts "$proc: $cmd $args"
   set code "ok"
   puts $channel [concat $cmd $args]
   catch {flush $channel}
   set res [gets $channel]
   if {[regexp {^ *CODE +([^ ]+) +LEN +(-?[0-9]+) *$} $res x code len]} {
      if {$len > 0} {
	 set res [read $channel $len]
      } elseif {$len < 0} {
	 # For stream read, return channel itself and suppress proc
	 set res $channel
	 rename $proc {}
     } else {
	 set res ""
      }
   } else {
      set cmd "destroy"
      set code "error"
      set res "$proc error - $res"
   }
   if {[eof $channel] || $cmd == "destroy"} {
      rename $proc {}
      # This can raise an error (and return error message from pipe/socket)
      if {[catch {close $channel} err] && $cmd != "destroy"} {
	 set code "error"
	 concat res $err
      }
   }
   return -code $code $res
}
