# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

# Manage overlapping speech

proc CreateWho {bp} {
   global v
   set t $v(tk,edit)-bis

   foreach nb {1 2} {
      if {$nb == "1"} {
	 $v(tk,edit)-bis mark set insert "$bp.last"
	 set data [GetDataFromPos "insert"]
	 $t tag remove $data "insert-1c"
	 set tag [::xml::element "Who" [list "nb" $nb] -after $bp]
      } else {
	 set last [lindex [$t tag nextrange "sync" "$bp.first"] 1]
	 $v(tk,edit) mark set insert "$last"
	 set data [SplitData]
	 set tag [::xml::element "Who" [list "nb" $nb] -before $data]
      }
      InsertWho $tag
      $t tag add $data "insert-1c"
   }
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
}

proc InsertWho {elem {other_tags ""}} {
   global v
   set t $v(tk,edit)-bis

   set nb [$elem getAttr "nb"]
   if {$nb > 1} {
      $t insert "insert" "\n\t" [concat "sync" "locked" $elem $other_tags]
   }
   $t insert "insert" "$nb: " [concat "sync" "locked" $elem $other_tags]
   $t tag conf $elem -font {-weight bold -size 12}
}

proc Overlapping {{nb ""} {segmt "seg0"} {pos ""}} {
   global v
   
   if {$nb == ""} {
      if {![info exist v(segmt,curr)]} {
	 return 0
      }
      set nb $v(segmt,curr)
   }
   set turn [[GetSegmtId $nb] getFather]
   set spk [lindex [::turn::get_atts $turn] 0]
   return [expr [llength $spk] > 1]
}

proc OverlappingTurn {{turn ""}} {
   global v
   
   set spk [lindex [::turn::get_atts $turn] 0]
   return [expr [llength $spk] > 1]
}

proc DoWho {turn} {
   global v

   # Add <Who> / [1] tags and marks
   set nb $v(segmt,curr)
   foreach bp [$turn getChilds "element" "Sync"] {
      CreateWho $bp
   }
   SetCurrentSegment $nb
}

proc NoWho {turn} {
   # Suppress <Who> / [1] tags and marks
   foreach who [$turn getChilds "element" "Who"] {
      JoinData $who
   }
   # Redisplay text segmentation
   foreach bp [$turn getChilds "element" "Sync"] {
      SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
   }
}

################################################################

# Manage background noise and music

proc CreateBackground {} {
   global v
   set t $v(tk,edit)-bis

   if {![info exist v(segmt,curr)]} return
   set nb $v(segmt,curr)
   set beg [GetSegmtField seg0 $nb -begin]
   set end [GetSegmtField seg0 $nb -end]
   set bp [GetSegmtId $nb]

   # Choose initial attributes
   set nb [GetSegmentFromPos bg $v(curs,pos)]
   set back [GetSegmtId $nb bg]
   ReadBackAttrib $back
   set v(bgPos,chosen) "Begin"
   if {$v(curs,pos) != $beg} {
      set v(bgPos,chosen) "Current"
   }

   # Get user choice
   set res [ChooseBackground 1 0]
   if {$res == "Cancel"} return

   # Test position
   set first "$bp.last linestart"
   set last [lindex [$t tag nextrange "sync" "$bp.first"] 1]
   if {$v(bgPos,chosen) == "Begin" || 
       ($v(bgPos,chosen) == "Current" && $v(curs,pos) == $beg)} {
      set pos $beg
      $v(tk,edit) mark set insert "$first"
      set after "$bp"
      set data [GetDataFromPos "insert"]
   } elseif {$v(bgPos,chosen) == "End"} {
      set pos $end
      $v(tk,edit) mark set insert "$last"
      set after [GetDataFromPos "insert"]
      set data ""
   } else {
      set pos $v(curs,pos)
      set after [GetDataFromPos "insert"]
      # Split is delayed after validity check (avoid unknown state)
      set data "SplitData"
   }
   
   # Verify the unicity of Background tag
   set nb [GetSegmentFromPos bg $pos]
   if {$pos == [GetSegmtField bg $nb -begin]} {
      if {$nb == 0} {
	 tk_messageBox -message "Signal begins with empty background" \
	     -type ok -icon error
      } else {
	 tk_messageBox -message "Background is already defined at this time" \
	     -type ok -icon error
      }
      return
   }
   # Verify the order of background icons inside text segment
   set back0 [GetSegmtId $nb bg]
   set back1 [GetSegmtId [expr $nb+1] bg]
   if {($back0 != "" && [$t compare $back0.last > insert])
    || ($back1 != "" && [$t compare $back1.first < insert])} {
      tk_messageBox -message "Backgrounds in wrong order inside segment" \
	  -type ok -icon error
      return
   }

   if {$data == "SplitData"} {
      set data [SplitData]
   } elseif {$data != ""} {
      $t tag remove $data "insert-1c"
   }

   # Create background item with dynamic time
   set back [::xml::element "Background" {} -after $after]
   set ti [Synchro::NewTimeTag $back "time" $pos]
   foreach {txt img} [SetBackAttrib $back] {}

   # Update editor
   InsertImage $back $img
   if {$data != ""} {
      $t tag add $data "insert-1c"
   } else {
      $v(tk,edit) mark set insert "insert-1c"
   }
   # Update background segmentation
   set nb [GetSegmentFromPos bg $pos]
   SplitSegmt bg $nb $ti -keep $txt $back
   # Update text on segmentation
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
   DoModif "BACKGROUND"
   UpdateSegmtView modified
}

proc InsertImage {tag img} {
   global v
   set t $v(tk,edit)-bis

   set beg [$t index "insert"]
   $t image create "insert" -padx 4 -image $v(img,$img)
   $t tag add "locked" $beg "insert"
   $t tag add "cursor" "$beg" "insert"
   $t tag add "sync" $beg "insert"
   $t tag add "$tag" $beg "insert"
   $t tag bind "$tag" <Button-1> [subst {EditBackground $tag; break}]
}

proc EditBackground {back} {
   global v
   set t $v(tk,edit)-bis

   tkTextSetCursor $v(tk,edit) "$back.last"
   # Inhibit next cursor move due to multiple bindings
   set v(tk,dontmove) 1

   # Associated Sync
   set bp [SyncBefore $back]
   set nb [SearchSegmtId seg0 $bp]
   set beg [GetSegmtField seg0 $nb -begin]
   set end [GetSegmtField seg0 $nb -end]

   # Current Background attributes
   set pos [$back getAttr "time"]
   if {$pos == $beg} {
      set v(bgPos,chosen) "Begin"
      $v(tk,edit) mark set insert "$back.last"
   } elseif {$pos == $end} {
      set v(bgPos,chosen) "End"
      $v(tk,edit) mark set insert "$back.first"
   } else {
      set v(bgPos,chosen) "Current"
      $v(tk,edit) mark set insert "$back.last"
      SetCursor $pos
   }

   ReadBackAttrib $back

   # Get user choice
   switch [ChooseBackground 0 1] {
      "OK" {
	 # Update XML attributes
	 foreach {txt img} [SetBackAttrib $back] {}
	 # Update background segmentation
	 SetSegmtField bg [SearchSegmtId bg $back] -text $txt
	 ChangeSyncButton $back $img
	 # Update text on segmentation
	 SetSegmtField seg0 $nb -text [TextFromSync $bp]
	 DoModif "BACKGROUND"
      }
      "Destroy" {
	 SuppressBackground $back
      }
      "Cancel" {}
   }
}

proc SuppressBackground {back} {
   global v
   set t $v(tk,edit)-bis

   # Suppress tag
   set bp [SyncBefore $back]
   JoinData $back
   # Modify background segmentation
   set nb [expr [SearchSegmtId bg $back]-1]
   set pos [GetSegmtField bg $nb -endId]
   JoinSegmt bg $nb -first
   Synchro::TagToForget $back "time" $pos
   # Update text on segmentation
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
   DoModif "BACKGROUND"
}

proc ChooseBackground {state destroy} {
   global v

   set w [CreateModal .bgd "Background attributes"]

#    RadioFrame $w.pos "Position in segment" v(bgPos,chosen) {"Begin" "Current" "End"}
#    FrameState $w.pos $state
#    if {$state} {
#       if {$v(bgPos,chosen) == "Current"} {
#          # Current could be misleading, so switch back to Begin
#          set v(bgPos,chosen) "Begin"
#       } else {
#          FrameState $w.pos.right.rad1 0
#       } 
#    }
   
   set f [frame $w.top -relief raised -bd 1]
   pack $f -side top -fill both
   set i 0
   foreach sound {"music" "speech" "shh" "other"} r {0 1 0 1} c {0 0 1 1} {
      set b [checkbutton $f.rad[incr i] -var v($sound,chosen) -text [Local $sound]]
      #pack $b -side top -anchor w -padx 10m -pady 1m
      grid $b -row $r -column $c -sticky w -padx 3m -pady 3m
   }

   if {$destroy} {
      return [OkCancelModal $w $w {"OK" "Destroy" "Cancel"}]
   } else {
      return [OkCancelModal $w $w {"OK" "Cancel"}]
   }
}

proc ReadBackAttrib {back} {
   global v

   if {[catch {
      set level [$back getAttr "level"]
   }]} {
      set level ""
   }
   if {[catch {
      set types [$back getAttr "type"]
   }]} {
      set types ""
   }
   foreach sound {"music" "speech" "shh" "other"} {
      set v($sound,chosen) 0
   }
   set txt ""
   set img "music"
   if {[llength $types] > 0 && $level != "off"} {
      set img "music"
      set txt $types
      foreach sound $types {
	 set v($sound,chosen) 1
      }
   }
   return [list $txt $img]
}

proc SetBackAttrib {back} {
   global v

   # Update XML attributes
   set types ""
   set level ""
   set txt ""
   set img "music"
   foreach sound {"music" "speech" "shh" "other"} {
      if {$v($sound,chosen)} {
	 set img "music"
	 lappend types $sound
	 set level "high"
      }
   }
   set txt $types
   if {$level == ""} {
      set types "other"
      set level "off"
      set txt ""
   }
   $back setAttr "type" $types
   $back setAttr "level" $level
   return [list $txt $img]
}

################################################################

# Manage speech and non-speech events

proc CreateAutoEvent {txt {type "noise"} {extent "instantaneous"} {interactif 0}} {

    # JOB: if invoke for entities event tst if the automatic mode is required and create the requested event, else create events as usually with proc CreateEvent
    #
    # IN: txt, description of the event
    #     type, type of the event, default noise
    #     extent, extent of the event, default instantaneous
    #     interactif, interactif mode i.e. popup window for edit events, default 0, default 0
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004

    global v
    
    set t $v(tk,edit)-bis
    if { $v(find,what) != "" && $type == "entities" && $v(autoNE) != ""} {
	if { $v(autoNE) == "Add" } {
	    set answer [tk_messageBox -message [format [Local "The text \"%s\" will be automaticaly tagged - Continue ?"] $v(find,what)] -type okcancel -icon question]
	} else {
	    set answer [tk_messageBox -message [format [Local "The text \"%s\" tagged with \"%s\" will be automaticaly untagged - Continue ?"] $v(find,what) $txt] -type okcancel -icon question]
	}
	if { $answer == "ok" } {
	    set sel [$t tag ranges sel] 
	    if { $sel != "" } {
		tkTextSetCursor $v(tk,edit) sel.last
	    }
	    $t mark set oldpos "insert"
	    tkTextSetCursor $v(tk,edit) 0.0
	    set pos [$t index "insert -1c"]
	    set v(find,mode) "-exact"
	    set v(find,case) ""
	    set v(find,direction) "-forward"
	    if { [regexp {^(pers|org|gsp|loc|fac|prod|time|amount|unk).*$} $txt match tmp]} {
		set colortag NE$tmp
	    } 
	    if { [regexp {\/} $txt] } {
		set colortag NEmeto
	    } 
	    set nbocc 0
	    while { [set pos [FindNext 0]] != "" } {
		set what [[TagName $pos] getType]
		if { $what == "\#PCDATA" } {
		    switch $v(autoNE) {
		        Add {
		            if { [ColorTag $pos] == "" } {
		                CreateEvent $txt $type $extent $interactif
		                incr nbocc
		            }
		        }
		        Suppress {
		            set prevtagname [TagName "sel.first - 2c"]
		            set nexttagname [TagName "sel.last + 1c"]
		            if {  [$prevtagname getType]=="Event" && [$nexttagname getType]=="Event" } {
		                set prevtagdesc [$prevtagname getAttr "desc"]
		                set nexttagdesc [$nexttagname getAttr "desc"]
		                set col [ColorTag $prevtagname.first]
		                regexp {(.*)tag} [ColorTag $prevtagname.first] match prevtagcolor
		                if { $prevtagdesc==$txt && $nexttagdesc==$txt && $prevtagcolor=="$colortag"} {
		                    SuppressEvent $prevtagname
		                    incr nbocc
		                }
		            }
		        }
		    }
		}
	    }
	    tkTextSetCursor $v(tk,edit) oldpos
	    if { $v(autoNE) == "Add" } {
		DisplayMessage "$nbocc \"$v(find,what)\" automaticaly tagged with \"$txt\""
	    } else {
		DisplayMessage "$nbocc \"$v(find,what)\" tagged with \"$txt\" automaticaly untagged"
	    }
	    set v(autoNE) ""
	    set v(find,what) ""
	} 
    } else {
	CreateEvent $txt $type $extent $interactif
    }
}

proc CreateEvent {txt {type "noise"} {extent "instantaneous"} {interactif 0}} {

    # JOB: create the requested event
    #
    # IN: txt, description of the event
    #     type, type of the event, default noise
    #     extent, extent of the event, default instantaneous
    #     interactif, interactif mode i.e. popup window for edit events, default 0
    # OUT: the name of the tag i.e ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

    global v
    set t $v(tk,edit)-bis
    
    set sel [lindex [$t tag ranges sel] 0]
    if {$sel != ""} {
	set extent "end"
	tkTextSetCursor $v(tk,edit) sel.last
    }
    
    if {![info exist v(segmt,curr)]} return
    set nb $v(segmt,curr)
    set bp [GetSegmtId $nb]
    
    set data [SplitData]
    if {$type == "comment"} {
	set tag [::xml::element "Comment" [list "desc" $txt] -before $data]
    } else {
	set atts [list "desc" $txt "type" $type "extent" $extent]
	set tag [::xml::element "Event" $atts -before $data]
    }
    InsertEvent $tag "hilight"
    $t tag add $data "insert-1c"
    # Update text on segmentation
    SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
    if {$txt == "" || $interactif} {
	set tag [EditEvent $tag "Insert" $sel]
    }
    # In case we created around a selection, do the symetric
    if {$sel != "" && ![catch {
	set txt    [$tag getAttr "desc"]
	set extent [$tag getAttr "extent"]
	set type   [$tag getAttr "type"]
    }] && $extent == "end"} {
	catch {unset v(tk,dontmove)}
	tkTextSetCursor $v(tk,edit) $sel
	    CreateEvent $txt $type "begin"
	tkTextSetCursor $v(tk,edit) $tag.last 
    }
    DoModif "EVENT"
    return $tag


}

# Insert Event in text editor
proc InsertEvent {elem {other_tags ""}} {

    # JOB: insert the requested event in the text widget
    #
    # IN: txt, description of the event
    #     type, type of the event, default noise
    #     extent, extent of the event, default instantaneous
    #     interactif, interactif mode i.e. popup window for edit events, default 0
    # OUT: the name of the tag i.e ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004

    global v
    set t $v(tk,edit)-bis
    set desc [$elem getAttr "desc"] 
    set type [$elem getType]
    set txt [StringOfEvent $elem]
    set macro ""
    #Only for named entities, colors the tag and the event of the event if variable (checkNE,tag or text) is set to 1
    if { $type == "Event" && [set subtype [$elem getAttr "type"]] == "entities"} {
	# Look at the class of the named entities and configure the color
	if { [regexp {^(pers|org|gsp|loc|fac|prod|time|amount|unk)} $desc match macro] } {
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
		        $t tag conf NEmeto$part -foreground  black
		    }
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
    } else {$t insert "insert" $txt [concat "cursor" "sync" "event" $elem $other_tags]}
    # inhibit next "mark set insert"
    $t tag bind "$elem" <Button-1> [subst {EditEvent $elem; break}]
}

proc SearchSymEvent {elem} {

    # JOB: search a symetric event (begin or end) associated with the selected one (end or begin). If it exists, return its name  
    #
    # IN: elem, the selected element
    # OUT: the name of the symetric element i.e ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004
    
    global v

    set t $v(tk,edit)-bis
    set desc [$elem getAttr "desc"]
    set type [$elem getAttr "type"]
    if {$type == "language"} {
	catch {set desc [Local $::iso639($desc)]}
    }
    set extent [$elem getAttr "extent"]
    set symtag ""
    if { $extent == "end" } {
	# look for an eventual begin event non associated with an end one
	set first [$t search -backward -- "$desc\-\]" $elem.first 0.0]
	if { $first != "" } {
	    #check if the element is already associated with an end event
	    set tagfirst [TagName $first]
	    set check [$t search -- "$desc\]"  $tagfirst.last $elem.first]
	    if { $check == "" } {
		set symtag $tagfirst
	    }
	}
    }  
    if { $extent == "begin" } {
	set last [$t search  -- "${desc}\]" $elem.last end]
	if { $last != "" } {
	    set taglast [TagName $last]
	    set check [$t search -- "${desc}\-\]" $elem.last $taglast.first]
	    if { $check == "" } {
		set symtag $taglast
	    }
	}            
    }

    return $symtag
}

proc EditEvent {tag {mode "Edit"} {sel ""}} {

    # JOB: edit the requested event with a popup window
    #
    # IN: tag, name of the event
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
    
    set w [CreateModal .evt "$mode event"]
    
    if {$v(chatMode)} {
	set lstnam {"Noise" "Comment" "Dependent" "Header" "Scope" "\t" "Pronounce" "Lexical" "Language" "Named Entities"}
	set lstval {"noise" "comment"  "dependent" "header" "scope" "\t" "pronounce" "lexical" "language" "entities"}
    } else {
	set lstnam {"Noise" "Comment" "\t" "Pronounce" "Lexical" "Language" "Named Entities"}
	set lstval {"noise" "comment" "\t" "pronounce" "lexical" "language" "entities"}
    }
    set rads [RadioFrame $w.typ "Type" v(type,chosen) $lstnam $lstval]
    
    set v(desc,chosen) [$tag getAttr "desc"]
    
    set f [frame $w.desc -relief raised -bd 1]
    pack $f -side top -expand true -fill both
    set e [EntryFrame $f.ent "Description" [Local v(desc,chosen)]]
    $e conf -width 10
    
    if {$sel != ""} {
	RadioFrame $w.pos "Extent" v(extn,chosen) {"Apply to selection"} {"end"}
    } else {
	RadioFrame $w.pos "Extent" v(extn,chosen) {
	    "Instantaneous event" "Start of event" "End of event" "\t"
	    "Apply to previous word" "Apply to next word" "Apply to selection"
	} {
	    "instantaneous" "begin" "end" "\t"
	    "previous" "next" ""
	}
    }
    
    trace variable v(type,chosen) w [list TraceEvent $w.pos $f.ent]
    if {[$tag getType] == "Event"} {
	set v(type,chosen) [$tag getAttr "type"]
	set v(extn,chosen) [$tag getAttr "extent"]
    } else {
	set v(type,chosen) "comment"
	set v(extn,chosen) "instantaneous"
    }
    
    array set buttons {
	"Insert" {"OK" "Cancel"}
	"Edit" {"OK" "Destroy" "Cancel"}
    }
    switch [OkCancelModal $w $e $buttons($mode)] {
	"OK" {
	    if { $mode == "Edit" } {
		#For entities event, look for an eventual symetric event to configure the color of the text
		if { $v(type,chosen) == "entities" } {
		    set symtag [SearchSymEvent $tag]
		    if { $symtag != "" } {
		        catch { [unset v(tk,dontmove)] }
		        tkTextSetCursor $v(tk,edit) $symtag.first 
		        if { $v(extn,chosen) == "begin" } {
		            regexp {(^NE.*)tag} [ColorTag "$tag.first"] match color
		            $t tag remove ${color}text $tag.last $symtag.first
		            CreateAutoEvent $v(desc,chosen) $v(type,chosen) end
		        } else {
		            regexp {(^NE.*)tag} [ColorTag "$tag.first"] match color
		            $t tag remove ${color}text $symtag.last $tag.first
		            CreateAutoEvent $v(desc,chosen) $v(type,chosen) begin
		        }
		        tkTextSetCursor $v(tk,edit) $tag.first
		        set v(tk,dontmove) 1
		    }
		}
	    }
	    SuppressEvent $tag
	    set tag [CreateEvent $v(desc,chosen) $v(type,chosen) $v(extn,chosen)]
	}
	"Destroy" {
	    SuppressEvent $tag
	    set tag ""
	}
	"Cancel" {
	    if {$mode != "Edit"} {
		SuppressEvent $tag
		set tag ""
	    }
	}
    }
    catch {unset v(type,chosen) v(desc,chosen) v(extn,chosen)}
    return $tag
}

proc SuppressEvent {tag {sym 0}} {

    # JOB: suppress the requested event and it's symetric event if exists
    #
    # IN: tag, name of the event
    #     sym, set to 1 when the deletion applies to the symetric event (to avoid an ifinite loop by searching again a symetric), default 0
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004 

    global v
    
    if { ![info exists v(extn,chosen)] } {
	set v(extn,chosen) [$tag getAttr "extent"]
    }
    set t $v(tk,edit)-bis
    #if type is event and tag is not the sym event (sym set to 0) search symetric event and suppress it
    if {[$tag getType] == "Event" && $sym == 0 } {
	set symtag [SearchSymEvent $tag]
	  if { $symtag != "" } {
	      set color ""
	      if { $v(extn,chosen) == "begin" } {
		  regexp {(^NE.*)tag} [ColorTag "$tag.first"] match color
		  $t tag remove ${color}text "$tag.last" "$symtag.first"
	      } else {
		  regexp {(^NE.*)tag} [ColorTag "$tag.first"] match color
		  $t tag remove ${color}text $symtag.last $tag.first 
	      }
	      SuppressEvent $symtag 1
	  }
    }
    # Suppress tag
    set bp [SyncBefore $tag]
    JoinData $tag
    # Update text on segmentation
    SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
    DoModif "EVENT"
}

proc TagName {pos} {

    # JOB: find the name of the xml element at the position "pos" in the text
    #
    # IN: pos, position in the text
    # OUT: the name of the tag i.e. ::xml::elementXX
    # MODIFY: nothing
    #
    # Author: Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004 

    global v

    set t $v(tk,edit)-bis
    set alltag [split [$t tag names $pos]]
    foreach vartag $alltag {
	regexp {^(::.*xml.*)$} $vartag tag
    }
    return $tag
}

proc ColorTag {pos} {

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
	regexp {^NE(pers|org|gsp|loc|fac|prod|time|amount|meto|unk).*$} $tag colortag 
    }
    return $colortag
}

# trace callback on v(type,chosen) used during EditEvent
proc TraceEvent {w e args} {
   global v

   catch {
      destroy $e.men
   }
   FrameState $w 1
   catch {$w.right3.rad6 conf -state disabled}
   switch -exact $v(type,chosen) {
      "comment" {
	 set v(extn,chosen) "instantaneous"
	 FrameState $w 0
      }
      "noise" {
	 SetMenuEvent $e noise
      }
      "language" {
	 SetMenuEvent $e language
      }
      "dependent" {
	 SetMenuEvent $e dependent
      }
      "scope" {
	 SetMenuEvent $e scope
      }
      "header" {
	 SetMenuEvent $e header
      }
      "pronounce" {
	 SetMenuEvent $e pronounce
      }
      "lexical" {
	 SetMenuEvent $e lexical
      }
      "entities" {
	  SetMenuEvent $e entities
      }
   }
}

proc SetMenuEvent {e array_name} {
   global v

   menubutton $e.men -indicatoron 1 -menu $e.men.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -width 20
   menu $e.men.menu -tearoff 0
   foreach subl $v($array_name) {
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
   UpdateMenuEvent $e $array_name
   foreach set [trace vinfo v(desc,chosen)] {
      eval trace vdelete v(desc,chosen) $set
   }
   trace variable v(desc,chosen) w [list UpdateMenuEvent $e $array_name]
}

# trace callback on v(desc,chosen) used during EditEvent
proc UpdateMenuEvent {e array_name args} {
   global v

   array set arr [join $v($array_name)]
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
proc StringOfEvent {elem} {

    # JOB: gives the text in the tag event i.e. [text], for example for tag [lang=en] => text is "lang=en" 
    #
    # IN: elem, the name of the event
    # OUT: the string in the tag
    # MODIFY: nothing
    #
    # Author: Claude Barras
    # Version: 1.0
    # Date: 1999

   global v

   set desc [$elem getAttr "desc"]
   if {[$elem getType] == "Event"} {
      set extn [$elem getAttr "extent"]

      # For backward compability only: [noise-] ... [-noise] 
#       if {$extn == "instantaneous" 
#           && [regexp "^(-)?(.*\[^-])(-)?$" $desc all start desc end]} {
#          if {$start != ""} {
#             set extn "end"
#          } elseif {$end != ""} {
#             set extn "begin"
#          }
#          $elem setAttr "desc" $desc
#          $elem setAttr "extent" $extn
#       }

      set type [$elem getAttr "type"]
      if {$type == "language"} {
	 catch {set desc [Local $::iso639($desc)]}
      }
      return [format $v(event,$extn) [format $v(event,$type) $desc]]
   } else {
      set type "comment"
      return [format $v(event,$type) $desc]
   }
}

# User configuration proc for Event/Comment format strings
proc ConfigureEvents {} {
   global v

   # Keep initial values for 'Cancel'
   foreach name [array names v "event,*"] {
      lappend initConf $name $v($name)
   }

   set f .col
   CreateModal $f "Configure events"

   set g [frame $f.fr0]
   pack $g -fill both -expand true -side top

   set h [frame $g.fr1 -relief raised -bd 1]
   pack $h -fill both -expand true -side left
   foreach title {
      "Instantaneous event" "Start of event" "End of event"
      "Apply to previous word" "Apply to next word"
   } var {
      "instantaneous" "begin" "end"
      "previous" "next"
   } {
      set e [EntryFrame $h.$var $title v(event,$var)]
      $e conf -width 10
      pack $e -expand 0 -side right
   }

   set h [frame $g.fr2 -relief raised -bd 1]
   pack $h -fill both -expand true -side left
   if {$v(chatMode)} {
     set lstname {"Comment" "Noise" "Pronounce" "Lexical" "Language" "Named Entities" "Dependent" "Header" "Scope"}
     set lstval {"comment" "noise" "pronounce" "lexical" "language" "entities" "dependent" "header" "scope"}
   } else {
     set lstnam {"Comment" "Noise" "Pronounce" "Lexical" "Language" "Named Entities"}
     set lstval {"comment" "noise" "pronounce" "lexical" "language" "entities"}
   }
   foreach title $lstnam var $lstval {
      set e [EntryFrame $h.$var $title v(event,$var)]
      $e conf -width 10
      pack $e -expand 0 -side right
#       if {$var != "comment"} {
#          button $h.$var.edt -text "Edit list" -command "ConfEventName $var $title"
#          pack forget $e
#          pack $h.$var.edt $e -expand 0 -side right -pady 2m -padx 3m
#       } else {
#          pack $e -expand 0 -side right
#       }
   }

   # Wait for answer and undo changes if 'Cancel'
   set answer [OkCancelModal $f $f]
   if {$answer == "OK"} {
      DisplayTrans
   } else {
      array set v $initConf
   }
}

proc ConfEventName {type title} {

    # JOB: For each element (language, dependent,header,scope and the events), launch the ListEditor procedure to modify the associated list
    #
    # IN: type, the type of the event
    #     title, the name of the list
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.0
    # Date: October 20, 2004

    global v
    
    catch {
	switch $type {
	    "language" {
		set v($type) [ListEditor $v($type) $title {"Code" "Language"}]
		UpdateLangList
	    }
	    "dependent" {
		set v($type) [ListEditor $v($type) $title {"Code" "Dependent"}]
		UpdateDepList
	    }
	    "header" {
		set v($type) [ListEditor $v($type) $title {"Code" "Header"}]
		UpdateHeaderList
	    }
	    "scope" {
		set v($type) [ListEditor $v($type) $title {"Code" "Scope"}]
		UpdateScopeList
	    }
	    default {
		set v($type) [ListEditor $v($type) $title {"Value" "Description"}]
		#If entities list is modified, it is necessary to update the associated interface
		if { $type == "entities" } {
		    UpdateNEFrame .edit.ne
		}
	    }
	}
    }
}

################################################################

# Generic management of extensions to standard DTD

# Return string for element
proc StringOfOther {elem} {
  global v

  set type [$elem getType]
  if {[info commands ::tag::${type}::toString] != {}} {
    return [::tag::${type}::toString $elem]
  } else {
    return [$elem dump]
  }
}

# Insert tag in text editor
proc InsertOther {elem {other_tags ""}} {
   global v
   set t $v(tk,edit)-bis

   set txt [StringOfOther $elem]
   set type [$elem getType]
   $t insert "insert" $txt [concat "cursor" "sync" $type $elem $other_tags]
   if {[info commands ::tag::${type}::insert] != {}} {
     ::tag::${type}::insert $elem
   }
   # inhibit next "mark set insert"
   $t tag bind "$elem" <Button-1> [subst {EditOther $elem; break}]
}

proc SuppressOther {tag} {
   global v

   # do some cleaning associated to tag
   set type [$tag getType]
   if {[info commands ::tag::${type}::suppress] != {}} {
     ::tag::${type}::suppress $tag
   }
   # Really suppress the tag
   set bp [SyncBefore $tag]
   JoinData $tag
   # Update text on segmentation
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
   DoModif "TAG"
}

proc EditOther {tag} {
   global v

   set type [$tag getType]
   if {[info commands ::tag::${type}::edit] != {}} {
     tkTextSetCursor $v(tk,edit) "$tag.last"
     # Inhibit next cursor move due to multiple bindings
     set v(tk,dontmove) 1

     return [::tag::${type}::edit $tag]
   } else {
     return $tag
   }
}

# Insert new tag with default values (may be followed by edition)
proc CreateOther {type values} {
   global v
   set t $v(tk,edit)-bis

   if {![info exist v(segmt,curr)]} return
   set nb $v(segmt,curr)
   set bp [GetSegmtId $nb]

   set data [SplitData]
   set tag [::xml::element $type $values -before $data]
   InsertOther $tag "hilight"
   $t tag add $data "insert-1c"
   # Update text on segmentation
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
   DoModif "TAG"
   return $tag
}

################################################################
# added by Zhibiao
################################################################

# Insert Dependent in text editor
proc InsertDependent {} {
   global v
   set t $v(tk,edit)-bis

   set a [$t index insert]
    regsub {.[0-9]+$} $a "" line 
    
    tkTextSetCursor $t "$line.end"
    set a [$t index insert]
    regsub {^[0-9]+.} $a "" lineend 
    set lastone [expr  $lineend- 1]
    set lastchar [$t get $line.$lastone $line.end]
    tkTextSetCursor $t $line.$lastone
    tkTextInsert $t "$lastchar "
    set lastone [expr $lastone + 2]
    tkTextSetCursor $t $line.$lastone
    $t delete insert
    set lastone [expr $lastone -1]
    tkTextSetCursor $t $line.$lastone
    tkTextInsert $t "\n"
    CreateEvent "%act: " "dependent" "instantaneous" 1
}

# Insert Dependent in text editor
proc InsertHeader {} {
   global v
   set t $v(tk,edit)-bis

   set a [$t index insert]
    regsub {.[0-9]+$} $a "" line 
    
    tkTextSetCursor $t "$line.end"
    set a [$t index insert]
    regsub {^[0-9]+.} $a "" lineend 
    set lastone [expr  $lineend- 1]
    set lastchar [$t get $line.$lastone $line.end]
    tkTextSetCursor $t $line.$lastone
    tkTextInsert $t "$lastchar "
    set lastone [expr $lastone + 2]
    tkTextSetCursor $t $line.$lastone
    $t delete insert
    set lastone [expr $lastone -1]
    tkTextSetCursor $t $line.$lastone
    tkTextInsert $t "\n"
    CreateEvent "@Comment:" "header" "instantaneous" 1

}

# Insert Dependent in text editor
proc InsertScope {} {
   global v
   set t $v(tk,edit)-bis

   CreateEvent "=! " "scope" "instantaneous" 1
}
