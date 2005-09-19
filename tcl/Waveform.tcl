# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc CreateSoundFrame {frame} {
    #
    # JOB: create a sound frame
    #
    # IN: frame, the name of the wav frame, i.e. snd or snd2
    # OUT: nothing
    # MODIFY: v(frame_menu,$frame),v(frame,$frame.reso)
    #
    # Author: ??, Fabien Antoine
    # Version: 1.0
    # Date: Septembre 7, 2005
    # 
    global v

    set f $v(frame,$frame)
    foreach subframe {seg0 seg1 seg2 bg w} {
	set v(frame,$frame.$subframe) $f.1.$subframe
	set v(frame_name,$f.1.$subframe) $frame.$subframe
    }
    set v(frame,$frame.reso) $f.1.scr.reso
    set v(frame_name,$f.1.scr.reso) $frame.resos
    

    # embedded frame for optional inclusion of video
#    frame $f; #commented by FAE
    if {$v(frame_view,$frame)} { 
#        [winfo parent $f] add $f
	pack $f -fill both -side top
    } 
    set f $f.1
    frame $f -bd 1 -relief raised -bg $v(color,bg)
    setdef v($f.w,height) 100
    set wavfm [wavfm $f.w -padx 10 -bd 0 -bg $v(color,bg) \
		  -height $v($f.w,height) -selectbackground $v(color,bg-sel)]
    axis $f.a -padx 10 -bd 0 -bg $v(color,bg) -font axis
    
    set g $f.scr
    frame $g -bg $v(color,bg)
    frame $g.zoom
    label $g.zoom.lab -text "Zoom(dB)" -font {fixed 10} -bd 0 -padx 10 -pady 0
    set v($wavfm,zoom) [scale  $g.zoom.scrol -showvalue 0  -length 50 -from -10 -to 20  -command [list NewGain] -orient horizontal -width 8 -bd 1]
    pack $g.zoom.lab -side top
    pack $g.zoom.scrol -fill x -expand true
    pack $g.zoom -padx 0 -pady 0 -side left
    set v(frame_wavfm_scroll,$frame.w) [scrollbar $g.pos -orient horizontal -width 15\
		              -command [list ScrollTime $wavfm]]
    pack $g.pos -fill x -side left -expand true -anchor n
    
    # optional resolution scrollbar
    frame $g.reso
    label $g.reso.lab -text "Resolution" -font {fixed 10} -bd 0 -padx 10 -pady 0
    set v($wavfm,scale) [scrollbar $g.reso.scrol -command [list ScrollReso $wavfm] -orient horizontal -width 8 -bd 1]
    pack $g.reso.lab -side top
    pack $g.reso.scrol -fill x -expand true
    # Default : display resolution scrollbar
    setdef v(frame_view,$frame.reso) 1
    if {$v(frame_view,$frame.reso)} {
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
    InitWavContextualMenu $frame
    bind $f <Button-3>  [list tk_popup $v(frame_menu,$frame) %X %Y]
    bind $f <Control-Button-1>  [list tk_popup $v(frame_menu,$frame) %X %Y]
    return $wavfm
}

proc InitWavContextualMenu {f} {
    #
    # JOB: create the contextual menu on wave frame
    #
    # IN: f, the name of the wav frame, i.e. snd or snd2
    # OUT: nothing
    # MODIFY: v(frame_menu,$f)
    #
    # Author: Claude Barras, Sylvain Galliano, Fabien Antoine
    # Version: 1.2
    # Date: Septembre 7, 2005
    #

    global v
    set wavfm $v(frame,$f).1.w
    
    catch {destroy .menu$f}
    set v(frame_menu,$f) [add_menu .menu$f [subst {
	{"Audio file"                cascade {
	    {"Open audio file..."         cmd {OpenAudioFile}}
	    {"Add audio file..."         cmd {OpenAudioFile add}}
	    {"Save audio segment(s)"   cascade {
		{"Selected..."     cmd   {SaveAudioSegment}}
		{"Automatic..." cmd   {SaveAudioSegmentAuto}}
	    }}
	    {""}
	}}
	{"Playback"                cascade {
	    {"Play/Pause"                cmd {PlayOrPause}}
	    {"Replay segment"        cmd {PlayCurrentSegmt}}
	    {"Play around cursor"        cmd {PlayAround}}
	}}
	{"Position"                cascade {
	    {"Forward"        cmd {PlayForward +1}}
	    {"Backward"        cmd {PlayForward -1}}
	    {"Previous"        cmd {MoveNextSegmt -1}}
	    {"Next"        cmd {MoveNextSegmt +1}} 
	}}
	{"Resolution"                cascade {
	    {"1 sec"        cmd {Resolution 1 $wavfm}}
	    {"10 sec"        cmd {Resolution 10 $wavfm}}
	    {"30 sec"        cmd {Resolution 30 $wavfm}}
	    {"1 mn"        cmd {Resolution 60 $wavfm}}
	    {"5 mn"        cmd {Resolution 300 $wavfm}}
	    {""}
	    {"up"                cmd {ZoomReso -1 $wavfm}}
	    {"down"        cmd {ZoomReso +1 $wavfm}}
	    {""}
	    {"View all"        cmd {ViewAll $wavfm}}
	}}
	{"Display"                cascade {
	    {"Resolution bar"        check v(frame_view,$f.reso) -command {SwitchFrame $f.reso}}
	    {"Reduce waveform"        cmd {WavfmHeight $f [expr 1/1.2]}}
	    {"Expand waveform"        cmd {WavfmHeight $f 1.2}}
	    {""}
	}}
    }]]
}

proc WavfmHeight {wavfm {val 1.0}} {
    #
    # JOB: Change height of a frame containing a waveform 
    #
    # IN: wavfm, path of the frame, optionnal scaling value (e.g. ...snd.1.w or ...snd2.1.w)
    # OUT: Nothing
    # MODIFY: v(frame_wavfm_height,$wavfm)
    #
    # AUTHOR: ??, Fabien Antoine
    # VERSION: 1.0
    # DATE: September 7, 2005
    # 
   global v

   set frame $v(frame_name,$wavfm)
   set v(frame_wavfm_height,$frame) [expr int([$wavfm cget -height] * $val)]
   $wavfm conf -height $v(frame_wavfm_height,$frame)
}

proc ConfigWavfm {wavfm {mode "reset"}} {
    #
    # JOB: Configure waveforme frame
    #
    # IN: wavfm, path of the waveform, mode 
    # OUT: Value returned by the procedure and its meaning
    # MODIFY: Global variables modified by the procedure
    #
    # AUTHOR: ??, Fabien Antoine
    # VERSION: Version number of the procedure
    # DATE: Date of creation or last modification of the procedure
    # 
   global v

   set frame $v(frame_name,$wavfm)

  if {$mode == "reset"} {
    set v(frame_wavfm_left,$frame)    0
    set v(frame_wavfm_size,$frame)    [setdef v(frame_wavfm_resolution,$frame) 30]
    if {$v(shape,cmd)=="" && $v(frame_wavfm_size,$frame) > $v(shape,min)} {
      set v(frame_wavfm_size,$frame) $v(shape,min)
    }
  }
  $wavfm config -sound $v(sig,cmd) -shape $v(shape,cmd)
  if {$mode == "reset"} {
    SynchroWidgets $wavfm
  }
}

proc ConfigAllWavfm {{mode "reset"}} {
   global v

   foreach wavfm $v(wavfm,list) {
      ConfigWavfm $wavfm $mode
   }
}

################################################################

# Synchronize waveform, axis and scrollbars
proc SynchroWidgets {wavfm} {
   global v
    #
    # JOB: synchronize waveform widgets 
    #
    # IN: frame, the path of the wav frame
    # OUT: nothing
    # MODIFY: v(frame_menu,$frame),v(frame,$frame.reso)
    #
    # Author: ??, Fabien Antoine
    # Version: 1.0
    # Date: Septembre 7, 2005
    # 
    set frame $v(frame_name,$wavfm)
   # Make sure we have :
   #   sig,min <= win,left < win,right=(left+size) <= sig,max=(min+len)
   if {$v(frame_wavfm_size,$frame) > $v(sig,len)} {
      set v(frame_wavfm_size,$frame) $v(sig,len)
   }
   if {$v(frame_wavfm_left,$frame) < $v(sig,min)} {
      set v(frame_wavfm_left,$frame) $v(sig,min)
   }
   set v(frame_wavfm_right,$frame) [expr $v(frame_wavfm_left,$frame)+$v(frame_wavfm_size,$frame)]
   set v(sig,max)   [expr $v(sig,min)+$v(sig,len)]
   if {$v(frame_wavfm_right,$frame) > $v(sig,max)} {
      set v(frame_wavfm_right,$frame) $v(sig,max)
      set v(frame_wavfm_left,$frame) [expr $v(frame_wavfm_right,$frame)-$v(frame_wavfm_size,$frame)]
   }
   # Configure widgets
   foreach tk $v($wavfm,sync) {
      set left $v(frame_wavfm_left,$frame)
      if {[winfo class $tk] == "Axis"} {
	 set left [expr $left+$v(sig,base)]
      }
      $tk configure -begin $left -length $v(frame_wavfm_size,$frame)
   }
   set begin [expr ($v(frame_wavfm_left,$frame)-$v(sig,min))/$v(sig,len)]
   set ratio [expr $v(frame_wavfm_size,$frame)/$v(sig,len)]
   $v(frame_wavfm_scroll,$frame) set $begin [expr $begin+$ratio]
   $v($wavfm,scale) set $ratio $ratio
}

# Horizontal scrollbar callback
proc ScrollTime {wavfm cmd {val 0} {unit ""}} {
   global v

    set frame $v(frame_name,$wavfm)
   if {$cmd=="moveto"} {
      set v(frame_wavfm_left,$frame) [expr $val*$v(sig,len)+$v(sig,min)]
   } elseif {$cmd=="scroll"} {
      if {$unit=="units"} {
	 set v(frame_wavfm_left,$frame) [expr $v(frame_wavfm_left,$frame)+$val*$v(frame_wavfm_size,$frame)/100.0]
      } elseif {$unit=="pages"} {
	 set v(frame_wavfm_left,$frame) [expr $v(frame_wavfm_left,$frame)+$val*$v(frame_wavfm_size,$frame)]
      }
   }
   SynchroWidgets $wavfm
}

# Vertical scrollbar callback for resolution
proc ScrollReso {wavfm cmd {val 0} {unit ""}} {
    #
    # JOB: change the resolution of a waveform (called by Resolution)
    #
    # IN: wavfm, path of the frame containing the waveform, cmd command, val value, unit unit
    # OUT: 
    # MODIFY: ?
    #
    # AUTHOR: ??, Fabien Antoine
    # VERSION: 1.0
    # DATE: September 7, 2005
    # 
   global v
   set frame $v(frame_name,$wavfm)

   if ($v(sig,len)<0) return;

   if {[winfo exists .noshapemsg]} {
	  destroy .noshapemsg
   }   
   # Try to keep cursor stable - else center of screen
   set curs $v(curs,pos)
   if {($curs >= $v(frame_wavfm_left,$frame)) && ($curs <= $v(frame_wavfm_right,$frame))} {
      set ratio [expr ($curs-$v(frame_wavfm_left,$frame))/$v(frame_wavfm_size,$frame)]
   } else {
      set ratio 0.5
   }
   set t [expr $v(frame_wavfm_left,$frame)+$v(frame_wavfm_size,$frame)*$ratio]
   if {$cmd=="moveto"} {
     if {$val>0} {set v(frame_wavfm_size,$frame) [expr $val*$v(sig,len)]}
   } elseif {$cmd=="scroll"} {
      if {$val>0} {
	set scale 1.1
      } else {
	 set scale 0.9
      }
      set v(frame_wavfm_size,$frame) [expr $scale*$v(frame_wavfm_size,$frame)]
   }
   # Arbitrary max value for zoom
   if {$v(frame_wavfm_size,$frame) < 1e-5} {
      set v(frame_wavfm_size,$frame) 1e-5
   }
   # Min value for zoom if no shape is available
   if {$v(sig,cmd) != "" && $v(shape,cmd) == "" && $v(frame_wavfm_size,$frame) > $v(shape,min)} {
      NoShapeMessage
      DisplayMessage "Lower resolution not allowed without signal shape"
      set v(frame_wavfm_size,$frame) $v(shape,min)
   }
   set v(frame_wavfm_left,$frame) [expr $t-$v(frame_wavfm_size,$frame)*$ratio]
   set v(frame_wavfm_resolution,$frame) $v(frame_wavfm_size,$frame) 
   SynchroWidgets $wavfm
}

proc NoShapeMessage {} {
  set m .noshapemsg
  if {[winfo exists $m]} {
    destroy $m
  }  
  toplevel $m
  wm title $m "Warning !"
  wm geometry $m 250x100+500+350
  label $m.l -text [Local "Resolution > 30\" impossible !\n\nCan't find the signal shape."]
  button $m.b -text "Ok" -command {destroy .noshapemsg}
  pack $m.l -fill both -expand true -padx 3m -pady 2m
  pack $m.b -padx 3m -pady 2m
  bell -displayof $m
} 

proc Resolution {reso {win ""}} {
   global v
    #
    # JOB: change the resolution of a waveform to reso
    #
    # IN: reso, the resolution wished, optionnal win, the path of the frame containing the waveform (e.g. snd.1.w or snd2.1.w)
    # OUT: nothing
    # MODIFY: nothing
    #
    # AUTHOR: ??
    # VERSION: 1.0
    # DATE: ??
    #


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
    set frame $v(frame_name,$win)
   set v(frame_wavfm_left,$frame) $v(sig,min)
   set v(frame_wavfm_size,$frame) $v(sig,len)
   if {$v(shape,cmd) == "" && $v(frame_wavfm_size,$frame) > $v(shape,min)} {
      set v(frame_wavfm_size,$frame) $v(shape,min)
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

proc ScrollGain {wavfm cmd {val 0}} {
    global v
    switch $cmd {
	"moveto" {
	    NewGain [expr 30*$val-10]
	}
	"scroll" {
	    if {$val>0} {
		set scale 1.1
	    } else {
		set scale 0.9
	    }
	    NewGain [expr $v(sig,gain)*$scale]
	}
    }
}

################################################################

# Cursor and selection handling

proc SetCursor {pos {hide 0}} {
    #
    # JOB: Set the time cursor on the waveforms
    #
    # IN: pos, the position of the cursor (time in seconds)
    # OUT: nothing
    # MODIFY: might modify v(frame_wavfm_left(resp. rigth),*) for each waveform
    #
    # Author: ??, Fabien Antoine
    # Version: 1.0
    # Date: Septembre 7, 2005
    # 
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
	 set frame $v(frame_name,$wavfm)
	 # View cursor
	 set margin 0; #[expr $v(frame_wavfm_size,$wavfm)*0.0]
	 if {$pos > $v(frame_wavfm_right,$frame)} {
	    set v(frame_wavfm_left,$frame) [expr $pos + $margin - $v(frame_wavfm_size,$frame)]
	    SynchroWidgets $wavfm
	 } elseif {$pos < $v(frame_wavfm_left,$frame) } {
	   set v(frame_wavfm_left,$frame) [expr $pos - $margin]
	    SynchroWidgets $wavfm
	 }
      }
      DisplayMessage "Cursor : [Tim2Str [expr $v(curs,pos)+$v(sig,base)] 3]\t\t$v(sel,text)"
      SynchroToSignal $pos
      ViewVideo $pos
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
	       set frame $v(frame_name,$win)
	       set v(frame_wavfm_left,frame) [expr $pos-$v(frame_wavfm_size,$frame)/2]
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

   set frame $v(frame_name,$wavfm)
   set bd [expr [$wavfm cget -bd] + [$wavfm cget -padx]]
   set width [expr [winfo width $wavfm] - 2*$bd]
   set x [expr $X - $bd - [winfo rootx $wavfm]]
   if {$x<0} {
      set scroll -1
      set pos $v(frame_wavfm_left,$frame)
   } elseif {$x>$width} {
      set scroll +1
      set pos $v(frame_wavfm_right,$frame)
   } else {
      set scroll 0
      set pos [expr $v(frame_wavfm_left,$frame)+$v(frame_wavfm_size,$frame)*double($x)/$width]
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

    set frame $v(frame_name,$win)
   if [info exists v(sel,start)] {
      CancelSelectEvent
      unset v(sel,start)
      if [GetSelection beg end] {
	 # If selection too short (4 pixels), set only cursor
	 set epsilon [expr 4.0*$v(frame_wavfm_size,$frame)/[winfo width $win]]
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
    set frame $v(frame_name,$win)
    if { ($beg != "" && $end != "") || [GetSelection beg end] } {
      set margin [expr $v(frame_wavfm_size,$frame)*$ratio]
      if {$end-$beg > $v(frame_wavfm_size,$frame)} {
	# If it can't fit completely on screen...
	if {$end == $v(sig,max)} {
	  # center left side of last segment
	  set v(frame_wavfm_left,$frame) [expr $beg-$v(frame_wavfm_size,$frame)/2.0]
	} elseif {$mode == "END" || ($mode == "AUTO" && 
		  $end > $v(frame_wavfm_left,$frame) && $end < $v(frame_wavfm_right,$frame))} {
	  # show end
	  set v(frame_wavfm_left,$frame) [expr $end + $margin - $v(frame_wavfm_size,$frame)]
	} elseif {$mode == "BEGIN" || ($mode == "AUTO"
		  && $beg > $v(frame_wavfm_left,$frame) && $beg < $v(frame_wavfm_right,$frame)) } {
	  # show begin
	  set v(frame_wavfm_left,$frame) [expr $beg - $margin]
	} else {
	  # center
	  set v(frame_wavfm_left,$frame) [expr ($end+$beg-$v(frame_wavfm_size,$frame))/2.0]
	}
      } elseif {$end-$beg > (1-2*$ratio)*$v(frame_wavfm_size,$frame)} {
	# center on the screen with a reduced margin
	set v(frame_wavfm_left,$frame) [expr ($end+$beg-$v(frame_wavfm_size,$frame))/2.0]
      } else {
	if {$end > $v(frame_wavfm_right,$frame)} {
	  # show end plus margin
	  set v(frame_wavfm_left,$frame) [expr $end + $margin - $v(frame_wavfm_size,$frame)]
	} elseif {$beg < $v(frame_wavfm_left,$frame) } {
	  # show begin plus margin
	  set v(frame_wavfm_left,$frame) [expr $beg - $margin]
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

    set frame $v(frame_name,$win)
   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   if [GetSelection beg end] {
      set v(zoom,list) [list $v(frame_wavfm_left,$frame) $v(frame_wavfm_size,$frame)]
      set v(frame_wavfm_left,$frame) $beg
      set v(frame_wavfm_size,$frame) [expr $end-$beg]
      SynchroWidgets $win
      config_entry "Signal" "Unzoom selection" -state normal
   }
}

# Undo last zoom
proc UnZoom {{win ""}} {
   global v

    set frame $v(frame_name,$win)
   if {$win == ""} {
      set win $v(tk,wavfm); # defaults to principal sound frame
   }
   if [info exists v(zoom,list)] {
      set v(frame_wavfm_left,$frame) [lindex $v(zoom,list) 0]
      set v(frame_wavfm_size,$frame) [lindex $v(zoom,list) 1]
      unset v(zoom,list)
      SynchroWidgets $win
      config_entry "Signal" "Unzoom selection" -state disabled
   }
}

proc SaveAudioSegment {{auto ""}} {

    # JOB: save an audio selection
    #
    # IN: nothing
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.3
    # Date: July 18, 2005
    # 
    # Save Audio Segment in normal or automatic mode 
    # Select the name, format and directory of the file to saved 
    # returns empty string if save failed (or was canceled)

    global v 
    
    snack::sound player
    
    if { $auto == "" && $v(sel,begin) == $v(sel,end) } {
	tk_messageBox -icon warning -message [Local "No audio segment selected !"] -title "Warning" -type ok
	return ""
    } else {
	if { $v(sig,cmd) == "" } {
	    set v(sig,name) "empty" 
	    set rep [tk_messageBox -icon question -message [Local "   No audio file opened !\nThis will create an empty\n audio file ! Really save ?"] \
		         -title "Warning" -type yesno]
	    if {$rep == "no"} {
		return
	    } else {
		set format ".wav"
	    }
	} else {
	    set format [file extension $v(sig,name)]
	}
	set types {
	    { "Wave file" {.wav}}
	    { "AU file" {.au}}
	    { "Sound file" {.snd}}
	    { "SD file" {.sd}}
	    { "SMP file" {.smp}}
	    { "AIFF" {.aiff}}
	    { "RAW file" {.raw}}
	    { "All Files" {*}}
	}
	set base [file root [file tail $v(sig,name)]]
	# because the command body of the catch contains return commands, we need to examinate the returns code...
	switch [catch {
	    player conf -file $v(sig,name)
	    PauseAudio
	    
	    # if possible, keep previously open sound file
	    player conf -file $v(sig,name) -channels $v(sig,channels) -frequency $v(sig,rate) -skiphead $v(sig,header) -guessproperties 1
	    if { $v(sig,cmd) != "" } { 
		set rate [$v(sig,cmd) cget -frequency]
		if {$auto == "" } {
		    set zone [concat [format "%6.2f" $v(sel,begin)]-[format "%-6.2f" $v(sel,end)]]
		    set name [tk_getSaveFile -filetypes $types -initialfile "$base\_$zone$format" -initialdir $v(trans,path) -title "Save audio segment"]
		    if {$name == ""} return
		    player write $name -start [expr int($v(sel,begin)*$rate)] -end [expr int($v(sel,end)*$rate)]
		} else {
		    #Automatic mode
		    set loop ""
		    set tot 0
		    foreach segment {"Section" "Turn" "Sync"} {
		        if {$v($segment,loop)} {
		            lappend loop $segment
		        }
		    }
		    if {$loop != ""} {
		        foreach segment $loop {
		            set cpt 0
		            set begin $v(sig,min)
		            set end 0
		            set max $v(sig,max)
		            SetCursor $begin
		            while {$begin < $max} {
		                set nb $v(segmt,curr)
		                set tag [GetSegmtId $nb]
		                if {$segment == "Section"} {
		                    set sec [[$tag getFather] getFather]
		                    set id [::section::long_name $sec]
		                }
		                if {$segment == "Turn" || $segment == "Sync"} {
		                    set tur [$tag getFather]
		                    set spk [$tur getAttr "speaker"]
		                    set spk [::speaker::name $spk]
		                    set id [string trim $spk "_"]
		                }
		                set alnum {[^[:alnum:]]+}
		                regsub -all $alnum $id "_" id
		                
		                TextNext$segment +1
		                set end [GetCursor]
		                if {$end == $begin || $end == 0} {
		                    set end $max
		                }
		                set zone [concat [format "%6.2f" $begin]-[format "%-6.2f" $end]]
		                set num [format "%03.0f" [incr cpt]]
		                set name [file join $v(saveaudioseg,dir) "$base\_$segment$num\_$id\_$zone$format"]
		                regsub -all "__" $name "_" name
		                player write $name -start [expr int($begin*$rate)] -end [expr int($end*$rate)]
		                set tot [incr tot]
		                set begin $end
		            }
		            set v($segment,loop) 0
		        }
		    } 
		}
	    } else {
		set time [expr int([format "%6.3f" [expr $v(sel,end) - $v(sel,begin)]]*16000)]
		set f [snack::filter generator 0.0 0 0.0 sine $time] 
		set s [snack::sound]
		$s filter $f
		$s write $name   
	    }  
	} res] {
	    0 {
		if {$auto != ""} {
		    tk_messageBox -message [format [Local "%s wave segment(s) saved !"] $tot] -type ok -icon info
		} else {
		    tk_messageBox -message [format [Local "%s saved !"] $name] -type ok -icon info
		}
	    }
	    1 { tk_messageBox -message "[Local "Error, wave segment(s) not saved !!"] $res" -type ok -icon error; return "" ;}
	    2 { return ""; }
	} 
    }
}

proc SaveAudioSegmentAuto {} {
    # JOB: open a dialog box to define the option for saving automaticaly each kind of wave segment (turn, section, sync).
    #      you have to choose the destination directory and the element to save  
    #
    # IN: nothing
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: November 29, 2004

    global v

    set w [CreateModal .save [Local "Save audio segments options"]]
    set f [frame $w.top -relief raised -bd 1]
    pack $f -side top -fill both
    set i 0
    foreach segment {"Section" "Turn" "Sync"} {
	set b [checkbutton $f.rad[incr i] -var v($segment,loop) -text [Local $segment]]
	grid $b -row 0 -column "$i"  -sticky w -padx 3m -pady 3m
    }
    EntryFrame $w.dir [Local "Destination directory"] v(saveaudioseg,dir) 50
    set v(saveaudioseg,dir) [pwd]
    if {[OkCancelModal $w $w {"OK" "Cancel"}] == "OK"} {
	SaveAudioSegment auto
    } else return
}
