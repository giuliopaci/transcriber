# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc CreateSoundFrame {f} {
   global v

   frame $f -bd 1 -relief raised -bg $v(color,bg)
   setdef v($f.w,height) 100
   set wavfm [wavfm $f.w -padx 10 -bd 0 -bg $v(color,bg) \
		  -height $v($f.w,height) -selectbackground $v(color,bg-sel)]
   axis $f.a -padx 10 -bd 0 -bg $v(color,bg) -font axis

   set g $f.scr
   frame $g -bg $v(color,bg)
   set v($wavfm,scroll) [scrollbar $g.pos -orient horizontal -width 15\
	-command [list ScrollTime $wavfm]]
   pack $g.pos -fill x -side left -expand true -anchor n

   # optional resolution scrollbar
   frame $g.reso
   label $g.reso.lab -text "Resolution" -font {fixed 10} -bd 0 -padx 10 -pady 0
   set v($wavfm,scale) [scrollbar $g.reso.scrol -command [list ScrollReso $wavfm] -orient horizontal -width 8 -bd 1]
   pack $g.reso.lab -side top
   pack $g.reso.scrol -fill x -expand true
   # Default : display resolution scrollbar
   setdef v(view,$g.reso) 1
   if {$v(view,$g.reso)} {
      pack $g.reso -padx 0 -pady 0 -side right
   }

   pack $g -side top -fill x

   pack $f.w -fill both -expand true -side top
   pack $f.a -fill x -side top
   pack $f -fill both -side top
   set v($wavfm,sync) [list $wavfm $f.a]
   lappend v(wavfm,list) $wavfm

   # Register the bindings at the frame level
   bindtags $wavfm [list $wavfm Wavfm $f . all]
   bindtags $f.a [list $f.a Axis $f . all]

   # Selection/cursor position with B1
   bind $f <Button-1>  [list BeginCursorOrSelect $wavfm %X]
   bind $f <B1-Motion> [list SelectMore $wavfm %X]
   bind $f <ButtonRelease-1> [list EndCursorOrSelect $wavfm]
   bind $f <Shift-Button-1>  [list ExtendOldSelection $wavfm %X]

   # Extend selection with B2
   bind $f <Button-2>  [list ExtendOldSelection $wavfm %X]

   # Contextual menus with B3
   regsub -all {\.} $wavfm {_} name
   set v($wavfm,menu) [add_menu .menu$name [subst {
      {"Audio file"		cascade {
	 {"Open audio file..." 	cmd {OpenAudioFile}}
      }}
      {"Playback"		cascade {
	 {"Play/Pause"		cmd {PlayOrPause}}
	 {"Replay segment"	cmd {PlayCurrentSegmt}}
	 {"Play around cursor"	cmd {PlayAround}}
      }}
      {"Position"		cascade {
	 {"Forward"	cmd {PlayForward +1}}
	 {"Backward"	cmd {PlayForward -1}}
	 {"Previous"	cmd {MoveNextSegmt -1}}
	 {"Next"	cmd {MoveNextSegmt +1}} 
      }}
      {"Resolution"		cascade {
	 {"1 sec"	cmd {Resolution 1 $wavfm}}
	 {"10 sec"	cmd {Resolution 10 $wavfm}}
	 {"30 sec"	cmd {Resolution 30 $wavfm}}
	 {"1 mn"	cmd {Resolution 60 $wavfm}}
	 {"5 mn"	cmd {Resolution 300 $wavfm}}
	 {""}
	 {"up"		cmd {ZoomReso -1 $wavfm}}
	 {"down"	cmd {ZoomReso +1 $wavfm}}
	 {""}
	 {"View all"	cmd {ViewAll $wavfm}}
      }}
      {"Display"		cascade {
	 {"Resolution bar"	check v(view,$g.reso) -command {SwitchFrame $g.reso}}
	 {"Reduce waveform"	cmd {WavfmHeight $wavfm [expr 1/1.2]}}
	 {"Expand waveform"	cmd {WavfmHeight $wavfm 1.2}}
	 {""}
      }}
   }]]
   bind $f <Button-3>  [list tk_popup $v($wavfm,menu) %X %Y]
   return $wavfm
}

proc SwitchSoundFrame {f} {
   global v

   if {![winfo exists $f]} {
     set wavfm [CreateSoundFrame $f]
     ConfigWavfm $wavfm
     CreateAllSegmentWidgets
     SetCursor [GetCursor]
   } elseif {[winfo ismapped $f]} {
     pack forget $f
   } else {
     pack $f -fill x
   }
}

proc WavfmHeight {wavfm {val 1.0}} {
   global v

   set v($wavfm,height) [expr int([$wavfm cget -height] * $val)]
   $wavfm conf -height $v($wavfm,height)
}

proc ConfigWavfm {wavfm} {
   global v

   set v($wavfm,left)    0
   set v($wavfm,size)    [setdef v($wavfm,resolution) 30]
   if {$v(shape,cmd)=="" && $v($wavfm,size) > $v(shape,min)} {
      set v($wavfm,size) $v(shape,min)
   }
   $wavfm config -sound $v(sig,cmd) -shape $v(shape,cmd)
   SynchroWidgets $wavfm
}

proc ConfigAllWavfm {} {
   global v

   foreach wavfm $v(wavfm,list) {
      ConfigWavfm $wavfm
   }
}

################################################################

# Synchronize waveform, axis and scrollbars
proc SynchroWidgets {wavfm} {
   global v

   # Make sure we have :
   #   sig,min <= win,left < win,right=(left+size) <= sig,max=(min+len)
   if {$v($wavfm,size) > $v(sig,len)} {
      set v($wavfm,size) $v(sig,len)
   }
   if {$v($wavfm,left) < $v(sig,min)} {
      set v($wavfm,left) $v(sig,min)
   }
   set v($wavfm,right) [expr $v($wavfm,left)+$v($wavfm,size)]
   set v(sig,max)   [expr $v(sig,min)+$v(sig,len)]
   if {$v($wavfm,right) > $v(sig,max)} {
      set v($wavfm,right) $v(sig,max)
      set v($wavfm,left) [expr $v($wavfm,right)-$v($wavfm,size)]
   }
   # Configure widgets
   foreach tk $v($wavfm,sync) {
      set left $v($wavfm,left)
      if {[winfo class $tk] == "Axis"} {
	 set left [expr $left+$v(sig,base)]
      }
      $tk configure -begin $left -length $v($wavfm,size)
   }
   set begin [expr ($v($wavfm,left)-$v(sig,min))/$v(sig,len)]
   set ratio [expr $v($wavfm,size)/$v(sig,len)]
   $v($wavfm,scroll) set $begin [expr $begin+$ratio]
   $v($wavfm,scale) set $ratio $ratio
}

# Horizontal scrollbar callback
proc ScrollTime {wavfm cmd {val 0} {unit ""}} {
   global v

   if {$cmd=="moveto"} {
      set v($wavfm,left) [expr $val*$v(sig,len)+$v(sig,min)]
   } elseif {$cmd=="scroll"} {
      if {$unit=="units"} {
	 set v($wavfm,left) [expr $v($wavfm,left)+$val*$v($wavfm,size)/100.0]
      } elseif {$unit=="pages"} {
	 set v($wavfm,left) [expr $v($wavfm,left)+$val*$v($wavfm,size)]
      }
   }
   SynchroWidgets $wavfm
}

# Vertical scrollbar callback for resolution
proc ScrollReso {wavfm cmd {val 0} {unit ""}} {
   global v

   if ($v(sig,len)<0) return;

   # Try to keep cursor stable - else center of screen
   set curs $v(curs,pos)
   if {($curs >= $v($wavfm,left)) && ($curs <= $v($wavfm,right))} {
      set ratio [expr ($curs-$v($wavfm,left))/$v($wavfm,size)]
   } else {
      set ratio 0.5
   }
   set t [expr $v($wavfm,left)+$v($wavfm,size)*$ratio]

   if {$cmd=="moveto"} {
      if {$val>0} {set v($wavfm,size) [expr $val*$v(sig,len)]}
   } elseif {$cmd=="scroll"} {
      if {$val>0} {
	 set scale 1.1
      } else {
	 set scale 0.9
      }
      set v($wavfm,size) [expr $scale*$v($wavfm,size)]
   }
   # Arbitrary max value for zoom
   if {$v($wavfm,size) < 1e-5} {
      set v($wavfm,size) 1e-5
   }
   # Min value for zoom if no shape is available
   if {$v(shape,cmd) == "" && $v($wavfm,size) > $v(shape,min)} {
      DisplayMessage "Lower resolution not allowed without signal shape"
      set v($wavfm,size) $v(shape,min)
   }
   set v($wavfm,left) [expr $t-$v($wavfm,size)*$ratio]
   set v($wavfm,resolution) $v($wavfm,size) 
   SynchroWidgets $wavfm
}

proc Resolution {reso {win ""}} {
   global v

   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   ScrollReso $win moveto [expr 1.0*$reso/$v(sig,len)]
}

proc ZoomReso {dir {win ""}} {
   global v

   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   ScrollReso $win scroll $dir
}

proc ViewAll {{win ""}} {
   global v

   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   set v($win,left) $v(sig,min)
   set v($win,size) $v(sig,len)
   if {$v(shape,cmd) == "" && $v($win,size) > $v(shape,min)} {
      set v($win,size) $v(shape,min)
   }
   SynchroWidgets $win
}

# Change volume gain for waveform display (not for replay)
proc NewGain {val} {
   global v

   set v(sig,gain) $val
   set vol [expr exp($val/10.0*log(10.0))]
   #$v(tk,gain) configure -label "Vertical zoom ($val dB)"
   foreach wavfm $v(wavfm,list) {
      $wavfm configure -volume $vol
   }
}

################################################################

# Cursor and selection handling

proc SetCursor {pos {hide 0}} {
   global v

   if {$pos < $v(sig,min)} {
      set pos $v(sig,min)
   } elseif {$pos > $v(sig,max)} {
      set pos $v(sig,max)
   }
   set v(curs,pos) $pos
   if {$hide == 1} {
      foreach wavfm $v(wavfm,list) {
	 #$wavfm config -cursor -1
	 $wavfm cursor -1
      }
      DisplayMessage "\t\t\t$v(sel,text)"
   } else {
      foreach wavfm $v(wavfm,list) {
	 #$wavfm config -cursor $pos
	 $wavfm cursor $pos
	 # View cursor
	 set margin 0; #[expr $v($wavfm,size)*0.0]
	 if {$pos > $v($wavfm,right)} {
	    set v($wavfm,left) [expr $pos + $margin - $v($wavfm,size)]
	    SynchroWidgets $wavfm
	 } elseif {$pos < $v($wavfm,left) } {
	   set v($wavfm,left) [expr $pos - $margin]
	    SynchroWidgets $wavfm
	 }
      }
      DisplayMessage "Cursor : [Tim2Str [expr $v(curs,pos)+$v(sig,base)] 3]\t\t$v(sel,text)"
      SynchroToSignal $pos
   }
}

proc EditCursor {} {
   global v dial

   set f [CreateModal .curs "Cursor"]
   set w [frame $f.top -relief raised -bd 1]
   pack $w -fill both -expand true -side top
   set dial(newpos) [format "%.3f" [GetCursor]]
   set e [EntryFrame $w.en "Position (in seconds)" dial(newpos)]
   if {[OkCancelModal $f $e] == "OK"} {
      if {[regexp {^((([0-9]+):)?([0-5]?[0-9]):)?([0-9]+(\.[0-9]+)?)$} $dial(newpos) all hasm hash h m s]} {
	 if {$h == ""} {set h 0}
	 if {$m == ""} {set m 0}
	 set pos [expr 3600*$h+60*$m+$s]
	 if {$dial(newpos) != [format "%.3f" [GetCursor]]} {
	    foreach win $v(wavfm,list) {
	       set v($win,left) [expr $pos-$v($win,size)/2]
	       SynchroWidgets $win
	    }
	 }
	 SetCursor $pos
      } else {
	 DisplayMessage "Cursor : invalid position $dial(newpos)"
      }
   }
}

proc GetCursor {} {
   global v

   return $v(curs,pos)
}

# Set selection, put cursor at beginning and display infos
proc SetSelection {begin end} {
   global v

   set v(sel,begin) $begin
   set v(sel,end) $end
   foreach wavfm $v(wavfm,list) {
      $wavfm config -selectbegin $begin -selectend $end
   }
   if {($end > $begin)} {
      set v(sel,text) "Selection : [Tim2Str [expr $begin+$v(sig,base)] 3] - [Tim2Str [expr $end+$v(sig,base)] 3] ([Tim2Str [expr $end-$begin] 3])"
      config_entry "Signal" "Zoom selection" -state normal
   } else {
      set v(sel,text) ""
      config_entry "Signal" "Zoom selection" -state disabled
      config_entry "Signal" "Unzoom selection" -state disabled
   }
   SetCursor $begin
}

# If selection exists, returns true and set begin/end values into vars
# else returns false and set all signal into vars
proc GetSelection {{beginName ""} {endName ""}} {
   global v
   if {$beginName != ""} {
      upvar $beginName begin
   }
   if {$endName != ""} {
      upvar $endName   end
   }

   # Test if previous selection exists
   set begin $v(sel,begin)
   set end $v(sel,end)
   if {($begin >= $v(sig,min)) && ($end > $begin) && ($end <= $v(sig,max))} {
      return 1
   } else {
      set begin $v(sig,min)
      set end   $v(sig,max)
      return 0
   }
}

# Return position in signal from screen click position
#  - scroll = -1 or +1 if click is outside window (left or right), 0 else
proc GetClickPos {wavfm X scrollName} {
   global v
   upvar $scrollName scroll

   set bd [expr [$wavfm cget -bd] + [$wavfm cget -padx]]
   set width [expr [winfo width $wavfm] - 2*$bd]
   set x [expr $X - $bd - [winfo rootx $wavfm]]
   if {$x<0} {
      set scroll -1
      set pos $v($wavfm,left)
   } elseif {$x>$width} {
      set scroll +1
      set pos $v($wavfm,right)
   } else {
      set scroll 0
      set pos [expr $v($wavfm,left)+$v($wavfm,size)*double($x)/$width]
   }
   return $pos
}

################################################################

# Events bindings for cursor position and  selection

proc BeginCursorOrSelect {wavfm X} {
   global v

   PauseAudio
   set pos [GetClickPos $wavfm $X scroll]
   if {$scroll == 0} {
      set v(sel,start) $pos
      SetSelection $pos $pos
   }
}

proc CancelSelectEvent {} {
   global v

   if [info exists v(sel,event)] {
      after cancel $v(sel,event)
      unset v(sel,event)
   }
}

proc SelectMore {wavfm X} {
   global v

   if ![info exists v(sel,start)] return
   CancelSelectEvent
   # If out of window : scroll for extending selection and repeat event
   set pos [GetClickPos $wavfm $X scroll]
   if {$scroll != 0} {
      ScrollTime $wavfm scroll $scroll units
      # Get new position after scroll
      set pos [GetClickPos $wavfm $X scroll]
      set v(sel,event) [after idle [list SelectMore $wavfm $X]]
   }
   # Selection with right order for $v(sel,start) and $pos
   eval SetSelection [lsort -real [list $v(sel,start) $pos]]
}

proc EndCursorOrSelect {win} {
   global v

   if [info exists v(sel,start)] {
      CancelSelectEvent
      unset v(sel,start)
      if [GetSelection beg end] {
	 # If selection too short (4 pixels), set only cursor
	 set epsilon [expr 4.0*$v($win,size)/[winfo width $win]]
	 if {$end-$beg < $epsilon} {
	    SetSelection $beg $beg
	    return
	 }
	 # Automatic play selection : optional
	 if {$v(play,auto)} {
	    PlayFromBegin
	 }
      }
   }
}

proc ExtendOldSelection {wavfm X} {
   global v

   PauseAudio
   # Test if previous selection exists
   if [GetSelection beg end] {
      set pos [GetClickPos $wavfm $X scroll]
      if {$scroll != 0} return

      # Choose side of extension
      if {[expr abs($pos-$beg)] < [expr abs($pos-$end)]} {
	 set v(sel,start) $end
      } else {
	 set v(sel,start) $beg
      }
   } else {
      set v(sel,start) [GetCursor]
   }
   SelectMore $wavfm $X
}

# View selection (or given interval)
proc ViewSelection {{beg {}} {end {}} {mode "AUTO"} {ratio 0.1}} {
   global v

  #set win $v(tk,wavfm); # defaults to principal sound frame
  foreach win $v(wavfm,list) {
    if { ($beg != "" && $end != "") || [GetSelection beg end] } {
      set margin [expr $v($win,size)*$ratio]
      if {$end-$beg > $v($win,size)} {
	# If it can't fit completely on screen...
	if {$end == $v(sig,max)} {
	  # center left side of last segment
	  set v($win,left) [expr $beg-$v($win,size)/2.0]
	} elseif {$mode == "END" || ($mode == "AUTO" && 
		  $end > $v($win,left) && $end < $v($win,right))} {
	  # show end
	  set v($win,left) [expr $end + $margin - $v($win,size)]
	} elseif {$mode == "BEGIN" || ($mode == "AUTO"
                  && $beg > $v($win,left) && $beg < $v($win,right)) } {
	  # show begin
	  set v($win,left) [expr $beg - $margin]
	} else {
	  # center
	  set v($win,left) [expr ($end+$beg-$v($win,size))/2.0]
	}
      } elseif {$end-$beg > (1-2*$ratio)*$v($win,size)} {
	# center on the screen with a reduced margin
	set v($win,left) [expr ($end+$beg-$v($win,size))/2.0]
      } else {
	if {$end > $v($win,right)} {
	  # show end plus margin
	  set v($win,left) [expr $end + $margin - $v($win,size)]
	} elseif {$beg < $v($win,left) } {
	  # show begin plus margin
	  set v($win,left) [expr $beg - $margin]
	} else {
	  # it's ok
	  continue
	}
      }
      SynchroWidgets $win
    }
  }
}

################################################################

# Zoom on selection
proc ZoomSelection {{win ""}} {
   global v

   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   if [GetSelection beg end] {
      set v(zoom,list) [list $v($win,left) $v($win,size)]
      set v($win,left) $beg
      set v($win,size) [expr $end-$beg]
      SynchroWidgets $win
      config_entry "Signal" "Unzoom selection" -state normal
   }
}

# Undo last zoom
proc UnZoom {{win ""}} {
   global v

   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   if [info exists v(zoom,list)] {
      set v($win,left) [lindex $v(zoom,list) 0]
      set v($win,size) [lindex $v(zoom,list) 1]
      unset v(zoom,list)
      SynchroWidgets $win
      config_entry "Signal" "Unzoom selection" -state disabled
   }
}
