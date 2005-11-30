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
    
    foreach {name} { } {
	set v(img,$name) [image create bitmap -file [file join $v(path,image) $name.bmp]]
    }
    foreach {name} { info pause forward backward circle circle2 over1 over2 music musicl musicr next previous play transfile wavfile folder updir close folder_green empty textfile } {
	set v(img,$name) [image create photo -file [file join $v(path,image) $name.gif]]
    }
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

proc ConfigureCanvas {} {
    global v
    
    foreach var [array names v "frame*,*" ] {
	if [regexp "type|content|before|after|container|pos|frame," $var] {
	    unset v($var)
	}
    }
    
    if {![info exists v(canvas,type)]} {
	set v(canvas,type) canvas1
    }
    
    switch $v(canvas,type) {
	"canvas1" {
	    # first global canvas :
	    #___________________________________
	    #           |notebooked      | video |
	    # database  |      text      |_______|
	    # explorer  |                |       |
	    #           |                |annot. |
	    #           |----------------|toolbox|
	    #           |      media     |       |
	    #           |    navigator   |       |
	    #___________|________________|_______|
	    #
	    # 
	    set v(frame_type,main) {paned horizontal autoresize}
	    set v(frame_content,main) {database central toolbox}
	    set v(frame_type,database) {paned horizontal}
	    set v(frame_content,database) {explorer}
	    set v(frame_type,central) { frame vertical stretch}
	    set v(frame_content,central) {text  navigator}
	    set v(frame_type,navigator) { frame vertical -fill x } 
	    set v(frame_type,snd) {  -fill x }
	    set v(frame_type,snd2) {  -fill x }
	    
	    set v(frame_content,navigator) { cmd gain snd snd2 msg}
	    set v(frame_type,toolbox) {frame vertical}
	    set v(frame_content,toolbox) {video attributes ne }
	    set v(frame_content,attributes) {background episode event turn}
	    set v(frame_type,ne) { -fill y }
	    set v(frame_type,msg) {  -fill x }
	    set v(frame_type,text) {  -expand true -fill both -side top     }
	}
	"canvas2" {
	    # second global canvas :
	    #___________________________________
	    #           |     video      |       |
	    # database  |                |       |
	    # explorer  |----------------|       |
	    #           |     text       |annot. |
	    #           |----------------|toolbox|
	    #           |      media     |       |
	    #           |    navigator   |       |
	    #___________|________________|_______|
	    #
	    # 
	    set v(frame_type,main) {paned horizontal autoresize}
	    set v(frame_content,main) {database central toolbox}
	    set v(frame_type,database) {paned horizontal}
	    set v(frame_content,database) {explorer}
	    set v(frame_type,central) { frame vertical stretch}
	    set v(frame_content,central) {video text  navigator}
	    set v(frame_type,navigator) { frame vertical -fill x } 
	    set v(frame_type,snd) {  -fill x }
	    set v(frame_type,snd2) {  -fill x }
	    
	    set v(frame_content,navigator) { cmd gain snd snd2 msg}
	    set v(frame_type,toolbox) {paned vertical}
	    set v(frame_content,toolbox) { attributes ne }
	    set v(frame_content,attributes) {background episode event turn}
	    set v(frame_type,msg) {  -fill x }
	    set v(frame_type,text) {  -expand true -fill both -side top     }	    
	}
	"canvas3" {
	    # third global canvas :
	    #__________________________________
	    #         |notebooked     |       |
	    # database|     video     |annot. |
	    # explorer|               |toolbox|
	    #         |---------------|       |
	    #         |     text      |       |
	    #---------------------------------|
	    #               media             |
	    #             navigator           |
	    #_________________________________|
	    #
	    #
	    set v(frame_type,main) {frame vertical}
	    set v(frame_content,main) {top navigator}
	    set v(frame_type,top) {paned horizontal autoresize   -expand true -fill both -side top  }
	    set v(frame_content,top) {database central toolbox}
	    set v(frame_type,database) {paned horizontal}
	    set v(frame_content,database) {explorer}
	    set v(frame_type,central) { frame vertical stretch}
	    set v(frame_content,central) {video text}
	    set v(frame_type,navigator) { frame vertical -fill both  } 
	    set v(frame_type,snd) {  -fill both }
	    set v(frame_type,snd2) {  -fill both }
	    
	    set v(frame_content,navigator) { cmd gain snd snd2 msg}
	    set v(frame_type,toolbox) {paned vertical}
	    set v(frame_content,toolbox) { attributes ne }
	    set v(frame_content,attributes) {background episode event turn}
	    set v(frame_type,msg) {  -fill both }
	    set v(frame_type,text) {  -expand true -fill both -side top     }
	}
    }
}

proc ChangeCanvas {canvas} {
    global v

    if {[HasModifs]} {
	set answer [tk_messageBox -message [Local "Transcription has been modified - It need to be saved before you change the canvas - do you want to proceed and save your work?"] -type yesnocancel -icon question]
	switch $answer {
	    cancel { return  }
	    yes    { if {[SaveTrans]==""} {return -code error cancel} }
	    no     { }
	}
    }
    
    DestroyFrame main
    set v(canvas,type) $canvas
    set oldsnd $v(frame,snd)
    set oldsnd2 $v(frame,snd2)
    ConfigureCanvas
    set v(wavfm,list) {}

    CreateFrame main

    foreach pattern [list  "$oldsnd,*" "$oldsnd.*" "*,$oldsnd" "*,$oldsnd.*"] {
	foreach varname [array names v $pattern] {
	    set oldvarname $varname
	    set tmp [regsub "$oldsnd" $varname "$v(frame,snd)"]
	    set content [regsub "$oldsnd" $v($varname) "$v(frame,snd)"]
	    if {$varname != $oldvarname} {
		unset v($varname)
	    }
	}
    }

    ReadTrans $v(trans,name)
    foreach wavfm $v(wavfm,list) {
	ConfigWavfm $wavfm
    }
    CreateAllSegmentWidgets
    SetCursor [GetCursor]

}


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

    ConfigureCanvas 
    
    CreateFrame main

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
proc PrevShowedFrame {f} {
    # JOB: returns the frame before f
    #
    # IN: f, the name of the frame
    # USES: v(frame_before,$f) and so on 
    # OUT: the frame before f
    #
    # Author: Fabien Antoine
    # Version : 1
    # Date: June 28, 2005    
    global v
    if [info exists v(frame_before,$f)] {
	if {[winfo exists $v(frame,$v(frame_before,$f))] && [winfo ismapped $v(frame,$v(frame_before,$f))]} {
	    return $v(frame_before,$f)
	} else {
	    return [PrevShowedFrame $v(frame_before,$f)]
	}
    } else {
	return ""
    }
}

proc NextShowedFrame {f} {
    # JOB: returns the frame after f
    #
    # IN: f, the name of the created frame
    # USES: v(frame_after,$f) and so on 
    # OUT: the frame after f
    #
    # Author: Fabien Antoine
    # Version : 1
    # Date: June 28, 2005    
    global v
    if [info exists v(frame_after,$f)] {
	if {[winfo exists $v(frame,$v(frame_after,$f))] && [winfo ismapped $v(frame,$v(frame_after,$f))]} { 
	    return $v(frame_after,$f)
	} else {
	    return [NextShowedFrame $v(frame_after,$f)]
	}
    } else {
	return ""
    }
}


proc CreateFrame {f} {
    # JOB: create a frame in the interface
    #
    # IN: f, the name of the created frame
    # USES: v(container,$f) scheme for the interface
    # OUT: nothing
    #
    # Author: Fabien Antoine
    # Version : alpha0
    # Date: June 16, 2005

    global v
    set v(frame_creation,$f) 1
    
    #path of the frame
    if {[info exists v(frame_container,$f)]} {
	set v(frame,$f) $v(frame,$v(frame_container,$f)).$f
	set v(frame_name,$v(frame,$f)) $f
    } else {
	set v(frame,$f) .$f
	set v(frame_name,$v(frame,$f)) $f
    }
    

    #type and childs of the input frame    
    if {[info exists v(frame_type,$f)]} {
	set type   $v(frame_type,$f) 
	set opts [lsearch -all -inline -regexp -not $type "pane.*|vert.*|hor.*|autoresize.*|stretch|notebook.*"]
    } else {
	set type ""
	set opts ""
    }

    if {[info exists v(frame_content,$f)]} {
	set childs $v(frame_content,$f)
	set before ""
	foreach child $childs {
	    if {$before != ""} {
		set v(frame_before,$child) $before
		set v(frame_after,$before) $child
	    }
	    set v(frame,$child) $v(frame,$f).$child
	    set v(frame_container,$child) $f
	    set before $child
	}
    } else {
	set childs {}
    }


    if {[winfo exists $v(frame,$f)]} {DestroyFrame $f}

    # type-dependent frame creation
    if {[lsearch $type "pane*"] >=0} {
	# panedwindow type (available since tcl-tk 8.4)
	set orient horizontal
	if {[lsearch $type "vert*"] >= 0} {
	    set orient vertical
	}      
	switch $orient {
	    horizontal { set LEN width ; set index 0}
	    vertical { set LEN height ; set index 1}
	}
	panedwindow $v(frame,$f) -orient $orient -showhandle 0 
    } elseif {[lsearch $type "notebook*"] >=0} {
	#notebooked type
	package require BWidget
	NoteBook $v(frame,$f) 
    } else {
	#default simple frame type
	frame $v(frame,$f)
    }    

    if ([info exists v(frame_container,$f)]) {
	if [info exists v(frame_type,$v(frame_container,$f))] {
	    set container_type $v(frame_type,$v(frame_container,$f))
	    if {[lsearch $container_type "notebook*"] >=0} {
		set $v(frame,$f) $v(frame,$v(frame_container,$f)).pane$f.$f
		eval $v(frame,$v(frame_container,$f)) insert 0 pane$f 
	    }
	}
    }
    
    #specific frame creation procedures
    # if frame type is among "text", "snd", "msg", "ne", "explorer" or "cmd", then use 
    # specific proc to create the frame
	if {[regexp "text" $f]} {
	    CreateTextFrame $v(frame,$f)
	} elseif {[regexp "snd*" $f]} {
	    CreateSoundFrame $f
	} elseif {[regexp "msg" $f]} {
	    CreateMessageFrame $v(frame,msg)
	} elseif {[regexp "ne" $f]} {
	    CreateNEFrame $f
	} elseif {[regexp "cmd" $f]} {
	    CreateCommandFrame $v(frame,cmd)
	} elseif {[regexp "explorer" $f]} {
	    CreateBrowserFrame $f
	}

    set viewable_childs 0
    foreach child $childs {
	# recursively create child frames

	if $v(frame_view,$child) {
	    incr viewable_childs
	}
	CreateFrame $child
	if {[lsearch $type "autoresize"] >=0} {
	    bind $v(frame,$child) <Configure> [list RememberPanesSize $f]
	}

    }
    
    if {[lsearch $type "pane*"] >=0} {
	if {[lsearch $type "autoresize"] >=0} {
	    if {$viewable_childs != 0} {
		ResizePanedFrame $f
	    }
	    bind $v(frame,$f) <Configure> [list ResizePanedFrame $f]
	}
    }
    #place the frame in its context
    PlaceFrame $f
    set v(frame_creation,$f) 0
}

proc PlaceFrame {f} {
    # JOB: place the frame in its context
    #
    # IN: f, name of the main window to insert
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Fabien Antoine
    # Version: 0.1
    # Date: May 13, 2005
    
    global v

    if {$v(frame_view,$f)} {
	if {[info exists v(frame_type,$f)]} {
	    set type   $v(frame_type,$f) 
	    set opts [join [lsearch -all -inline -regexp -not $type "pane.*|frame.*|vert.*|hor.*|stretch|autoresize.*|notebook.*"]]
	    set index [lsearch $opts "-req*"]
	    if {$index >= 0} {
		set rindex $index
		incr rindex
		set opts [lreplace $opts $index $rindex]
	    }
	} else {
	    set type ""
	    set opts ""
	}
	
	set prev_frame [PrevShowedFrame $f] 
	set next_frame [NextShowedFrame $f] 
	if {$prev_frame != ""} {
	    lappend opts -after $v(frame,$prev_frame)
	} elseif {$next_frame != ""}  {
	    lappend opts -before $v(frame,$next_frame)
	} 

	
	if ([info exists v(frame_container,$f)]) {
	    if [info exists v(frame_type,$v(frame_container,$f))] {
		set container_type $v(frame_type,$v(frame_container,$f))
	    } else {
		set container_type ""
	    }
		if {[lsearch $container_type "pane*"] >=0} {
		    if {$opts != ""} {
			$v(frame,$v(frame_container,$f)) add $v(frame,$f) 
			eval $v(frame,$v(frame_container,$f)) paneconfigure $v(frame,$f) $opts
		    } else {
			$v(frame,$v(frame_container,$f)) add $v(frame,$f)
		    }
		switch [$v(frame,$v(frame_container,$f)) cget -orient] {
		    horizontal { set LEN width ; set index 0}
		    vertical { set LEN height ; set index 1}
		}		
	    } elseif {[lsearch $container_type "notebook*"] >=0} {
		if {$opts != ""} {
		    eval pack $v(frame,$f) $opts 
		} else {
		}
		eval $v(frame,$v(frame_container,$f)) raise pane$f
		
	    } else {
		if {$opts != ""} {
		    eval pack $v(frame,$f)  $opts          
		} else {
		    eval pack $v(frame,$f)
		}
	    } 
	} else {
	    if {$opts != ""} {
		eval pack $v(frame,$f) -fill both -expand true $opts          
	    } else {
		eval pack $v(frame,$f) -fill both -expand true 
	    }
	}
	
	if ([info exists v(frame_container,$f)]) {
	    if {[winfo ismapped $v(frame,$v(frame_container,$f))] == 0} {
		if $v(frame_view,$v(frame_container,$f)) {
		    PlaceFrame $v(frame_container,$f)
		}
	    } else {
		catch {
		    ResizePanedFrame $v(frame_container,$f) $f
		}
	    }
	}
    }
    return
}


proc RememberPanesSize {f} {
    # JOB: stores sash places for $f
    #
    # IN: f, name of the window whom config must be stored
    # OUT: nothing
    # MODIFY : v(frame_panes_pos,$f)
    #
    # Author: Fabien Antoine
    # Version: 0.1
    # Date: July 19, 2005

    global v
    if [info exists v(frame_type,$f)] {
	set new_panes_pos {}
	switch [$v(frame,$f) cget -orient] {
	    horizontal { set LEN width ; set index 0}
	    vertical { set LEN height ; set index 1}
	}
	if {[lsearch $v(frame_type,$f) "autoresize"] >=0} {
	    set j 0
	    set pos 0
	    foreach pane [$v(frame,$f) panes] {
		if  { $j < [expr {[llength [$v(frame,$f) panes]]-1}] } {
		    set new_pos [lindex [$v(frame,$f) sash coord $j] $index]
		    set v(frame_$LEN,$v(frame_name,$pane)) [expr $new_pos-$pos]
		    lappend new_panes_pos $new_pos
		    set pos $new_pos
		}
		incr j
	    }
	    lappend new_panes_pos [winfo $LEN $v(frame,$f)]
	    set v(frame_panes_pos,$f) $new_panes_pos
	}
    }
}

proc ResizePanedFrame {f {newf ""} } {
    global v
    set w $v(frame,$f)
    if [info exists v(frame_type,$f)] {
	
	if {[lsearch $v(frame_type,$f) "autoresize"] >=0} {
	    set len 0
	    switch [$w cget -orient] {
		horizontal { set LEN width ; set index 0}
		vertical { set LEN height ; set index 1}
	    }
	    if ![info exists v(frame_panes_pos,$f)] {
		set v(frame_panes,$f) {}
		set j 0
		set indice 0
		foreach i [$w panes] {
		    set l 0
		    if  { $j < [expr {[llength [$w panes]]-1}] } {
			if [info exists v(frame_$LEN,$v(frame_name,$i))] {
			    set len $v(frame_$LEN,$v(frame_name,$i))
			} else {
			    set len [lindex [$w sash coord $j] $index]
			}
		    } else {
			if [info exists v(frame_$LEN,$v(frame_name,$i))] {
			    set l $v(frame_$LEN,$v(frame_name,$i))
			} elseif { [$w panecget $i -$LEN] ne "" } {
			    set l [$w panecget $i -$LEN]
			} else {
			    set l [winfo req$LEN $i]
			}
			incr len $l
			incr indice
		    }
		    lappend v(frame_panes_pos,$f) $len
		    incr j
		}
	    } else {
	    }
	    if { [llength $v(frame_panes_pos,$f)] >0} { 
		set len [lindex $v(frame_panes_pos,$f) [expr {[llength $v(frame_panes_pos,$f)]-1}]]
	    } else {
		set len [winfo $LEN $w]
	    }
	    set delta [expr {[winfo $LEN $w]-$len}]
	    set delta2 0
	    
	    set spad [$w cget -sashpad]
	    set swidth [$w cget -sashwidth]
	    set tlen 0
	    set len 0
	    set j 0
	    set norm 0
	    set panes [$w panes]
	    set npanes [llength $panes]
	    if {$newf != ""} {
		if {[info exists v(frame_$LEN,$newf)] && ([lsearch $v(frame_content,$f) $newf] > 0)} {
		    incr delta -$v(frame_$LEN,$newf)
		} else {
#		    set delta2 [winfo $LEN $v(frame,$newf)]
		}
	    }
	    #number of panes to be resized
	    set rpanes 0
	    if {($delta != 0) && [info exists v(frame_content,$f)]} {
		foreach child $v(frame_content,$f) {
		    if {$v(frame_view,$child)} {
			if [info exists v(frame_type,$child)] {
			    if {[lsearch $v(frame_type,$child) "stretch"] >= 0} {
				incr rpanes
			    }
			}
		    }
		}
		
		if {$rpanes == 0} {
		    set rpanes 1
		}
		set i 0
		set j 0
		set k 0
		set len [winfo $LEN $w]
		set sashplace 0
		set new_panes_pos {}
		foreach child $v(frame_content,$f) {
		    set l 0
		    if $v(frame_view,$child) {
			set i [lsearch $panes $v(frame,$child)]
			set pane [lindex [$w panes] $i]
			if {$child != $newf} {
			    set l [lindex $v(frame_panes_pos,$f) [expr {$i-$k}]]
			} else {
			    incr l $delta2
			}
			if [info exists v(frame_type,$child)] {
			    if {[lsearch $v(frame_type,$child) "stretch"] >= 0} {
				incr j
			    } 
			    set l [expr {$k*$delta2+$l+int($delta*$j*1.0/$rpanes+.5)}]
			}
			set tlen $l
			if { $i < [llength [$w panes]]-1 } {
			    $w sash place $i $tlen $tlen
			}
			lappend new_panes_pos $tlen
			if {$child == $newf} {
			    set k 1
			}
		    }
		}
		set v(frame_panes_pos,$f) $new_panes_pos
	    }
	}
    }
}


proc ReqFramewidth {f} {
    global v
    set res 0
    if [info exists v(frame_type,$f)] {
	set index [lsearch $v(frame_type,$f) "-reqwidth"]
	if {$index >= 0} {
	    incr index
	    set res [lindex $v(frame_type,$f) $index]
	}
    } 
    if {$res == 0} {
	if {[info exists v(frame_content,$f)]} {
	    foreach child $v(frame_content,$f) {
		if {$v(frame_view,$child)} {
		    incr res [ReqFramewidth $child]
		}
	    }
	} 
    }
    return $res
}

proc ReqFrameheight {f} {
    global v
    set res 0
    if [info exists v(frame_type,$f)] {
	set index [lsearch $v(frame_type,$f) "-reqheight"]
	if {$index >= 0} {
	    incr index
	    set res [lindex $v(frame_type,$f) $index]
	}
    } 
    if {$res == 0} {
	if {[info exists v(frame_content,$f)]} {
	    foreach child $v(frame_content,$f) {
		if {$v(frame_view,$child)} {
		    incr res [ReqFramewidth $child]
		}
	    }
	} 
    }
    return $res
}


proc DestroyFrame {f} {
    
    # JOB: destroy a frame
    #
    # IN: f, name of the main window to destroy
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Fabien Antoine
    # Version: 0.1
    # Date: May 13, 2005
    
    global v
    if [info exists v(frame,$f)] {
	catch {
	    destroy $v(frame,$f)
	}
    }
}

proc HideFrame {f} {
    global v
    set v(frame_view,$f) 0
    if [info exists v(frame,$f)] {
	set parent [winfo parent $v(frame,$f)]
	if ([info exists v(frame_container,$f)]) {
	    set container_type $v(frame_type,$v(frame_container,$f))
	    if {[lsearch $container_type "paned"] >=0} {
		set i [lsearch [$v(frame,$v(frame_container,$f)) panes] $v(frame,$f)]
		$v(frame,$v(frame_container,$f)) forget $v(frame,$f)
	    } else {
		pack forget $v(frame,$f)
	    } 
	} else {
	    pack forget $v(frame,$f)   
	}
	set parent_viewable 0
	foreach brother [winfo children $parent] {
	    if [winfo ismapped $brother] {
		set parent_viewable 1
	    }
	}
	catch {
	    set new_panes_pos {}
	    set old_panes_pos $v(frame_panes_pos,$v(frame_container,$f))
	    for {set j 0} {$j < $i} {incr j} {
		lappend new_panes_pos [lindex $old_panes_pos $j]
	    }
	    for {incr j} {$j < [llength $old_panes_pos]} { incr j } {
		lappend new_panes_pos [expr {[lindex $old_panes_pos $j]-[lindex $old_panes_pos $i]}]
	    }
	    set v(frame_panes_pos,$v(frame_container,$f)) $new_panes_pos
	    ResizePanedFrame $v(frame_container,$f)
	}
    }
}

proc CreateCommandFrame {f args} {
    global v dial
    
    # Commands frame
    set v(tk,play) [button $f.play -command {PlayOrPause}]
    set v(tk,stop) [button $f.pause -command {PlayOrPause} -state disabled]
    set dial(volume) [snack::audio play_gain]
    button $f.previous -command {MoveNextSegmt -1}
    button $f.next -command {MoveNextSegmt +1}
    button $f.backward
    button $f.forward
    bind $f.backward <Button-1> {BeginPlayForward -1}
    bind $f.forward <Button-1> {BeginPlayForward +1}
    bind $f.backward <ButtonRelease-1> {EndPlayForward}
    bind $f.forward <ButtonRelease-1> {EndPlayForward}
    foreach but {previous backward pause play forward next} {
	$f.$but conf -image $v(img,$but) -borderwidth 0
	pack $f.$but -side left -padx 1 -pady 1
    }
    button $f.info -command {CreateInfoFrame}  -image $v(img,info) -borderwidth 0
    pack $f.info -side left -padx 10 
    scale $f.vol -label [Local "Volume"] -font {fixed 10} -orient horiz -length 70 -width 8  -variable dial(volume) -command {snack::audio play_gain} -showvalue 0
    pack $f.vol  -fill x -padx 5 -pady 5 -side right
    
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
    setdef v(frame_view,cmd) 1
    pack $f -fill x
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
	destroy $f
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

proc SwitchFrame {frame {args ""}} {
    # show or hide frame
    
    global v
    
    if {$frame == "menu"} {
	if {$v(frame_view,m) == 1} {
	    set v(frame_view,m) 0
	    . configure -menu .alternate
	} else {
	    set v(frame_view,m) 1
	    . configure -menu .menu
	}
	return
    }
    
    set f $v(frame,$frame)
    if {[winfo class $f] == "Toplevel"} {
	# Always bring to top
	if {[winfo ismapped $f]} {
	    wm withdraw $f
	    set v(frame_view,$frame) 0
	} else {
	    wm deiconify $f
	    set v(frame_view,$frame) 1
	}
    } else {
	# Switch display/hide
	if {[winfo ismapped $f]} {
	    HideFrame $frame
	    #pack forget $f
	    #[winfo parent $f] forget $f
	} else {
	    set v(frame_view,$frame) 1
	    PlaceFrame $frame
	}
    }
}

#######################################################################

proc CreateMessageFrame {f} {
    global v
    
    label $f.label -font mesg -textvariable v(var,msg) \
	-justify left -anchor w -bg $v(color,bg) -padx 10 -relief raised -bd 1
    pack $f.label -fill x -side bottom
    bind $f.label <Button-1> EditCursor
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
    
    # Menu to choose the default browser
    set i [frame $g.fr]
    pack $i -fill both -expand true -side top
    label $i.lab -text [Local "Default browser:"]
    set v(browser,but) [button $i.v(browser,but) -text $v(browser) -default disabled ]
    pack $i.lab $i.v(browser,but) -side left -padx 3m -pady 3m -fill x -expand true
    bind $i.v(browser,but) <Button-1> { 
	set v(browser) [SelectBrowser .col.fr0.fr]
	$v(browser,but) configure -text $v(browser)
    }
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
    # Version: 1.2
    # Date: October 11, 2005

    global v
    
    set f .col
    CreateModal $f "Configure colors"
    
    # create a list that defines the classical buttons in the color interface configuration
    lappend listbutton {"Waveform bg" bg "selected" bg-sel}\
	{"Segments foreground" fg-sync "background" bg-sync}\
	{"Current segment" hi-sync}\
	{"Speaker foreground" fg-turn "background" bg-turn}\
	{"Sections foreground" fg-sect "background" bg-sect}\
	{"Noise foreground" fg-back "background" bg-back}\
    	{"Text foreground" fg-text "background" bg-text}\
	{"Highlighted text bg" hi-text}\
	{"Event foreground" fg-evnt "background" bg-evnt}

    # Make dynamically the color button for the macroclass of named entities defined in configuration file (default.txt)
    foreach {macro1 macro2} $v(listmacroNE) {
	if {$macro2 != ""} {
	    lappend listbutton "\"NE $macro1\" ne-$macro1 \"NE $macro2\" ne-$macro2"
	} else {
	    lappend listbutton "\"NE $macro1\" ne-$macro1"
	}
    }
    # Now, the list of needed button is defined, we only have to build the interface
    set i 0
    foreach set $listbutton {
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
    checkbutton $g.enttag -text [Local "Use color for NE tag"] -variable v(color,NEtag) -command { UpdateColors }
    pack $g.enttag -side left -padx 10
    checkbutton $g.enttext -text [Local "Use color for NE text"] -variable v(color,NEtext) -command { UpdateColors }
    pack $g.enttext -side left -padx 10
    checkbutton $g.entbuton -text [Local "Use color for NE button"] -variable v(color,NEbutton) -command {UpdateNEFrame}
    pack $g.entbuton -side left -padx 10
    pack $g -side top -fill x -expand true

    # check button for colorize or not the speaker segmentation
    set h [frame $f.checkSpkSeg -bd 1 -relief raised]
    checkbutton $h.spkseg -text [Local "Colorize speaker segments"] -variable v(colorizeSpk) -command {ColorizeSpk}
    pack $h.spkseg
    pack $h -side top -fill x -expand true

    # save old values in case of cancel
    foreach part {tag text button} {
	lappend old NE$part $v(color,NE$part)
    }

    # Undo changes after "Cancel"
    if {[OkCancelModal $f $f] != "OK"} {
	foreach {var val} $old {
	    set v(color,$var) $val
	}
	UpdateColors
	UpdateNEFrame
    }
}

proc ChooseColor {varName {parent "."}} {

    # JOB: Change configuration color with a popup to choose the color and redisplay widgets. Called by ColorFrame and ConfigureColors
    #
    # IN: varName, name of the color variable to change
    #     parent, the parent window that call this function for displaying the color selection box over it. 
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: october 2005

    global v
    upvar $varName var
    
    set color [tk_chooseColor -initialcolor $var -parent $parent]

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
    
    # Update the entities colors in the text
    UpdateNEColors
    
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
    $v(frame,msg) config -bg $v(color,bg)
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