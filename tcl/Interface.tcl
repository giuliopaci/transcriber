# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc BuildGUI {} {
   LoadImages
   CreateFonts
   CreateWidgets
   SetBindings
   InitMenus
   update
}

#######################################################################

# Generation of user interface : widgets, bindings, menus

proc LoadImages {} {
   global v

#    foreach {name} { } {
#       set photo [image create photo ${name}Img]
#       $photo read [file join $v(path,image) $name.gif]
#    }
   foreach {name} { play pause forward backward circle circle2 over1 over2 music musicl musicr next previous} {
      set v(img,$name) [image create bitmap -file [file join $v(path,image) $name.bmp]]
   }
   $v(img,circle) conf -foreground $v(color,bg-sync)
   $v(img,circle2) conf -foreground $v(color,bg-sync)
   $v(img,over1) conf -foreground $v(color,bg-sync)
   $v(img,over2) conf -foreground $v(color,bg-sync)
}

# Create configurable named fonts for later use
proc CreateFonts {} {
   global v
   foreach var [array names v "font,*"] {
      set name [string range $var [string length "font,"] end]
      catch {
	 eval font create $name [font actual $v(font,$name)]
      }
   }
}

#######################################################################

proc CreateWidgets {} {
   global v

   catch {destroy .edit .cmd .snd .gain .msg}
   CreateTextFrame .edit
   CreateCommandFrame .cmd
   set v(tk,wavfm) [CreateSoundFrame .snd]
   if {!$v(view,.edit)} {
     pack configure .snd -expand true
   }
   #CreateGainFrame .gain
   if {$v(view,.snd2)} {
      CreateSoundFrame .snd2
   }
   CreateMessageFrame .msg
   if {$v(geom,.) != ""} {
      wm geom . $v(geom,.)
   } else {
     if {[info tclversion] >= 8.4 && [tk windowingsystem] == "aqua"} {
       wm geometry . [winfo screenwidth .]x[expr [winfo screenheight .]-44]+0+22 
     } else {
       wm geometry . [winfo screenwidth .]x[expr [winfo screenheight .]-44]+0+22 

     }
   }
}

#######################################################################

proc CreateCommandFrame {f args} {
   global v

   # Commands frame
   frame $f -bd 1 -relief raised 
   set v(tk,play) [button $f.play -command {PlayOrPause}]
   set v(tk,stop) [button $f.pause -command {PlayOrPause} -state disabled]
   button $f.previous -command {MoveNextSegmt -1}
   button $f.next -command {MoveNextSegmt +1}
   button $f.backward
   button $f.forward
   bind $f.backward <Button-1> {BeginPlayForward -1}
   bind $f.forward <Button-1> {BeginPlayForward +1}
   bind $f.backward <ButtonRelease-1> {EndPlayForward}
   bind $f.forward <ButtonRelease-1> {EndPlayForward}
   foreach but {previous backward pause play forward next} {
      $f.$but conf -image $v(img,$but) -width 16 -height 16
      pack $f.$but -side left -padx 1 -pady 1
   }
   $v(img,play) conf -foreground "#70c078"
   $v(img,pause) conf -foreground "#f08020"
   button $f.info -command {CreateInfoFrame} -width 16 -height 16 -bitmap info; pack $f.info -side left -padx 10

   # if one wishes to have buttons for segment/turn/section creation
   if {0} {
      button $f.seg -command {InsertSegment} \
	  -width 16 -height 16 -image $v(img,circle)
      pack $f.seg -side left -padx 1 -pady 1
      button $f.tur -command {ChangeSegType Turn} \
	  -text "Turn" -font info -padx 0 -pady 2 \
	  -activeforeground $v(color,fg-turn) -fg $v(color,fg-turn) \
	  -activebackground $v(color,bg-turn) -bg $v(color,bg-turn)
      pack $f.tur -side left -padx 1 -pady 1
      button $f.sec -command {ChangeSegType Section} \
	  -text "Sect." -font info -padx 0 -pady 2 \
	  -activeforeground $v(color,fg-sect) -fg $v(color,fg-sect) \
	  -activebackground $v(color,bg-sect) -bg $v(color,bg-sect)
      pack $f.sec -side left -padx 1 -pady 1
   }

   label $f.name -textvariable v(sig,shortname) -font info -padx 20
   pack $f.name -side right -fill x -expand true

   # Default : display command frame
   setdef v(view,$f) 1
   if {$v(view,$f)} {
      pack $f -fill x
   }
}

#######################################################################

proc FrameOrTop {f top title} {
   global v

   # Default : do not display frame
   setdef v(view,$f) 0

   # Signal infos frame
   if {$top} {
      toplevel $f
      wm title $f $title
      wm protocol $f WM_DELETE_WINDOW "wm withdraw $f; set v(view,$f) 0"
      if {! $v(view,$f)} {
	 wm withdraw $f
      }
   } else {
      frame $f -relief raised -bd 1
      if {$v(view,$f)} {
	 pack $f -fill x
      }
   }
}

# Signal description (not localized)
proc CreateInfoFrame {{f .inf}} {
   global v

   if {![winfo exists $f]} {
      toplevel $f
      wm title $f [Local "Informations"]

      message $f.sig -font list -justify left \
	  -width 15c -anchor w -textvariable v(sig,desc)
      pack $f.sig -padx 3m -pady 2m -anchor w

      message $f.trans -font list -justify left \
	  -width 15c -anchor w -textvariable v(trans,desc)
      pack $f.trans -padx 3m -pady 2m -anchor w

      button $f.upd -text "Update" -command UpdateInfo
      pack $f.upd -side left -expand 1 -padx 3m -pady 2m

      button $f.close -text "Close" -command [list wm withdraw $f]
      pack $f.close -side left -expand 1 -padx 3m -pady 2m
   } else {
      FrontWindow $f
   }
   update
   UpdateInfo
}

proc UpdateInfo {} {
   global v

   set v(trans,desc) [eval [list format "Transcription:\t$v(trans,name)\nnb. of sections:\t%d\t with %d topics\nnb. of turns:   \t%d\t with %d speakers\nnb. of syncs:   \t%d\nnb. of words:   \t%d"] [TransInfo]]
   TraceInfo
}

# Short file description
proc UpdateShortName {} {
   global v

   set sig   [file tail $v(sig,name)]
   set trans [file tail $v(trans,name)]
   if {[file root $sig] == [file root $trans]} {
      set v(sig,shortname) [file root $sig]
   } elseif {$trans == ""} {
      set v(sig,shortname) $sig
   } elseif {$sig == ""} {
      set v(sig,shortname) $trans
   } else {
      set v(sig,shortname) "$trans\n$sig"
   }
   update idletasks
}

# Vertical zoom
proc CreateGainFrame {{f .gain}} {
   global v dial

   if {![winfo exists $f]} {
      toplevel $f
      wm title $f [Local "Control panel"]

     if {[info tclversion] < 8.4 || [tk windowingsystem] != "aqua"} {
       scale $f.s -label [Local "Volume"] \
	   -orient horiz -length 200 -width 10 \
	   -variable dial(volume) -command {snack::audio play_gain}
       pack $f.s -expand true -fill x -padx 10 -pady 5
     }

      set v(tk,gain)  [scale $f.gain -label [Local "Vertical zoom (dB)"] \
	       -orient horizontal -length 200 -width 10 -showvalue 1 \
	       -from -10 -to 20 -tickinterval 10 -resolution 1 \
	       -variable v(sig,gain) -command [list NewGain]]
      pack $f.gain -expand true -fill x -padx 10 -pady 5

      # Disabled, since changing frequency is not yet available
      scale $f.freq -label [Local "Adjust playback speed (%)"] \
	  -orient horiz -length 200 -width 10 \
	  -from -40 -to 60 -tickinterval 20 -resolution 1 \
	  -command {AdjustPlaybackSpeed}
      #pack $f.freq -expand true -fill x -padx 10 -pady 5

      button $f.close -text [Local "Close"] -command [list wm withdraw $f]
      pack $f.close -side bottom -expand 1 -padx 3m -pady 2m
   } else {
      FrontWindow $f
   }
   set dial(volume) [snack::audio play_gain]
}

proc AdjustPlaybackSpeed {val} {
   global v

   set play [IsPlaying]
   if {$play} {PauseAudio}
   set v(playbackSpeed) [expr 1.0+$val/100.0]
   if {$play} {Play}
}

proc SwitchFrame {f args} {
   global v

   if {[winfo class $f] == "Toplevel"} {
      # Always bring to top
      if {[winfo ismapped $f]} {
	 wm withdraw $f
	 set v(view,$f) 0
      } else {
	 wm deiconify $f
	 set v(view,$f) 1
      }
   } else {
      # Switch display/hide
      if {[winfo ismapped $f]} {
	 pack forget $f
	 set v(view,$f) 0
      } else {
	 eval pack $f -fill x $args
	 set v(view,$f) 1
      }
   }
}

#######################################################################

proc CreateMessageFrame {f} {
   global v

   label $f -font mesg -textvariable v(var,msg) \
       -justify left -anchor w -bg $v(color,bg) -padx 10 -relief raised -bd 1
   pack $f -fill x -side bottom
   bind $f <Button-1> EditCursor
}

proc DisplayMessage {text} {
   global v

   set v(var,msg) $text
}

#######################################################################

proc SetBindings {} {
   global v

   # Mouse events
   #bind all <Enter> {focus %W}

   # Forget existing bindings
   foreach b [bind .] {bind . $b {}}

   # Some aliases for keyboard events
   bind . <Pause> {PlayOrPause}
   bind . <Alt-Tab> {PlayCurrentSegmt}
   # alternative for Shift-Tab already defined in menu bindings
   catch {bind . <Key-ISO_Left_Tab> {PlayCurrentSegmt; break}}
   # the break added in previous should make following useless:
   # bind all <<PrevWindow>> {}
}

#######################################################################

proc ConfigureGeneral {} {
   
	#global but
	global v
    global env
   # Keep initial values for 'Cancel' (but not for 'lang')
   foreach name {
      scribe,name autosave,time backup,ext encoding
      debug trace,name lang space,auto spell,names
   } {
      lappend initConf $name $v($name)
   }

   set f .col
   CreateModal $f "General options"

   set g [frame $f.fr0 -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   EntryFrame $g.en1 "Default scribe's name" v(scribe,name)
   EntryFrame $g.en2 "Log trace in file" v(trace,name)
   EntryFrame $g.en3 "External Speakers Database " v(list,ext) 
   
   # Menu to choose the default browser
    set i [frame $g.fr]
    pack $i -fill both -expand true -side top
    label $i.lab -text [Local "Default browser:"]
    set v(browser,but) [button $i.v(browser,but) -text [Local $v(browser)] -default disable  ]
    bind $i.v(browser,but) <Button-1>	{
    set v(browser) [SelectBrowser]
    $v(browser,but) configure -text $v(browser)
    }
    pack $i.lab $i.v(browser,but) -side left -padx 3m -pady 3m -fill x -expand true
   
   set g [frame $f.fr1 -relief raised -bd 1 -width 25c]
   pack $g -fill both -expand true -side top
   EntryFrame $g.en1 "Auto-save interval (in minutes)" v(autosave,time)
   EntryFrame $g.en2 "Backup extension" v(backup,ext)

   if {![catch {encoding system}]} {
      EncodingChooser $f
   }

   set g [frame $f.fr3 -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   checkbutton $g.en7 -text [Local "Ask user to save configuration before leaving"] -variable v(keepconfig) -anchor w -padx 3m -pady 2m
   MenuFrame $g.defpos "Default text cursor position" v(preferedPos) {
      "Start of line"
      "End of line"
   } {"begin" "end"}
   checkbutton $g.en5 -text [Local "Automatic space insertion"] -variable v(space,auto) -anchor w -padx 3m -pady 2m
   checkbutton $g.en6 -text [Local "Check spelling of capitalized words"] -variable v(spell,names) -anchor w -padx 3m -pady 2m
   checkbutton $g.en8 -text [Local "Debug menu"] -variable v(debug) -command {InitMenus} -anchor w -padx 3m -pady 2m
   pack $g.en7 $g.en5 $g.en6 $g.en8 -side top -expand true -fill x

   set g [frame $f.fr4 -relief raised -bd 1]
   pack $g -fill both -expand true -side top
   set h [frame $g.fr]
   pack $h -fill both -expand true -side top
   # Menu for language selection
   set langlist {}
   set langother {}
   set current_nam ""
   foreach {lang nam} [join $v(language)] {
      set nam [Local $nam]
      if {$lang == $v(lang)} {
	 set current_nam $nam
      }
     if {$lang == "en" || [info exists ::local_$lang] || [file readable [file join $v(path,etc) "local_$lang.txt"]]} {
	 lappend langlist $lang $nam
      } else {
	 lappend langother $lang $nam
      }
   }
   label $h.lab -text "[Local Language]:"
   menubutton $h.en5 -text $current_nam -menu $h.en5.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -width [maxlength $v(language)]
   menu $h.en5.menu -tearoff 0
   foreach {val nam} $langlist {
      if {$val=="en"} {
	 set stat "disabled"
      } else {
	 set stat "normal"
      }
      $h.en5.menu add radiobutton -label $nam -variable v(lang) -value $val -command "ChangedLocal; $h.en5 conf -text $nam; $h.but conf -state $stat"
   }
   $h.en5.menu add cascade -label [Local "New language"] -menu $h.en5.menu.oth
   menu $h.en5.menu.oth -tearoff 0
   foreach {val nam} $langother {
      $h.en5.menu.oth add radiobutton -label $nam -variable v(lang) -value $val -command "ChangedLocal; $h.en5 conf -text $nam; $h.but conf -state normal"
   }
   button $h.but -text [Local "Edit translation"] -command {EditLocal}
   if {$v(lang) == "en"} {$h.but conf -state disabled}
   pack $h.lab $h.en5 $h.but -side left -padx 3m -pady 3m -fill x -expand true
   EntryFrame $g.en7 "Localization file" v(file,local)

   # Wait for answer and undo changes if 'Cancel'
   set answer [OkCancelModal $f $f]
   if {$answer != "OK"} {
      set newlang $v(lang)
      array set v $initConf
      if {$v(lang) != $newlang} {
	 ChangedLocal
      }
   } else {
       ::speaker::reset_dbg
       ::speaker::importg $env(HOME)/[file tail $v(list,ext)]
       ::speaker::store_dbg
       TraceInit 1
   }
}

#######################################################################

# Edit v(encoding) within $f frame - called by ConfigureGeneral
proc EncodingChooser {f} {
   global v

   set e [frame $f.enc -relief raised -bd 1]
   pack $e -fill both -expand true -side top

   label $e.lab -text "[Local Encoding]:"
   menubutton $e.men -indicatoron 1 -menu $e.men.menu -relief raised -bd 2 -highlightthickness 2 -anchor c
   menu $e.men.menu -tearoff 0
   set len 20
   # List of encoding: IANA name/usual name
   foreach subl $v(encodingList) {
      if {$subl == ""} {
	 $e.men.menu add separator
	 continue
      }
      foreach {val name} $subl {}
      if {$name == ""} {
	 set name $val
      }
      set name [Local $name]
      set len [max $len [string length $name]]
      if {$val == $v(encoding)} {
	 $e.men configure -text $name
      }
      $e.men.menu add radiobutton -label $name -variable v(encoding) -value $val -command [list $e.men configure -text $name]
   }
   $e.men configure -width $len
   pack $e.lab $e.men -side left -padx 3m -pady 3m -fill x -expand true
}

# Try to find an available Tcl encoding matching the given IANA name
# and return it, or else an empty string.
proc EncodingFromName {iana} {
   set enc [string tolower $iana]
   regsub "iso-" $enc "iso" enc
   regsub "_" $enc "" enc
   # resolve confusion: IANA gb_2312-80 => Tcl gb2312; IANA gb2312 => Tcl euc-cn
   regsub "gb2312" $enc "euc-cn" enc   
   if {[lsearch [encoding names] $enc] >= 0} {
      return $enc
   } else {
      return ""
   }
}

#######################################################################

proc EditGlossary {} {
   global v

   # When a selection is active, propose its content as default value
   set new {}
   if {[$v(tk,edit) tag ranges sel] != {}} {
      set new [list [CopyAll sel.first sel.last] ""]
   }
   catch {
      set v(glossary) [ListEditor $v(glossary) "Glossary" \
			   {"Value" "Comment"} $new GlosBack]
   }
}

proc GlosBack {} {
   global v lst

   button .lst.bot.ins -text [Local "Insert"] -command {GlosIns}
   pack .lst.bot.ins -side left -after .lst.bot.ok -padx 3m -pady 2m -fill x -expand true
}

proc GlosIns {} {
   global v lst

   PasteAll $v(tk,edit) $lst(f0)
   set lst(result) "Insert"
}

#######################################################################

proc ConfigureBindings {} {
   global v

   # When a selection is active, propose its content as default value
   set new {}
   if {[$v(tk,edit) tag ranges sel] != {}} {
      set new [list "" [CopyAll sel.first sel.last]]
   }
   catch {
      RegisterBindings [ListEditor $v(bindings) "Bindings" \
			{"Keystrokes" "Replacement string"} $new BindBack]
   }
}

# Inside binding editor, replace keystroke with corresponding string
proc BindBack {} {
   global v lst

   catch {
      bind $lst(e0) <Alt-KeyPress> {if {[string length %A] > 0} {tkEntryInsert %W "<Alt-%K>"}; break}
      bind $lst(e0) <Control-KeyPress> {if {[string length %A] > 0} {tkEntryInsert %W "<Control-%K>"}; break}
      bind $lst(e0) <Control-Alt-KeyPress> {if {[string length %A] > 0} {tkEntryInsert %W "<Control-Alt-%K>"}; break}
   }
}

proc RegisterBindings {new} {
   global v

   foreach subl $v(bindings) {
      foreach {s1 s2} $subl {}
      bind Text $s1 ""
   }
   set v(bindings) $new
   foreach subl $v(bindings) {
      foreach {s1 s2} $subl {}
      # count plain chars to delete before current char - can be wrong !
      regsub -all "<(Control|Alt|Meta)-\[^>]+>" $s1 "" s3
      regsub -all "<\[^>]+>" $s3 "." s3
      set l [expr [string length $s3]-1]
      catch {
	 if {$l > 0} {
	    bind Text $s1 "%W delete insert-${l}c insert; PasteAll %W [list $s2]; break"
	 } else {
	    bind Text $s1 "PasteAll %W [list $s2]; break"
	 }
      }
   }
}

#######################################################################

proc ConfigureColors {} {
   global v

   set f .col
   CreateModal $f "Configure colors"
   
   set i 0
   foreach set {
      {"Waveform bg"		bg
	 "selected"		bg-sel}
      {"Segments foreground"	fg-sync
	 "background"		bg-sync}
      {"Current segment"	hi-sync}
      {"Speaker foreground"	fg-turn
	 "background"		bg-turn}
      {"Sections foreground"	fg-sect
	 "background"		bg-sect}
      {"Noise foreground"	fg-back
	 "background"		bg-back}
      {"Text foreground"	fg-text
	 "background"		bg-text}
      {"Highlighted text bg"	hi-text}
      {"Event foreground"	fg-evnt
	 "background"		bg-evnt}
   } {
      set g [frame $f.fr[incr i] -bd 1 -relief raised]
      pack $g -side top -fill x -ipady 1m
      foreach {title var} $set {
	 lappend old $var $v(color,$var)
	 ColorFrame $g.$var $title v(color,$var)
	 pack $g.$var -side left
      }
   }
   # Undo changes after "Cancel"
   if {[OkCancelModal $f $f] != "OK"} {
      foreach {var val} $old {
	 set v(color,$var) $val
      }
      UpdateColors
   }
}

# Change configuration color and redisplay widgets
proc ChooseColor {varName} {
   global v
   upvar $varName var

   set color [tk_chooseColor -initialcolor $var]
   if {$color != ""} {
      set var $color
      UpdateColors
   }
}

proc UpdateColors {} {
   global v

   foreach wavfm $v(wavfm,list) {
      set f [winfo parent $wavfm] 
      if [winfo exists $f.seg0] {
	 $f.seg0 config -fg $v(color,fg-sync) -full $v(color,bg-sync)
      }
      if [winfo exists $f.seg1] {
	 $f.seg1 config -fg $v(color,fg-turn) -full $v(color,bg-turn)
      }
      if [winfo exists $f.seg2] {
	 $f.seg2 config -fg $v(color,fg-sect) -full $v(color,bg-sect)
      }
      if [winfo exists $f.bg] {
	 $f.bg config -fg $v(color,fg-back) -full $v(color,bg-back)
      }
      foreach w [concat $f [winfo children $f]] {
	 if {[winfo class $w] != "Scrollbar"} {
	    $w config -bg $v(color,bg)
	 }
      }
      $wavfm config -selectbackground $v(color,bg-sel)
   }
   .msg config -bg $v(color,bg)
   if [info exists v(tk,edit)] {
      set t $v(tk,edit)-bis
      $t conf -bg $v(color,bg-text) -fg $v(color,fg-text)
      $t tag conf "event" -background $v(color,bg-evnt) -foreground $v(color,fg-evnt)
      foreach w [$t window names] {
	 switch -glob -- [$w conf -command] {
	    *section* {
	       $w conf -activeforeground $v(color,fg-sect) \
		   -fg $v(color,fg-sect) \
		   -activebackground $v(color,bg-sect) -bg $v(color,bg-sect)
	    }
	    *turn* {
	       $w conf -activeforeground $v(color,fg-turn)\
		   -fg $v(color,fg-turn) \
		   -activebackground $v(color,bg-turn) -bg $v(color,bg-turn)
	    }
	 }
      }
      $v(img,circle) conf -foreground $v(color,bg-sync)
      $v(img,over1) conf -foreground $v(color,bg-sync)
      $v(img,over2) conf -foreground $v(color,bg-sync)
   }
}

proc RandomColor {} {
  set sum 0
  while {$sum < 384} {
    set col "\#"
    set sum 0
    foreach c {r g b} {
      set d [expr int(rand()*256)]
      append col [format "%02x" $d]
      incr sum $d
    }
  }
  return $col
}

proc ColorMap {val {col ""}} {
  global color
  regsub -all "\[ _-]" $val "" val
  set val [string tolower $val]
  if {$col != ""} {
    set color($val) $col
  } elseif {[info exists color($val)]} {
    set col $color($val)
  } else {
    set col [RandomColor]
    set color($val) $col
  }
  return $col
}

proc ColorizeSpk {{segmt seg1}} {
  global v color
  if {$v(colorizeSpk)} {
    ColorMap ([Local "no speaker"]) $::v(color,bg)
    for {set i 0} {$i < [GetSegmtNb $segmt]} {incr i} {
      SetSegmtField $segmt $i -color [ColorMap [GetSegmtField $segmt $i -text]]
    }
  } else {
    catch {unset color}
    for {set i 0} {$i < [GetSegmtNb $segmt]} {incr i} {
      SetSegmtField $segmt $i -color ""
    }
  }
}
