# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
# Text edit frame
#
# Tags used in widget :
#  "locked" -> forbid deleting chars with this tag
#  "$id" -> applied to button + chars belonging to a segment.

proc CreateTextFrame {f {top 0}} {
   global v

   if {$top} {
      toplevel $f
   } else {
      frame $f -bd 2 -relief raised
      pack $f -expand true -fill both -side top
      if {[catch {
	 pack $f -before .cmd
      }]} {catch {
	 pack $f -before .snd
      }}
   }
   set v(tk,edit) [text $f.txt -wrap word  -width 80 -height 8 \
	       -fg $v(color,fg-text) -bg $v(color,bg-text) \
		-font text -yscrollcommand [list $f.ysc set]]
   scrollbar $f.ysc -orient vertical -command [list $f.txt yview]
   pack $f.txt -side left -fill both -expand true
   pack $f.ysc -side right -fill y

   # Filter actions to text widget
   rename $v(tk,edit) $v(tk,edit)-bis
   if {[concat \xe0] == "\xe0"}  {
     proc $v(tk,edit) {args} "eval TextFilter $v(tk,edit)-bis \$args"
   } else {
     # turn around Tcl8.3.2 bug (SourceForge bug ID 227512)
     proc $v(tk,edit) {args} "set args \[linsert \$args 0 TextFilter $v(tk,edit)-bis]; eval \$args"
   }

   # Bindings for widget: tabs and insert are propagated
   bind $v(tk,edit) <Enter> {focus %W}
   bind Text <Key> { tkTextInsert %W %A; break }
   # Suppress local control bindings to allow global menu accelerators
   foreach k {
      Tab Insert Return Pause Shift-BackSpace Shift-Tab ISO_Left_Tab
      Alt-Up Alt-Down Alt-Left Alt-Right Alt-Tab Control-Tab
   } {
      catch {bind Text <$k> { continue }}
   }
   foreach k {q w e r t y u i o p a s d f g h j k l z b n m} {
      bind Text <Control-$k> { continue }
   }
   # ...except for ^X/^C/^V which are best handled in current text widget
   bind Text <Control-x> { tk_textCut %W; break }
   bind Text <Control-c> { tk_textCopy %W; break }
   bind Text <Control-v> { tk_textPaste %W; break }

   # Insert automatically spaces before "," or "." etc. but not inside "..."
   foreach c {"," ";" "." ":"} {
      bind $v(tk,edit) $c { SpaceMagic; tkTextInsert %W %A; break }
   }
   bind $v(tk,edit) ".." { tkTextInsert %W %A; break }

   # Special chars can be generated with bindings
   RegisterBindings $v(bindings)

   bind $v(tk,edit) <Up>   {TextNextLine -1; break }
   bind $v(tk,edit) <Down> {TextNextLine +1; break }
   #bind $v(tk,edit) <Up>   { TextNextSync -1; break }
   #bind $v(tk,edit) <Down> { TextNextSync +1; break }
   bind $v(tk,edit) <Control-Up> {  TextNextTurn -1; break }
   bind $v(tk,edit) <Control-Down> { TextNextTurn +1; break }
   bind $v(tk,edit) <Prior> { TextNextSection -1; break }
   bind $v(tk,edit) <Next> { TextNextSection +1; break }
   #bind $v(tk,edit) <Key-less> { KbdPlayForward -1; break }
   #bind $v(tk,edit) <Key-greater> { KbdPlayForward +1; break }
   bind $v(tk,edit) <Shift-Return> { tkTextInsert %W "\n\t"; break }
}

# called from: InitEditor; CloseTrans
proc EmptyTextFrame {} {
   global v

   if [info exists v(tk,edit)] {
      set t $v(tk,edit)-bis
      # Remove marks and tags
      eval $t mark unset [$t mark names]
      eval $t tag delete [$t tag names]
      # Direct text widget, no filter
      $t delete 1.0 end
   }   
}

# called from: menu Help/Debug/Restart; CloseAndDestroyTrans (not in use)
proc DestroyTextFrame {} {
   global v

   if [info exists v(tk,edit)] {
      set f [winfo parent $v(tk,edit)]
      destroy $f
      unset v(tk,edit)
   }
}

################################################################

# called from: DisplayTrans
proc InitEditor {} {
   global v

   if ![info exists v(tk,edit)] {
      CreateTextFrame .edit
   } else {
      EmptyTextFrame
      # For optimization : destroy and re-create is much quicker...
   }
   set t $v(tk,edit)-bis
   $t tag conf "sel" -underline 0
   $t tag conf "section" -justify center
   $t tag conf "turn" -justify left
   $t tag conf "sync" -tabs "1c left" -lmargin2 1c -spacing3 5
   $t tag conf "event" -background $v(color,bg-evnt) -foreground $v(color,fg-evnt) -font event
   $t tag bind "cursor" <Enter> [list $t config -cursor top_left_arrow]
   $t tag bind "cursor" <Leave> [list $t config -cursor xterm]
   $t tag conf "hilight" -background $v(color,hi-text)
   $t tag raise "sel"
   set pos [$t index insert]
   $t insert "insert" "\n\n\n\n\n" locked
   $t mark set insert $pos
}

proc CreateSectionButton {section} {
   global v

   set button $v(tk,edit).[namespace tail $section]
   set name [::section::long_name $section]
   button $button -text $name -width [max 20 [string length $name]] \
       -command "::section::edit $section" \
       -cursor top_left_arrow \
       -activeforeground $v(color,fg-sect) -fg $v(color,fg-sect) \
       -activebackground $v(color,bg-sect) -bg $v(color,bg-sect)
   return $button
}

proc InsertSectionButton {sec} {
   global v
   set t $v(tk,edit)-bis

   # Button for new section
   if {[$t compare "insert" > "1.0"]} {
      $t insert insert "\n"
   }
   set beg [$t index "insert"]
   $t window create "insert" -align center -window [CreateSectionButton $sec]
   $t tag add "locked" "$beg-1c" "insert"
   $t tag add "section" $beg "insert"
   $t tag add "$sec" "$beg-1c" "insert"
}

###### Added by Zhibiao
proc CreateEpisodeButton {episode} {
   global v

   set button $v(tk,edit).[namespace tail $episode]
   set name "Edit File"
   button $button -text $name -width [max 20 [string length $name]] \
       -command "EditEpisode" \
       -cursor top_left_arrow \
       -activeforeground $v(color,fg-sect) -fg $v(color,fg-sect) \
       -activebackground $v(color,bg-sect) -bg $v(color,bg-sect)
   return $button
}

proc InsertEpisodeButton {episode} {
   global v
   set t $v(tk,edit)-bis

   # Button for new section
   if {[$t compare "insert" > "1.0"]} {
      $t insert insert "\n"
   }
   set beg [$t index "insert"]

   $t window create "insert" -align center -window [CreateEpisodeButton $episode]

   $t tag add "locked" "$beg-1c" "insert"
   $t tag add "episode" $beg "insert"
   $t tag add "$episode" "$beg-1c" "insert"
}
###### added end

proc CreateTurnButton {turn} {
   global v

   set button $v(tk,edit).[namespace tail $turn]
   set name [::turn::get_name $turn]
   button $button -text $name -anchor w -padx 1m -pady 0 \
       -command "::turn::edit $turn" \
       -cursor top_left_arrow \
       -activeforeground $v(color,fg-turn) -fg $v(color,fg-turn) \
       -activebackground $v(color,bg-turn) -bg $v(color,bg-turn)
   return $button
}

proc InsertTurnButton {tur} {
   global v
   set t $v(tk,edit)-bis

   # Button for new speaker
   $t insert "insert" "\n"
   set beg [$t index "insert"]
   $t window create "insert" -padx 3 -pady 2 -window [CreateTurnButton $tur]
   $t tag add "locked" "$beg-1c" "insert"
   $t tag add "turn" $beg "insert"
   $t tag add "$tur" "$beg-1c" "insert"
}

proc InsertSyncButton {bp} {
   global v
   set t $v(tk,edit)-bis

   # Image for breakpoint: sync or background
   $t insert "insert" "\n" "locked $bp"
   set beg [$t index "insert"]
   # Optimization: delayed windows much quicker, but display is unpleasant
   $t image create "insert" -padx 4 -image $v(img,circle)
   $t insert "insert" "\t"
   $t tag add "locked" "$beg-1c" "insert"
   $t tag add "sync" $beg "insert"
   $t tag add "$bp" "$beg-1c" "insert"
   $t tag lower "$bp"
}

proc ChangeSyncButton {bp img} {
   global v
   set t $v(tk,edit)-bis

   set i [lindex [$t dump -image "$bp.first" "$bp.last"] 1]
   $t image configure $i -image $v(img,$img)
}

proc InsertData {data} {
   global v
   set t $v(tk,edit)-bis

   # Previous char tagged as data to allow insertion at beginning of field
   $t tag add "$data" "insert-1c"
   $t insert "insert" [$data getData] "$data sync"
}

proc HomeEditor {} {
   global v
   set t $v(tk,edit)-bis

   catch {unset v(segmt,curr)}
   if {[GetSegmtNb seg0] > 0} {
      SetCurrentSegment 0
   }
   $t see 1.0
}

################################################################

proc SpaceMagic {} {
   global v
   if {$v(space,auto)} {
      if {[string trim [$v(tk,edit) get "insert -1 chars"]] != ""} {
	 $v(tk,edit) insert "insert" " "
      }
   }
}

proc CopyAll {first last} {
   global v

   set t $v(tk,edit)-bis
   set data ""
   set end ""
   foreach {typ val idx} [$t dump -text $first $last] {
      if {$end != "" && [$t compare $idx < $end]} continue
      set tags [$t tag names $idx]
      set elem [lindex $tags [lsearch -glob $tags "*element*"]]
      if {$elem != ""} {
	 switch [$elem getType] {
	    "Event" - "Comment" {
	       append data [$elem dumpTag -empty]
	       set end [$t index $elem.last]
	    }
	    default {
	       #append data $val
	       append data " "
	    }
	 }
      } else {
	 append data $val
      }
   }
   return $data
}

proc PasteAll {w text} {
   global v

   if {$w == $v(tk,edit)} {
      set re "^(\[^<\]*)<(\[^ \]+)( +desc=\"(\[^\"\]*)\")?( +type=\"(\[^\"\]*)\")?( +extent=\"(\[^\"\]*)\")? */>(.*)$"
      while {[regexp $re $text a t1 evt d desc t type e extent text]} {
	 $w insert insert $t1
	 switch -exact -- $evt {
	    "Comment" {
	       CreateEvent $desc "comment"
	    }
	    "Event" {
	       if {$type == ""} {
		  set type "noise"
	       }
	       if {$extent == ""} {
		  set extent "instantaneous"
	       }
	       CreateEvent $desc $type $extent
	    }
	    default {
	    }
	 }
      }
   }
   $w insert insert $text
}

# Override standard cut/Copy/Paste proc: paste always delete selection; 
# convert events and comments to XML tags and back
proc tk_textCut w {
   global v

   if {![catch {set data [$w get sel.first sel.last]}]} {
      if {$w == $v(tk,edit)} {
	 set data [CopyAll sel.first sel.last]
      }
      clipboard clear -displayof $w
      clipboard append -displayof $w $data
      $w delete sel.first sel.last
   }
}

proc tk_textCopy w {
   global v

   if {![catch {set data [$w get sel.first sel.last]}]} {
      if {$w == $v(tk,edit)} {
	 set data [CopyAll sel.first sel.last]
      }
      clipboard clear -displayof $w
      clipboard append -displayof $w $data
   }
}

proc tk_textPaste w {
   global v

   catch {
      catch {
	 $w delete sel.first sel.last
      }
      set text [selection get -displayof $w -selection CLIPBOARD]
      PasteAll $w $text
   }
}

# Filter text widget commands :
#  - doesn't allow deleting locked text area (especially embedded windows)
#  - propagate changes to transcription list
#  - synchronize view of signal to the current segment
proc TextFilter {t option args} {
   global v
   
   switch -glob -- $option {
      "del*"  {
	 # End of delete range (eventually empty)
	 set end [lindex $args 1]
	 # Dump text widget between requested delete indices
	 set lst [eval $t dump -text -image -window $args]
	 # Process backwards to keep correct indices
	 for {set i [expr [llength $lst]-3]} {$i>=0} {incr i -3} {
	    set key  [lindex $lst $i]
	    set idx  [lindex $lst [expr $i+2]]
	    if {$i == 0} {set idx [lindex $args 0]}
	    if {$end != "" && [$t compare $idx >= $end]} continue
	    # Verify that first character of block is not locked
	    set tags [$t tag names $idx]
	    if {[lsearch -exact $tags "locked"] < 0} {
	       set elem [lindex $tags [lsearch -glob $tags "*element*"]]
	       if {$elem != ""} {
		  switch [$elem getType] {
		     "Background" {
			#set idx [$t index $elem.first]
			#SuppressBackground $elem
		     }
		     "Event" - "Comment" {
			set idx [$t index $elem.first]
			SuppressEvent $elem
		     }
		  }
	       } else {
		  set data [GetDataFromPos "$idx+1c"]
		  eval $t delete $idx $end
		  # Update corresponding segment
		  if {$data != ""} {
		     # Display text on transcription and segmentation 
		     ModifyText $data
		  }
	       }
	    }
	    set end $idx
	 }
      }
      "ins*"  {
	 # Position of insertion
	 set idx [lindex $args 0]
	 # We can only insert right to a data tagged char
	 set data [GetDataFromPos "$idx"]
	 if {$data != ""} {
	    # Insert with the tag of current breakpoint
	    lappend args [list $data sync hilight]
	    # turn around Tcl8.3.2 bug (SourceForge bug ID 227512)
	    if {[concat \xe0] == "\xe0"}  {
	      eval $t "insert" $args
	    } else {
	      set args [linsert $args 0 $t insert]; eval $args
	    }
	    if {$v(chatMode)} {
	      CheckTerminator $t
	    }
	    # Display text on transcription and segmentation 
	    ModifyText $data
	 }
      }
      "mark" {
	 # Detect the case of insert point position "$t mark set insert ..."
	 if {[string match "set insert *" $args]} {
	    # Inhibit mark set from button press
	    if {[info exists v(tk,dontmove)]} {
	       unset v(tk,dontmove)
	       return
	    }
	    # Requested insert position
	    set idx [lindex $args 2]
	    # Some "ad-hoc" test to decide if we move left or right in
	    #  case we are out of segment
	    if {([string match "*-*" $idx] 
		 || [$t compare $idx < insert]
		 || [string match "*lineend*" $idx])
		&& ![string match "*linestart*" $idx]} {
	       set dir "-1c"
	    } else {
	       set dir "+1c"
	    }
	    set idx [$t index $idx]
	    while {[$t compare $idx < end]} { 
	       # Search a pos where insertion is allowed
	       set data [GetDataFromPos "$idx"]
	       if {$data != ""} {
		  # Move to new pos and view corresponding segment
		  eval $t $option set insert $idx
		  SynchroToText [SyncBefore $data]
		  return
	       }
	       # If selection active, don't move cursor (blinking effect)
	       if {[$t tag ranges sel] != ""} return
	       # "Bounce" on first char and move left or right
	       if {[$t compare $idx == 1.0]} {
		  set dir "+1c"
	       }
	       set idx [$t index "$idx $dir"]
	    }
	 } else {
	    eval $t $option $args
	 }
      }
      default { 
	 # Blindly propagate other commands to widget
	 eval $t $option $args
      }
   }
}

################################################################

# Search a breakpoint tag at the left of given cursor position
# because we can only insert right to a data tagged char
proc GetDataFromPos {idx} {
   global v
   set t $v(tk,edit)-bis

   set tags [$t tag names "$idx -1 chars"]
   set data [lindex $tags [lsearch -glob $tags "*data*"]]
   return $data
}

# Register modification of $data item inside $bp breakpoint
proc ModifyText {data} {
   global v
   set t $v(tk,edit)-bis

   # Save old text for Undo
   DoModif [list "TEXT" $data [$data getData]]
   # Register new text into data field of transcription
   set txt [$t get "$data.first+1c" "$data.last"]
   $data setData $txt
   # Display whole segment text on segmentation
   set bp [SyncBefore $data]
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
}

################################################################

proc ViewAroundText {} {
   global v

   if ![info exists v(segmt,curr)] return
   set t $v(tk,edit)-bis
   set nb $v(segmt,curr)
   set bp1 [GetSegmtId [expr $nb-1]]
   if [catch {$t see "$bp1.first+1c"}] {$t see 1.0}
   set bp2 [GetSegmtId [expr $nb+1]]
   if [catch {$t see "$bp2.first+1c"}] {$t see end}
   $t see insert
}

################################################################

# Goto end of next/previous synchro/segment/section depending on $rel
# (or current insert pos if move impossible)

proc TextNextLine {{dir +1}} {
  global v

  tkTextSetCursor $v(tk,edit) "insert${dir}l"
  if {$v(preferedPos) == "begin"} {
    tkTextSetCursor $v(tk,edit) "insert linestart"
  } elseif {$v(preferedPos) == "end"} {
    tkTextSetCursor $v(tk,edit) "insert lineend"
  }
}

proc TextNextSync {rel} {
   global v

   set t $v(tk,edit)-bis
   set id [GetSegmtId [expr $v(segmt,curr)+$rel]]
   if {$id != ""} {
      set last [lindex [$t tag nextrange "sync" "$id.first"] 1]
      tkTextSetCursor $v(tk,edit) "$last lineend"
      update idle
   }
}

proc TextFirstSync {} {
   global v

   tkTextSetCursor $v(tk,edit) 1.0
}

proc TextLastSync {} {
   global v

   tkTextSetCursor $v(tk,edit) {end - 1 char}
}

proc TextNextTurn {rel {spk ""}} {
   global v

   set t $v(tk,edit)-bis
   set nb $v(segmt,curr)
   set max [expr [GetSegmtNb seg0]-1]
   while {1} {
      set nb [expr $nb+$rel]
      if {$nb > $max} {
	 set nb 0
      } elseif {$nb < 0} {
	 set nb $max
      }
      if {$nb == $v(segmt,curr)} {
	 return
      }
      set tag [GetSegmtId $nb]
      set tur [$tag getFather]
      set bros [$tur getChilds]
      if {$tag == [lindex $bros 0]} {
	 if {$spk != ""} {
	    set crt [$tur getAttr "speaker"]
	    if {[lsearch -exact $crt $spk] < 0} {
	       continue
	    }
	 }
	 set id [GetSegmtId $nb]
	 set last [lindex [$t tag nextrange "sync" "$id.first"] 1]
	 tkTextSetCursor $v(tk,edit) "$last lineend"
	 return
      }
   }
}

proc TextNextSection {rel {top ""}} {
   global v

   set t $v(tk,edit)-bis
   set nb $v(segmt,curr)
   set max [expr [GetSegmtNb seg0]-1]
   while {1} {
      set nb [expr $nb+$rel]
      if {$nb > $max} {
	 set nb 0
      } elseif {$nb < 0} {
	 set nb $max
      }
      if {$nb == $v(segmt,curr)} {
	 return
      }
      set tag [GetSegmtId $nb]
      set sec [[$tag getFather] getFather]
      set bros [[lindex [$sec getChilds] 0] getChilds]
      if {$tag == [lindex $bros 0]} {
	 if {$top != ""} {
	    set crt [$sec getAttr "topic"]
	    if {[lsearch -exact $crt $top] < 0} {
	       continue
	    }
	 }
	 set id [GetSegmtId $nb]
	 set last [lindex [$t tag nextrange "sync" "$id.first"] 1]
	 tkTextSetCursor $v(tk,edit) "$last lineend"
	 return
      }
   }
}

################################################################

# Test text widget existence for Cut/Copy/Paste
proc TextCmd {{type ""}} {
   global v

   if ![info exists v(tk,edit)] return
   eval tk_text$type $v(tk,edit)
}

proc InsertText {text} {
   global v

   if ![info exists v(tk,edit)] return
   $v(tk,edit) insert insert $text
}

################################################################
# Find & Replace

proc Find {} {
   global v

   if ![info exists v(tk,edit)] return
   set w .find
   if ![winfo exists $w] {
      toplevel $w
      wm title $w [Local "Find and replace"]
      set v(find,what) ""
      set v(find,direction) "-forward"
      set v(find,case) "-nocase"
      set v(find,mode) "-exact"
      set v(find,replace) ""
      
      frame $w.what -relief raised -bd 1
      checkbutton $w.what.case -text [Local "Case sensitive"] -variable v(find,case)  -offvalue "-nocase" -onvalue "" -anchor w -padx 3m
      checkbutton $w.what.dir -text [Local "Backward search"] -variable v(find,direction) -offvalue "-forward" -onvalue "-backward" -anchor w -padx 3m
      checkbutton $w.what.rgxp -text [Local "Use regular expression"] -variable v(find,mode) -offvalue "-exact" -onvalue "-regexp" -anchor w -padx 3m
      pack $w.what.rgxp $w.what.dir $w.what.case -expand true -fill x -side bottom
      EntryFrame $w.what.val "Find" v(find,what)
      $w.what.val.lab conf -width 10 -anchor w

      frame $w.repl -relief raised -bd 1
      EntryFrame $w.repl.val "Replace" v(find,replace)
      $w.repl.val.lab conf -width 10 -anchor w

      frame $w.but -relief raised -bd 1
      button $w.but.next -text [Local "Next"] -command [list FindNext] -default active
      button $w.but.repl -text [Local "Replace"] -command [list Replace]
      button $w.but.repa -text [Local "Replace all"] -command [list ReplaceAll]
      button $w.but.close -text [Local "Close"] -command [list wm withdraw $w]
      pack $w.but.next $w.but.repl $w.but.repa $w.but.close -side left \
	  -expand 1 -padx 2m -pady 1m

      pack $w.what $w.repl $w.but -side top -fill both -expand true
      focus $w.what.val.ent
      bind $w <Return> "tkButtonInvoke $w.but.next"
   } else {
      FrontWindow $w
   }
}

proc FindNext {{loop 1}} {
   global v

   if ![info exists v(tk,edit)] return
   set t $v(tk,edit)
   if {$v(find,direction) == "-backward" && [${t}-bis tag ranges sel] != ""} {
      set start "sel.first"
   } else {
      set start "insert"
   }
   if {$loop} {
      set stop ""
   } elseif {$v(find,direction) == "-backward"} {
      set stop "1.0"
   } else {
      set stop "end"
   } 
   set pos [eval ${t}-bis search $v(find,direction) $v(find,mode) \
		$v(find,case) -count cnt -- [list $v(find,what)] $start $stop]
   ${t}-bis tag remove sel 0.0 end
   if {$pos != ""} {
      $t mark set insert "$pos + $cnt chars"
      ${t}-bis tag add sel $pos insert
   } else {
      DisplayMessage "$v(find,what) not found."
   }
   return $pos
}

proc Replace {{loop 1}} {
   global v

   if ![info exists v(tk,edit)] return
   set t $v(tk,edit)
   # If no selection, do find and replace
   if {[${t}-bis tag ranges sel] == ""} {
      FindNext $loop
   }
   # If still no selection, abort replace.
   if {[${t}-bis tag ranges sel] == ""} {
      return
   }
   # Do the work (skipping element tags)
   if {[lsearch -glob [$t tag names sel.first] "*element*"] < 0} {
      $t mark set insert "sel.first"
      $t delete "insert" "sel.last"
      $t insert insert $v(find,replace)
      set nb 1
   } else {
      $t mark set insert "sel.last"
      set nb 0
   }
   # Search again
   FindNext $loop
   DisplayMessage "Replaced $nb occurence"
   return $nb
}

# Replace all occurences without wrap-around at document boundaries
# (avoiding infinite loops)
proc ReplaceAll {} {
   global v

   if ![info exists v(tk,edit)] return
   set t $v(tk,edit)
   set nb 0
   while {[set done [Replace 0]] != ""} {
      incr nb $done
      if {[expr $nb % 10] == 0} {
	 ${t}-bis see insert
	 update idle
      }
   }
   $t see insert
   DisplayMessage "Replaced $nb occurence(s)."
}

################################################################

proc CheckTerminator {t} {
    global v

    set a [$t index insert]
    set oldcursor $a
    regsub {.[0-9]+$} $a "" line 
    
    set lastchar [$t get $line.0 $line.end]
    
    if {[regexp {^\[.*$} $lastchar] == 1} {
	return
    }
    tkTextSetCursor $t "$line.end"
    set a [$t index insert]
    regsub {^[0-9]+.} $a "" lineend 
    set lastone [expr  $lineend- 1]
    set lastchar [$t get $line.$lastone $line.end]

    set found 0
    if {[info exists v(terminator,$lastchar)] != 0  && $v(terminator,$lastchar) == 1} {
	set found 1
    } else {
	set lastone [expr  $lineend- 2]
	set lastchar [$t get $line.$lastone $line.end]
	if {[info exists v(terminator,$lastchar)] != 0  && $v(terminator,$lastchar) == 1} {
	    set found 1
	} else {
	    set lastone [expr  $lineend- 3]
	    set lastchar [$t get $line.$lastone $line.end]
	    if {[info exists v(terminator,$lastchar)] != 0  && $v(terminator,$lastchar) == 1} {
		set found 1
	    } else {
		set lastone [expr  $lineend- 4]
		set lastchar [$t get $line.$lastone $line.end]
		if {[info exists v(terminator,$lastchar)] != 0  && $v(terminator,$lastchar) == 1} {
		    set found 1
		}

	    }
	}
    }
    tkTextSetCursor $t $oldcursor
    if {$found != 1} {
	tk_dialog .my_errormsg "Terminator not valid" \
        "The terminator is not valid for CHILDES format" ""  0 "Ok"
	
    }

}
