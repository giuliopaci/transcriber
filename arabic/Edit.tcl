# Copyright (C) 1998, DGA - part of the Transcriber program
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
   proc $v(tk,edit) {args} "eval TextFilter $v(tk,edit)-bis \$args"

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
   #foreach c {"," ";" "." ":"} {
   #   bind $v(tk,edit) $c { SpaceMagic; tkTextInsert %W %A; break }
   #}
   #bind $v(tk,edit) ".." { tkTextInsert %W %A; break }

   # Special chars can be generated with bindings
   RegisterBindings $v(bindings)

   bind $v(tk,edit) <Up>   {tkTextSetCursor %W "insert-1l linestart"; break }
   bind $v(tk,edit) <Down> {tkTextSetCursor %W "insert+1l"; tkTextSetCursor %W "insert linestart"; break }
   #bind $v(tk,edit) <Up> { TextNextSync -1; break }
   #bind $v(tk,edit) <Down> { TextNextSync +1; break }
   bind $v(tk,edit) <Control-Up> {  TextNextTurn -1; break }
   bind $v(tk,edit) <Control-Down> { TextNextTurn +1; break }
   bind $v(tk,edit) <Prior> { TextNextSection -1; break }
   bind $v(tk,edit) <Next> { TextNextSection +1; break }
   #bind $v(tk,edit) <Key-less> { KbdPlayForward -1; break }
   #bind $v(tk,edit) <Key-greater> { KbdPlayForward +1; break }
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
   $t tag conf "turn" -justify right
   $t tag conf "sync" -justify right -tabs "1c left" -lmargin2 1c -spacing3 5
   $t tag conf "event" -background $v(color,bg-evnt) -foreground $v(color,fg-evnt) -font event
   $t tag bind "cursor" <Enter> [list $t config -cursor top_left_arrow]
   $t tag bind "cursor" <Leave> [list $t config -cursor xterm]
   $t tag conf "hilight" -background $v(color,hi-text)
   $t tag raise "sel"
   $t tag conf "pers" -foreground "blue"
   $t tag conf "loc" -foreground #0007ff3ff
   $t tag conf "fac" -foreground "brown"
   $t tag conf "GSP" -foreground #000ff0fff
   $t tag conf "org" -foreground "purple"
   $t tag conf "time" -foreground "red"
   $t tag conf "amount" -foreground "orange"
   set pos [$t index insert]
   $t insert "insert" "\n\n\n\n\n" locked
   $t mark set insert $pos

   # with right justification, tabs are not well handled in Tk
   $t tag config "arabic" -font "*-20-*-atex-*" -justify right
   $t tag add "arabic" "insert"
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

   # patch arabic
   $t mark set insert "insert lineend"

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

   # patch arabic
   $t mark set insert "insert lineend"

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

   # patch arabic
   $t mark set insert "insert lineend"

   # Image for breakpoint: sync or background
   $t insert "insert" "\n" "locked $bp"
   set beg [$t index "insert"]
   # Optimization: delayed windows much quicker, but display is unpleasant
   $t insert "insert" " "
   $t image create "insert" -padx 4 -image $v(img,circle)
   $t tag add "locked" "$beg-1c" "insert"
   $t tag add "sync" $beg "insert"
   $t tag add "$bp" "$beg-1c" "insert"
   #$t tag add "$bp" "$beg" "insert"
   $t tag lower "$bp"
   $t mark set insert "$beg"
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
   $t tag add "$data" "insert"
   $t mark gravity "insert" left
   $t insert "insert" [ConvertToGlyph [$data getData]] "$data sync arabic"
   $t mark gravity "insert" right

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
   #if {$v(space,auto)} {
   #   if {[string trim [$v(tk,edit) get "insert -1 chars"]] != ""} {
   #	 $v(tk,edit) insert "insert" " "
   #   }
   #}
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
	       set data [$elem dumpTag -empty]$data
	       set end [$t index $elem.last]
	    }
	    default {
	       #append data $val
	       set data " $data"
	    }
	 }
      } else {
	 set data [ConvertFromGlyph $val]$data
      }
   }
   return $data
}

proc PasteAll {w text} {
   global v

   if {$w == $v(tk,edit)} {
      set re "^(\[^<\]*)<((\[^ \]+)( +desc=\"(\[^\"\]*)\")?( +type=\"(\[^\"\]*)\")?( +extent=\"(\[^\"\]*)\")? */>)?(.*)$"
      $w mark gravity "insert" left
      while {[regexp $re $text a t1 hastag evt d desc t type e extent text]} {
	 $w insert insert $t1
	 if {$hastag != ""} {
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
	 } else {
	    $w insert insert "<"
	 }
      }
      $w insert insert $text
      $w mark gravity "insert" right
      return
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
		  DeleteArabChars $t $idx $end
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
	    if {$idx == "insert"} {
	       foreach {a b} [lrange $args 1 end] {
		  InsertArabChars $t $a $b
	       }
	    } else {
	       eval $t "insert" $args
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

   set tags [$t tag names "$idx"]
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
   set txt [ConvertFromGlyph [$t get "$data.first" "$data.last-1c"]]
   $data setData $txt
   # Display whole segment text on segmentation
   set bp [SyncBefore $data]
   SetSegmtField seg0 [SearchSegmtId seg0 $bp] -text [TextFromSync $bp]
}

################################################################

# Goto end of next/previous synchro/segment/section depending on $rel
# (or current insert pos if move impossible)
proc TextNextSync {rel} {
   global v

   set t $v(tk,edit)-bis
   set id [GetSegmtId [expr $v(segmt,curr)+$rel]]
   if {$id != ""} {
      set last [lindex [$t tag nextrange "sync" "$id.first"] 0]
      tkTextSetCursor $v(tk,edit) "$last linestart"
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
	 tkTextSetCursor $v(tk,edit) "$last linestart"
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
	 tkTextSetCursor $v(tk,edit) "$last linestart"
	 return
      }
   }
}
