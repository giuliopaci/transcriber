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

    # JOB: create all the widgets of the interface
    #
    # IN: nothing
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

    global v

    catch {destroy .edit .cmd .snd .snd2 .gain .msg}
    CreateTextFrame .edit
    CreateCommandFrame .cmd
 
    if {!$v(view,.edit)} {
	pack configure .snd -expand true
    }

    #CreateGainFrame .gain
    
    set v(tk,wavfm) [CreateSoundFrame .snd]
    CreateSoundFrame .snd2
    CreateNEFrame .edit.ne
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

########################################################

proc CreateNEFrame {f} {

    # JOB: create the NE interface in the text widget for esay creation of entities events
    #
    # IN: f, name of the window created
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004

    global v

    # set the list Named Entities (NE) by macroclass
    set v(listNE,macroclass) {"pers" "org" "gsp" "loc" "fac" "prod" "time" "amount" "meto" "unk" "user"}

    if {[winfo exists $f]} {DestroyNEFrame $f}

    # make dynamicaly the different list of macroclass by taking the list of all the entities in the configuartion file if exists else in the default.txt
    foreach ent $v(entities) {
	set name [lindex $ent 0]
	# the metonymy entities are detected by the presence of the "/" character in the name
	if { [regexp "/" $name] } {
	    lappend v(listNE,meto) $name
	    continue
	} else {
	    set find 0
	    foreach macro $v(listNE,macroclass) {
		if { [regexp "^$macro" $name] } {
		    lappend v(listNE,$macro) $name
		    set find 1
		    break
		} 
	    }
	    # if the entity doesn't match any macroclass, add it to user entities class 
	    if { $find == 0 } {
		lappend v(listNE,user) $name
	    }
	}
    }
    if { ![info exists v(listNE,user)] } {
	set v(listNE,user) ""
    }

   set v(listNE,all) [concat "$v(listNE,pers)" "$v(listNE,org)"  "$v(listNE,gsp)" "$v(listNE,loc)" "$v(listNE,fac)" "$v(listNE,prod)" "$v(listNE,time)" "$v(listNE,amount)" "$v(listNE,meto)" "$v(listNE,user)"]

    frame $f -bd 1 -relief raised
    set row 0
    set column 0
 
    # create the interface with buttons
    foreach macro $v(listNE,macroclass) {
	frame $f.$macro
	foreach micro $v(listNE,$macro) {
	    regsub -all {\.} $micro "" name
	    if { $v(checkNEcolor,buton) == 1 } {
		button $f.$macro.$name -text $micro -font $v(font,NEbutton) -bg $v(color,netag-$macro) -pady 0 -width [maxlength $v(listNE,all)] -command "CreateAutoEvent $micro entities"
	    } else {
		button $f.$macro.$name -text $micro -font $v(font,NEbutton) -pady 0 -width [maxlength $v(listNE,all)] -command "CreateAutoEvent $micro entities"
	    }
	    pack $f.$macro.$name -ipadx 2
	}
	grid $f.$macro -row $row -column $column -padx 2 -pady 6 -sticky n
	incr column
	# control the number of column
	if {$column>2} {
	    set column 0
	    incr row 
	}
	unset v(listNE,$macro)
    } 

    set g [frame $f.auto -borderwidth 5 -relief raised]

    label $g.label -text [Local Automatic] 
    grid $g.label -row 1 -column 0

    entry $g.entry -textvariable v(find,what) 
    grid $g.entry -row 1 -column 1
    set h [frame $g.radio -relief raised]
    set i [frame $h.left]
    set j [frame $h.right]
    label $i.label -text "Mode:"
    grid $i.label -row 0 -column 2 -padx 10
    radiobutton $j.radioadd -text [Local Add] -variable v(autoNE) -value Add
    grid $j.radioadd -sticky w 
    radiobutton $j.radiosup -text [Local Suppress] -variable v(autoNE) -value Suppress
    grid $j.radiosup -sticky w 
    grid $i -row 1 -column 2
    grid $j -row 1 -column 3
    grid $h -row 1 -column 2 -columnspan 2
    grid $g  -pady 10 -row [expr $row+2] -column 0 -columnspan 3

    if {$v(view,$f)} {
	pack $f -fill both -expand true
    }
}

proc DestroyNEFrame {f} {

    # JOB: destroy the NE interface
    #
    # IN: f, name of the NE window to destroy
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004


    global v

    catch {destroy $f}
    set v(view,$f) 0
}

proc UpdateNEFrame {f} {

    # JOB: update the NE interface
    #
    # IN: f, name of the NE window
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004


    global v
 
    set oldview $v(view,$f)
    DestroyNEFrame $f
    set v(view,$f) $oldview
    CreateNEFrame $f
}

proc SwitchNEFrame {f} {

    # JOB: switch the display of the NE interface
    #
    # IN: f, name of the NE window
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004


    global v
 
    if {![winfo exists $f]} {
	CreateNEFrame .edit.ne
    } elseif {[winfo ismapped $f]} {
	pack forget $f
    } else {
	pack $f -fill y -side right
    }
}

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

	if {$::tcl_platform(platform) == "windows"} {
	      wm attributes $f -topmost 1 
      }

      message $f.sig -font list -justify left \
	  -width 15c -anchor w -textvariable v(sig,desc)
      pack $f.sig -padx 3m -pady 2m -anchor w

      message $f.trans -font list -justify left \
	  -width 15c -anchor w -textvariable v(trans,desc)
      pack $f.trans -padx 3m -pady 2m -anchor w

       button $f.upd -text [Local "Update"] -command UpdateInfo
      pack $f.upd -side left -expand 1 -padx 3m -pady 2m

       button $f.close -text [Local "Close"] -command [list wm withdraw $f]
      pack $f.close -side left -expand 1 -padx 3m -pady 2m
   } else {
      FrontWindow $f
   }
   update
   UpdateInfo
}

proc UpdateInfo {} {
    global v

    set v(trans,desc) [eval [list format "Transcription:\t$v(trans,name)\n[Local "nb. of sections:"]\t%d\t [Local "with %d topics"]\n[Local "nb. of turns:"]   \t%d\t [Local "with %d speakers"]\n[Local "nb. of syncs:"]   \t%d\n[Local "nb. of words:"]   \t%d"] [TransInfo]]
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

	if {$::tcl_platform(platform) == "windows"} {
	      wm attributes $f -topmost 1 
      }

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
   if {$v(view,$f)} {
   pack $f -fill x -side bottom
   }
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
    global v env
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
    EntryFrame $g.en3 "Global speakers database" v(list,ext) 
    
    # Menu to choose the default browser
    set i [frame $g.fr]
    pack $i -fill both -expand true -side top
    label $i.lab -text [Local "Default browser:"]
    set v(browser,but) [button $i.v(browser,but) -text [Local $v(browser)] -default disabled ]
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
   regsub "macintosh" $enc "macRoman" enc
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
      bind $lst(e0) <Command-KeyPress> {if {[string length %A] > 0} {tkEntryInsert %W "<Command-%K>"}; break}
      bind $lst(e0) <Option-KeyPress> {if {[string length %A] > 0} {tkEntryInsert %W "<Option-%K>"}; break}
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
      regsub -all "<(Control|Alt|Meta|Command|Option)-\[^>]+>" $s1 "" s3
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

    # JOB: Configure the colors of the interface. Called by the menu Options->Colors...
    #
    # IN: nothing
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

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
	{"NE pers"	netag-pers
	    "NE org"		netag-org}
	{"NE gsp"	netag-gsp
	    "NE loc"		netag-loc}
	{"NE fac"	netag-fac
	    "NE prod"		netag-prod}
	{"NE time"	netag-time
	    "NE amount"		netag-amount}
	{"NE metonymy"	netag-meto
	    "NE unknown"		netag-unk}
    } {
	set g [frame $f.fr[incr i] -bd 1 -relief raised]
	pack $g -side top -fill x -ipady 1m
	foreach {title var} $set {
	    lappend old $var $v(color,$var)
	    ColorFrame $g.$var $title v(color,$var)
	    pack $g.$var -side left
	}
    }
    # check buttons that allow to use or not the color with entities (tag, text and button)
    set g [frame $f.checkNE -bd 1 -relief raised]
    checkbutton $g.enttag -text [Local "Use color for NE tag"] -variable v(checkNEcolor,tag) -command { UpdateColors }
    pack $g.enttag -side left -padx 10
    checkbutton $g.enttext -text [Local "Use color for NE text"] -variable v(checkNEcolor,text) -command { UpdateColors }
    pack $g.enttext -side left -padx 10
    checkbutton $g.entbuton -text [Local "Use color for NE buton"] -variable v(checkNEcolor,buton) -command [list UpdateNEFrame .edit.ne]
    pack $g.entbuton -side left -padx 10
    pack $g -side top -fill x -expand true

    # Undo changes after "Cancel"
    if {[OkCancelModal $f $f] != "OK"} {
	foreach {var val} $old {
	    set v(color,$var) $val
	}
	UpdateColors
    }
}

proc ChooseColor {varName} {

    # JOB: Change configuration color with a popup to choose the color and redisplay widgets. Called by ColorFrame and ConfigureColors
    #
    # IN: varName, nale of the color variable to change
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras
    # Version: 1.0
    # Date: 1999

    global v
    upvar $varName var
    
    set color [tk_chooseColor -initialcolor $var]
    if {$color != ""} {
	set var $color
	UpdateColors
    }
}

proc UpdateColors {} {

    # JOB: Update the color of all the interface. Called by ChooseColor
    #
    # IN: nothing
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

   global v

   # Update the entities colors in the text and in the NE interface
   UpdateNEColors
   UpdateNEFrame .edit.ne

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

proc UpdateNEColors {} {

    # JOB: switch the display of the NE interface
    #
    # IN: f, name of the NE window
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004

    global v

    set t $v(tk,edit)-bis

    foreach macro "$v(listNE,macroclass) meto" {
	foreach part {"tag" "text"} {
	    if { $v(checkNEcolor,$part) == 1 } {
		$t tag conf NE$macro$part -foreground  $v(color,netag-$macro)
	    } else {
		$t tag conf NE$macro$part -foreground  black
	    }
	}
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
