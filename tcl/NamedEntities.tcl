# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc CreateNEFrame {frame} {

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

    
    set f $v(frame,$frame)
    
    if {[winfo exists $f]} {DestroyFrame $frame}
    
    # make dynamicaly the different list of entities by macroclass by taking the list of all the entities in the configuartion file if exists else in the default.txt
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

    frame $f -bd 1 -relief raised
    set row 0
    set column 0
 
    # create the interface with buttons
    foreach macro $v(listNE,macroclass) {
	frame $f.$macro
	foreach micro $v(listNE,$macro) {
	    regsub -all {\.} $micro "" name
	    if { $v(checkNEcolor,buton) == 1 } {
		button $f.$macro.$name -text $micro -font $v(font,namEnt) -bg $v(color,netag-$macro) -pady 0 -width [expr [maxlength $v(entities)]-5] -command "CreateAutoNE $micro"
	    } else {
		button $f.$macro.$name -text $micro -font $v(font,namEnt) -pady 0 -width [expr [maxlength $v(entities)]-5] -command "CreateAutoNE $micro"
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

    entry $g.entry -textvariable v(findNE,whichNEstring) 
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

}

proc UpdateNEFrame {} {

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
 
    set oldview $v(frame_view,ne)
    DestroyFrame ne
    set v(frame_view,ne) $oldview
    CreateFrame ne
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
 
    if {![winfo exists $v(frame,ne)]} {
	CreateFrame ne
    } elseif {[winfo ismapped $f]} {
	pack forget $f
    } else {
	pack $f -fill y -side right
    }
}

proc UpdateNEFont {fontNE} {

    # JOB: Change the font of the named entities to fontNE into the editor
    #
    # IN:
    #    fontNE : New named entity font - ex: Tahoma 10 {bold italic}
    #
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Mathieu MANTA
    # Version: 1.0
    # Date: March 1st, 2005

    global v

    set t $v(tk,edit)-bis

    foreach macro "$v(listNE,macroclass) meto" {
	foreach part {"tag" "text"} {
		$t tag conf NE$macro$part -elide 1
	}
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

proc CreateAutoNE {txt {interactif 0}} {

    # JOB: Named entities are implemented like events. This procedure test if the automatic 
    #      mode is required and create the requested NE, else create the NE as usually with proc CreateNE
    #
    # IN: txt, description of the event
    #     type, type of the event, default noise
    #     extent, extent of the event, default instantaneous
    #     interactif, interactif mode i.e. popup window for edit events, default 0
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.1
    # Date: September 16, 2005

    global v
    
    set t $v(tk,edit)-bis

    # Automatic mode
    if { $v(findNE,whichNEstring) != "" && $v(autoNE) != ""} {
	if { $v(autoNE) == "Add" } {
	    set answer [tk_messageBox -message [format [Local "The text \"%s\" will be automaticaly tagged - Continue ?"] $v(findNE,whichNEstring)] -type okcancel -icon question]
	} else {
	    set answer [tk_messageBox -message [format [Local "The text \"%s\" tagged with \"%s\" will be automaticaly untagged - Continue ?"] $v(findNE,whichNEstring) $txt] -type okcancel -icon question]
	}
	if { $answer == "ok" } {
	    #  save the current position then begin the loop from the beginning and return to the saved position
	    $t mark set oldpos "insert"
	    tkTextSetCursor $v(tk,edit) 0.0

	    set nbocc 0
	    while { [set pos [FindNextNE]] != "" } {
		set what [[TagName $pos] getType]
		if { $what == "\#PCDATA" } {
		    switch $v(autoNE) {
		        Add {
			    # Only add if the entities is not already annotated (i.e. if there is no color tag)
		            if { [ColorNE $pos text] == "" } {
		                CreateNE $txt "end" $interactif
		                incr nbocc
		            }
		        }
		        Suppress {
			    # before suppression, test if the entities is annotaded with the same NE type
		            set prevtagname [TagName "sel.first - 2c"]
		            set nexttagname [TagName "sel.last + 1c"]
		            if {  [$prevtagname getType]=="Event" && [$nexttagname getType]=="Event" } {
		                set prevtagdesc [$prevtagname getAttr "desc"]
		                set nexttagdesc [$nexttagname getAttr "desc"]
				if { $prevtagdesc==$txt && $nexttagdesc==$txt} {
		                    SuppressNE $prevtagname
		                    incr nbocc
		                }
		            }
		        }
		    }
		}
	    }
	    tkTextSetCursor $v(tk,edit) oldpos
	    if { $v(autoNE) == "Add" } {
		DisplayMessage "$nbocc \"$v(findNE,whichNEstring)\" automaticaly tagged with \"$txt\""
	    } else {
		DisplayMessage "$nbocc \"$v(findNE,whichNEstring)\" tagged with \"$txt\" automaticaly untagged"
	    }
	    set v(autoNE) ""
	    set v(findNE,whichNEstring) ""
	} 
    # Manual mode	
    } else {
	set sel [$t tag ranges sel] 
	if {$sel == ""} {
	    tk_messageBox -message [Local "No text selected !"] -type ok -icon warning
	} else {
	    CreateNE $txt "end" $interactif
	}
    }
}

proc CreateNE {txt {extent "end"} {interactif 0}} {

    # JOB: create the requested NE
    #
    # IN: txt, description of the NE
    #     interactif, interactif mode i.e. popup window for edit events, default 0
    # OUT: the name of the tag i.e ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: September 16, 2005

    global v
    set t $v(tk,edit)-bis
    set sel [lindex [$t tag ranges sel] 0]
    if {$sel != ""} {
	tkTextSetCursor $v(tk,edit) sel.last
    }
    if {![info exist v(segmt,curr)]} return
    set nb $v(segmt,curr)
    set bp [GetSegmtId $nb]
    
    set data [SplitData]
    # because we include an entities Event, the current DTD is the standard one
    # and the export DTD is still trans-13.dtd, then we switch to trans-14.dtd
    if { [::xml::dtd::compare_version $v(file,dtd) [::xml::dtd::name]] == 0 && [::xml::dtd::compare_version "trans-14.dtd" [::xml::dtd::exportname]] < 0} {
	set rep [tk_messageBox -message [Local "By including entities, this file will not be compatible with older version of Transcriber (<1.4.7).\nDo you want to proceed?"] -type okcancel -icon question]
	if {$rep == "cancel"} {
	    error "Action cancelled by user"
	}
	::xml::dtd::exportname "trans-14.dtd"
    }
    set atts [list "desc" $txt "type" "entities" "extent" $extent]
    set tag [::xml::element "Event" $atts -before $data]
    
    InsertNE $tag "hilight"
    $t tag add $data "insert-1c"
    # Update text on segmentation
    SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
    if {$txt == "" || $interactif} {
	set tag [EditNE $tag "Insert" $sel]
    }
    # As we want to create around a selection, do the symetric
    if {![catch {
	set txt    [$tag getAttr "desc"]
    }] && $sel != ""} {
	catch {unset v(tk,dontmove)}
	tkTextSetCursor $v(tk,edit) $sel
	CreateNE $txt "begin"
	tkTextSetCursor $v(tk,edit) $tag.last 
    }
    DoModif "EVENT"
    return $tag
}



proc InsertNE {elem {other_tags ""}} {

    # JOB: insert the requested NE in the text widget
    #
    # IN: elem, name of the XML element
    #     other_tags, optionnaly argument for some other tags
    #     
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.2
    # Date: September 16, 2005

    global v
    set t $v(tk,edit)-bis
    set desc [$elem getAttr "desc"] 
    set txt [StringOfEvent $elem]
    set macro ""
    # Only for named entities, colors the tag and the event of the event if variable (checkNE,tag or text) is set to 1
    # Look at the class of the named entities and configure the color
    foreach macroclass $v(listNE,macroclass) {
	if {[regexp "^($macroclass)" $desc match macro]} {
	    break
	}
    }	
    if {$macro != ""} {
	foreach part {"tag" "text"} {
	    if { $v(checkNEcolor,$part) == 1 } {
		if { ![regexp {/} $desc] } {
		    $t tag conf NE$macro$part -foreground  $v(color,netag-$macro)
		} else {
		    set macro "meto"
		    $t tag conf NE$macro$part -foreground  $v(color,netag-meto)
		}
	    } else {
		if { ![regexp {/} $desc] } {
		    $t tag conf NE$macro$part -foreground  black
		} else {
		    set macro "meto"
		    $t tag conf NE$macro$part -foreground  black
		}
	    }
	    if { $part == "tag" } {
		$t tag raise NE$macro$part
	    }
	}
    }
    $t insert "insert" $txt [concat "cursor" "sync" NE${macro}tag $elem $other_tags]
    set symtag [SearchSymEvent $elem]
    if { $symtag != "" } {
	set ext [$elem getAttr "extent"]
	if { $ext == "begin" } {
	    $t tag add NE${macro}text $elem.last $symtag.first
	} else {
	    $t tag add NE${macro}text $symtag.last $elem.first
	}
    }
    # inhibit next "mark set insert"
    $t tag bind "$elem" <Button-1> [subst {EditNE $elem; break}]
}

proc EditNE {tag {mode "Edit"} {sel ""}} {

    # JOB: edit the requested NE with a popup window
    #
    # IN: tag, name of the NE XML element
    #     mode, must be Edit or Insert, default Edit
    #     sel, variable corresponding to selection in the text, default no selection
    # OUT: the name of the tag i.e ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

    global v
    
    set t $v(tk,edit)-bis
    tkTextSetCursor $v(tk,edit) "$tag.last"
    # Inhibit next cursor move due to multiple bindings
    set v(tk,dontmove) 1
    
    set w [CreateModal .ne "$mode Named Entity"]
    
    set v(desc,chosen) [$tag getAttr "desc"]
    set v(extn,chosen) [$tag getAttr "extent"]

    set f [frame $w.desc -relief raised -bd 1]
    pack $f -side top -expand true -fill both
    set e [EntryFrame $f.ent "Description" [Local v(desc,chosen)]]
    $e conf -width 10

    catch {
	destroy $f.ent.men
    }
    SetMenuNE $f.ent    
    
    array set buttons {
	"Insert" {"OK" "Cancel"}
	"Edit" {"OK" "Destroy" "Cancel"}
    }
    switch [OkCancelModal $w $e $buttons($mode)] {
	"OK" {
	    if { $mode == "Edit" } {
		# look for an eventual symetric event to configure the color of the text
		set symtag [SearchSymEvent $tag]
		if { $symtag != "" } {
		    catch { [unset v(tk,dontmove)] }
		    tkTextSetCursor $v(tk,edit) $symtag.first 
		    if { $v(extn,chosen) == "begin" } {
			regexp {(^NE.*)tag} [ColorNE "$tag.first"] match color
			$t tag remove ${color}text $tag.last $symtag.first
			CreateNE $v(desc,chosen) "end"
		    } else {
			regexp {(^NE.*)tag} [ColorNE "$tag.first"] match color
			$t tag remove ${color}text $symtag.last $tag.first
			CreateNE $v(desc,chosen) "begin"
		    }
		    tkTextSetCursor $v(tk,edit) $tag.first
		    set v(tk,dontmove) 1
		}
	    }
	    SuppressNE $tag
	    set tag [CreateNE $v(desc,chosen) $v(extn,chosen)]
	}
	"Destroy" {
	    SuppressNE $tag
	    set tag ""
	}
	"Cancel" {
	    if {$mode != "Edit"} {
		SuppressNE $tag
		set tag ""
	    }
	}
    }
    catch {unset v(desc,chosen) v(extn,chosen)}
    return $tag
}

proc SuppressNE {tag {sym 0}} {

    # JOB: suppress the requested NE and it's symetric event if exists
    #
    # IN: tag, name of the XML NE
    #     sym, set to 1 when the deletion applies to the symetric event (to avoid an ifinite loop by searching again a symetric), default 0
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: September 16, 2005 

    global v
    
    set t $v(tk,edit)-bis
    #if type is event and tag is not the sym event (sym set to 0) search symetric event and suppress it
    if {[$tag getType] == "Event" && $sym == 0 } {
	if { ![info exists v(extn,chosen)] } {
	    set v(extn,chosen) [$tag getAttr "extent"]
	}
	set symtag [SearchSymEvent $tag]
	  if { $symtag != "" } {
	      set color ""
	      if { $v(extn,chosen) == "begin" } {
		  regexp {(^NE.*)tag} [ColorNE "$tag.first"] match color
		  $t tag remove ${color}text "$tag.last" "$symtag.first"
	      } else {
		  regexp {(^NE.*)tag} [ColorNE "$tag.first"] match color
		  $t tag remove ${color}text $symtag.last $tag.first 
	      }
	      SuppressNE $symtag 1
	  }
    }
    # Suppress tag
    set bp [SyncBefore $tag]
    JoinData $tag
    # Update text on segmentation
    SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
    DoModif "EVENT"
}

proc SetMenuNE {e} {
   global v

   menubutton $e.men -indicatoron 1 -menu $e.men.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -width 20
   menu $e.men.menu -tearoff 0
   foreach subl $v(entities) {
      foreach {i name} $subl {}
      if {$i == ""} {
	 $e.men.menu add separator
	 continue
      }
      if {$name == ""} {
	 set name $i
      }
      $e.men.menu add radiobutton -label [Local $name] -variable v(desc,chosen) -value [Local $i]
   }
   pack $e.men -side right
   UpdateMenuNE $e
   foreach set [trace vinfo v(desc,chosen)] {
      eval trace vdelete v(desc,chosen) $set
   }
   trace variable v(desc,chosen) w [list UpdateMenuNE $e]
}

# trace callback on v(desc,chosen) used during EditNE
proc UpdateMenuNE {e args} {
   global v

   array set arr [join $v(entities)]
   if {[catch {
      set name $arr($v(desc,chosen))
   }]} {
      set name "other"
   } elseif {$name == ""} {
      set name $v(desc,chosen)
   }
   catch {
      $e.men configure -text [Local $name]
   }
}

# Return string for display of Event or Comment
proc StringOfNE {elem} {

    # JOB: gives the text in the tag NE i.e. [text], for example for tag [lang=en] => text is "lang=en" 
    #
    # IN: elem, the name of the NE
    # OUT: the string in the tag
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: 2005-09-16

   global v

   set desc [$elem getAttr "desc"]
   set extn [$elem getAttr "extent"]
   set type [$elem getAttr "type"]

   return [format $v(event,$extn) [format $v(event,$type) $desc]]
}


proc FindNextNE {} {
    global v

    # JOB: find a specific string in the text and return its position (only for NE)
    #
    # IN: nothing
    # OUT: the position of the string
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: Novembre 29, 2004


    if ![info exists v(tk,edit)] return
    set t $v(tk,edit)
    set start "insert"
    set stop "end"
    set pos [eval ${t}-bis search -forward -exact -count cnt -- [list $v(findNE,whichNEstring)] $start $stop]
    ${t}-bis tag remove sel 0.0 end
    if {$pos != ""} {
	$t mark set insert "$pos + $cnt chars"
	${t}-bis tag add sel $pos insert
    } else {
	DisplayMessage "$v(findNE,whichNEstring) not found."
    }
    return $pos
}

proc ColorNE {pos {part "tag"}} {

    # JOB: find the color tag at the position "pos" in the text
    #
    # IN: pos, position in the text
    # OUT: the name of the color tag i.e. NEmacroclass
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004 

    global v 
    
    set t $v(tk,edit)-bis
    set alltag [split [$t tag names $pos]]
    set colortag ""
    foreach tag $alltag {
	foreach macro $v(listNE,macroclass) {
	    regexp "^NE$macro$part" $tag colortag 
	}
    }

    return $colortag
}