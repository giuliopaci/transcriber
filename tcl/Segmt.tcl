# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc CreateSegmentWidget {wavfm seg args} {
   global v

   set f [winfo parent $wavfm].$seg
   if ![winfo exists $f] {
      eval {segmt $f -seg v(trans,$seg) -bd 1 -padx 1m -pady 1 -font trans -bg $v(color,bg) -time ::Synchro::time} $args
      setdef v(view,$f) 1
      if {$v(view,$f)} {
	 #pack $f -fill x -padx 10 -after $wavfm
	 pack $f -fill x -padx 10 -before [winfo parent $wavfm].a
      }

      # Segment selection with B1
      bind $f <Button-1>   [list SegmentSelect $wavfm $seg 0 %X %y]
      bind $f <B1-Motion>  [list SegmentSelect $wavfm $seg 1 %X %y]
      bind $f <ButtonRelease-1>  [list EndSegmentSelect $seg %X %y]
      bind $f <Shift-Button-1>   [list SegmentSelect $wavfm $seg 1 %X %y]

      # Segment boundary move with B2 or Control-B1; forced move with Shift-
      foreach F {0 1} S {"" "Shift-"} {
	 bind $f <${S}Button-2>   [list SegmentMove $wavfm $seg 0 %X %y $F]
	 bind $f <${S}B2-Motion>  [list SegmentMove $wavfm $seg 1 %X %y $F]
	 bind $f <${S}ButtonRelease-2>  [list EndSegmentMove $seg]
	 bind $f <${S}Control-Button-1>   [list SegmentMove $wavfm $seg 0 %X %y $F]
	 bind $f <${S}Control-B1-Motion>  [list SegmentMove $wavfm $seg 1 %X %y $F]
	 bind $f <${S}Control-ButtonRelease-1>  [list EndSegmentMove $seg]
      }
      
      # Contextual menu with B3
      bind $f <Button-3>  [list tk_popup $v($wavfm,menu) %X %Y]
      set menu [$v($wavfm,menu) entrycget [Local "Display"] -menu]
      add_menu $menu [subst {
	 {"$seg" check v(view,$f) -command {SwitchSegmtView $wavfm}}
      }]

      lappend v($wavfm,seglist) $f
      lappend v($wavfm,sync) $f
      SynchroWidgets $wavfm

   }
}

proc SwitchSegmtView {wavfm} {
   global v

   foreach f $v($wavfm,seglist) {
      if {$v(view,$f)} {
	 #pack $f -fill x -padx 10 -after $wavfm
	 pack $f -fill x -padx 10 -before [winfo parent $wavfm].a
      } else {
	 pack forget $f
      }
   }
}

proc CreateAllSegmentWidgets {} {
   global v

   foreach wavfm $v(wavfm,list) {
      CreateSegmentWidget $wavfm bg   -fg $v(color,fg-back) -full $v(color,bg-back) -empty $v(color,bg)
      CreateSegmentWidget $wavfm seg2 -fg $v(color,fg-sect) -full $v(color,bg-sect)
      CreateSegmentWidget $wavfm seg1 -fg $v(color,fg-turn) -full $v(color,bg-turn) -tiny {fixed 8}
      CreateSegmentWidget $wavfm seg0 -fg $v(color,fg-sync) -full $v(color,bg-sync) -height 2 -high $v(color,hi-sync)
   }
}

proc DestroySegmentWidget {wavfm seg} {
   global v

   set f [winfo parent $wavfm].$seg
   if [winfo exists $f] {
      destroy $f
      lsuppress v($wavfm,sync) $f
   }
}

proc DestroySegmentWidgets {} {
   global v

   foreach wavfm $v(wavfm,list) {
      foreach f $v($wavfm,sync) {
	 if {[winfo class $f] == "Segmt"} {
	    destroy $f
	    lsuppress v($wavfm,sync) $f
	 }
      }
   }
}
 
################################################################

# Empty segmentations
proc InitSegmt {args} {
   global v

   foreach segmt $args {
      set v(trans,$segmt) {}
      set v(list,$segmt) {}
   }
}

proc AddSegmt {segmt begid endid txt id} {
   global v
   
   set beg [Synchro::GetTime $begid]
   set end [Synchro::GetTime $endid]
   if {$end <= $beg} { error "Size of segment \[$beg $end] must be positive" }
   lappend v(trans,$segmt) [list $begid $endid $txt "" $id]
   lappend v(list,$segmt) $id
}

# Replace old segment field by new value
# After that, the whole list is automatically reparsed by the segment widgets
# (this could be optimized to reparse only the modified segment)
proc SetSegmtField {segmt nb field value} {
   global v

   if {$nb < 0 || $nb>=[llength $v(trans,$segmt)]} return
   set seg [lindex $v(trans,$segmt) $nb]
   set seg [lrange [concat $seg {{} {} {} {} {}}] 0 4]
   set list "-begin -end -text -color" 
   set index [lsearch -exact $list $field]
   set seg [lreplace $seg $index $index $value]
   set v(trans,$segmt) [lreplace $v(trans,$segmt) $nb $nb $seg]
}

proc GetSegmtField {segmt nb field} {
   global v

   if {$nb < 0 || $nb>=[llength $v(trans,$segmt)]} return
   set seg [lindex $v(trans,$segmt) $nb]
   switch -- $field {
      -beginId   { return [lindex $seg 0] }
      -endId     { return [lindex $seg 1] }
      -begin   { return [Synchro::GetTime [lindex $seg 0]] }
      -end     { return [Synchro::GetTime [lindex $seg 1]] }
      -text    { return [lindex $seg 2] }
      -color   { return [lindex $seg 3] }
   }
}

proc GetSegmtNb {segmt} {
   global v

   if ![info exists v(trans,$segmt)] {
      return -1
   }
   return [llength $v(trans,$segmt)]
}

proc SearchSegmtId {segmt tag} {
   global v

   return [lsearch -exact $v(list,$segmt) $tag]
}

proc GetSegmtId {nb {segmt "seg0"}} {
   global v

   return [lindex $v(list,$segmt) $nb]
}

# Called from : JoinTransTags (<-DeleteSegment, ChangeSegType); DeleteSegment
proc JoinSegmt {segmt nb1 {mode ""} {txt ""}} {
   global v

   set nb2 [expr $nb1+1]
   if {$nb1 < 0 || $nb2>=[llength $v(trans,$segmt)]} return
   set seg1 [lindex $v(trans,$segmt) $nb1]
   set seg2 [lindex $v(trans,$segmt) $nb2]
   if {$mode == "-first"} {
      set txt [lindex $seg1 2]
   } elseif {$mode == "-last"} {
      set txt [lindex $seg2 2]
   } elseif {$mode == "-join"} {
      set txt [concat [lindex $seg1 2] [lindex $seg2 2]]
   }
   set seg [list [lindex $seg1 0] [lindex $seg2 1] $txt]
   set v(trans,$segmt) [lreplace $v(trans,$segmt) $nb1 $nb2 $seg]
   set v(list,$segmt) [lreplace $v(list,$segmt) $nb2 $nb2]
}

# Called by: SplitTransTags (<- ChangeSegType), InsertSegment
proc SplitSegmt {segmt nb pos txt1 txt2 id} {
   global v

   if {$nb < 0 || $nb>=[llength $v(trans,$segmt)]} return
   set seg [lindex $v(trans,$segmt) $nb]
   if {$txt1 == "-keep"} {
      set txt1 [lindex $seg 2]
   }
   if {$txt2 == "-keep"} {
      set txt2 [lindex $seg 2]
   }
   set seg1 [list [lindex $seg 0] $pos $txt1]
   set seg2 [list $pos [lindex $seg 1] $txt2]
   set v(trans,$segmt) [lreplace $v(trans,$segmt) $nb $nb $seg1 $seg2]
   set v(list,$segmt) [linsert $v(list,$segmt) [expr $nb+1] $id]
}

proc CountWordSegmt {segmt} {
   set w 0
   set c 0
   for {set i 0} {$i < [GetSegmtNb $segmt]} {incr i} {
      set txt [string trim [GetSegmtField $segmt $i -text]]
      if {$txt != ""} {
	 incr w [expr [regsub -all { +} $txt {} ignore]+1]
	 incr c [string length $txt]
      }
   }
   return $w
}

################################################################

# Events bindings for selection of segments

# If segment exists at time $pos, returns segment nb and set begin/end values
# else returns -1 and begin/end values are set to $pos
proc GetSegmentFromPos {seg pos {beginName ""} {endName ""} {overName ""}} {
   global v
   if {$beginName != ""} {
      upvar $beginName begin
   }
   if {$endName != ""} {
      upvar $endName   end
   }
   if {$overName != ""} {
      upvar $overName ov
   }

   # Dichotomic search for efficiency...
   set min 0
   set max [expr [GetSegmtNb $seg]-1]
   while {$max >= $min} {
      set i [expr ($max+$min)/2]
      set begin [GetSegmtField $seg $i -begin]
      set end   [GetSegmtField $seg $i -end]
      if {$pos >= $end} {
	 set min [expr $i+1]
	 continue
      }
      if {$pos < $begin} {
	 set max [expr $i-1]
	 continue
      }
      # Verify overlap
      set ov 0
#       set ov [Overlapping $i $seg $pos]
#       if {$ov >= 0} {    
# 	 if {$ov != $i} {
# 	    set begin [GetSegmtField $seg $ov -begin]
# 	    set end   [GetSegmtField $seg $ov -end]
# 	 }
# 	 set i $ov
# 	 set ov 1
#       } else {
# 	 set ov 0
#       }
      return $i
   }
   set begin $pos
   set end $pos
   set ov 0
   return -1
}

proc GetPosAfterScroll {wavfm X} {
   global v

   set pos [GetClickPos $wavfm $X scroll]
   if {$scroll != 0} {
      ScrollTime $wavfm scroll $scroll units
      # Tempo for smooth scrolling
      after 50
      # Get new position after scroll
      set pos [GetClickPos $wavfm $X scroll]
   }
   return $pos
}

proc SegmentSelect {wavfm segmt extend X y} {
   global v

   set pos [GetPosAfterScroll $wavfm $X]
   set nb [GetSegmentFromPos $segmt $pos beg end ov]
   if {$nb < 0} return
   if {$ov == 1} {
      set f [winfo parent $wavfm].$segmt
      set nb [expr $nb + ($y > [winfo height $f]/2)]
      set beg [GetSegmtField $segmt $nb -begin]
      set end [GetSegmtField $segmt $nb -end]
      if {!$extend} {
	 if {$segmt == "seg0"} {
	    SetCurrentSegment $nb
	 } elseif {$segmt == "seg1"} {
	 }
      }
   }
   PauseAudio
   set newbeg $beg
   set newend $end
   set mode "BEGIN"
   if {$extend && [GetSelection oldbeg oldend]} {
      if {($oldbeg < $beg) && ($oldend > $end)} {
	 if {$oldend-$beg < $end-$oldbeg} {
	    set newbeg $oldbeg
	    set mode "END"
	 } else {
	    set newend $oldend
	 }
      } elseif {$oldbeg < $beg} {
	 set newbeg $oldbeg
	 set mode "END"
      } elseif {$oldend > $end} {
	 set newend $oldend
      }
      # else 
      # SetCurrentSegment $nb
   }
   ViewSelection $beg $end
   SetSelection $newbeg $newend
   ViewSelection $beg $end $mode
}

proc EndSegmentSelect {segmt X y} {
   global v

   if {$v(play,auto)} {
      PlayFromBegin
   }
}

################################################################

# Events bindings for modification of segment boundaries

proc SegmentMove {wavfm segmt extend X y {force 0}} {
   global v

   set reso 0.001
   set pos [GetPosAfterScroll $wavfm $X]
   set epsilon [expr 10.0*$v($wavfm,size)/[winfo width $wavfm]]
   if {$epsilon < $reso} {set epsilon $reso}
   if {!$extend} {
      # Be sure we start close enough from existing boundary (10 pixels)
      set nb [GetSegmentFromPos $segmt $pos beg end ov]
      if {$nb < 0} return
      if {$ov == 1} {
	 set f [winfo parent $wavfm].$segmt
	 set nb [expr $nb + ($y > [winfo height $f]/2)]
	 set beg [GetSegmtField $segmt $nb -begin]
	 set end [GetSegmtField $segmt $nb -end]
      }
      if {abs($pos-$beg) > $epsilon && abs($pos-$end) > $epsilon } return

      # Choose the right side of segment
      if {$pos-$beg < $end-$pos} {
	 incr nb -1
      }
      set v(moved_id) {}
   } else {
      if {![info exists v(segmt,move)]} return
      # Keep moving same boundary during mouse motion
      set nb $v(segmt,move)
   }

   set nb1 $nb
   set pos1 $pos
   set moves {}
   set id ""
   while {1} {
      # Be sure we are not the first or last segment
      if {$nb < 0 || [expr $nb+1] >= [GetSegmtNb $segmt]} return
      
      # Get boundaries
      if {$id == ""} {
	 set id [GetSegmtField $segmt $nb -endId]
      }
      if [catch {expr double($id)}] {
	 Synchro::GetBoundaries $id center left right
	 if {$left == "" || $right == ""} return
      } else {
	 set center $id
	 set left   [GetSegmtField $segmt $nb -begin]
	 set right  [GetSegmtField $segmt [expr $nb+1] -end]
	 set id     ""
      }
      lappend moves [list $nb $id $pos]
      #puts "$nb $id $left $center $right => $pos"

      # Keep minimal apparent size for both segments
      if {$pos < $center && $pos-$left < $epsilon} {
	 if {!$force} return
	 if {$id != ""} {
	    set pos [expr $pos - $epsilon]
	    set id $Synchro::value($left)
	    continue
	 }
      } elseif {$pos > $center && $right-$pos < $epsilon} {
	 if {!$force} return
	 if {$id != ""} {
	    set pos [expr $pos + $epsilon]
	    set id $Synchro::value($right)
	    continue
	 }
      }
      break
   }

   # Really do it
   if {!$extend} {
      PauseAudio
      set v(segmt,move) $nb1
      # Register old position for undo
      if {$id != ""} {
	 DoModif "MOVE $id $center"
      } else {
	 DoModif "MOVE"
      }
   }
   foreach move $moves {
      foreach {nb id pos} $move {}
      if {$id == ""} {
	 SetSegmtField $segmt $nb -end $pos
	 SetSegmtField $segmt [expr $nb+1] -begin $pos
      } else {
	 Synchro::ModifyTime $id $pos
	 # Keep the list of all moved boundary ids
	 if {[lsearch -exact $v(moved_id) $id] < 0} {
	    lappend v(moved_id) $id
	 }
      }
   }
   SetSelection $pos1 $pos1
}

proc EndSegmentMove {segmt} {
   global v

   catch {
      foreach id $v(moved_id) {
	 Synchro::UpdateTimeTags $id
      }
      unset v(moved_id)
      unset v(segmt,move)
   }
}

################################################################

# Highlight current transcription and segment and register his number
# (called from :  SynchroToText, SynchroToSignal, DeleteSegment, 
# InsertSegment, UpdateTextFrame)
proc SetCurrentSegment {nb} {
   global v

   if {$nb < 0 || $nb >= [GetSegmtNb seg0] || [info exists v(demo)]} return
   set v(segmt,curr) $nb

   # Highlight current segment in text editor
   set t $v(tk,edit)-bis
   set bp [GetSegmtId $nb]
   foreach {first last} [$t tag nextrange "sync" "$bp.first"] {}
   $t tag remove "hilight" 1.0 end
   $t tag add "hilight" "$first" "$last+1c"
   
   # Highlight current segment under waveforms (level 0)
   foreach wavfm $v(wavfm,list) {
      set i [lsearch -glob $v($wavfm,seglist) "*seg0"]
      set s [lindex $v($wavfm,seglist) $i]
      catch {$s conf -current $nb}
   }

   # If necessary, set text cursor at end of transcription, and view around
   if {[$t compare insert <= "$first"] 
       || [$t compare insert > "$last"]} {
      set t $v(tk,edit)
      catch {
	 if {$v(preferedPos) == "begin"} {
	    $t see "$last"
	    tkTextSetCursor $t "$first linestart"
	 } else {
	    $t see "$first"
	    tkTextSetCursor $t "$last lineend"
	 }
      }
   }
   ViewAroundText
   
   # If necessary, set signal cursor at beginning of segment
   set beg [GetSegmtField seg0 $nb -begin]
   set end [GetSegmtField seg0 $nb -end]
   set pos [GetCursor]
   if {$pos<$beg || $pos>=$end} {
      # Select corresponding part of signal
      set play [IsPlaying]
      if {$play} {PauseAudio}
      SetSelection $beg $beg
      ViewSelection $beg $end "BEGIN"
      if {$play} {Play}
   }
}

# Synchronize text cursor position to signal cursor, if signal cursor
# moved out of current segment (called from SetCursor)
proc SynchroToSignal {pos} {
   global v

   if {[GetSegmtNb seg0]<=0} return
   # Did we move out of current segment ?
   if [info exists v(segmt,curr)] {
      set beg [GetSegmtField seg0 $v(segmt,curr) -begin]
      set end [GetSegmtField seg0 $v(segmt,curr) -end]
      if {$pos>=$beg && $pos<$end} return
   }
   # Get new current segment
   set nb [GetSegmentFromPos seg0 $pos {} {} ov]
   if {$nb < 0} return
   # For demo purposes only
   if {[info exists v(demo)]} {
      set txt [GetSegmtField seg0 $nb -text]
      .demo.txt insert insert "$txt "
      .demo.txt see insert
      set v(segmt,curr) $nb
      return
   }
   SetCurrentSegment [expr $nb+$ov]
}

# Synchronize signal cursor to text cursor position, if we moved out of
# current transcription
# (called from text widget after "mark set insert")
proc SynchroToText {bp} {
   global v

   # Really change of segment ?
   if {[info exists v(segmt,curr)] 
       && ($bp == [GetSegmtId $v(segmt,curr)])} {
      return
   }
   # Get real nb of segment
   set nb [SearchSegmtId seg0 $bp]
   if {$nb < 0} return
   SetCurrentSegment $nb
}

# Goto next/previous segment depending on $dir
# (or begin of signal)
proc MoveNextSegmt {dir} {
   global v

   set play [IsPlaying]
   if {[GetSegmtNb seg0] <= 0} {
      if {$dir < 0} {
	 set pos $v(sig,min)
	 SetSelection $pos $pos
	 #ViewSelection $pos $pos
      }
   } elseif {[info exists v(segmt,curr)]} {
      set nb $v(segmt,curr)
      set beg [GetSegmtField seg0 $v(segmt,curr) -begin]
      set end [GetSegmtField seg0 $v(segmt,curr) -end]
      set pos [GetCursor]
      if {$dir == -1 && 
	  (($pos-$beg>0.6 && $play) ||($pos>$beg  && !$play) || $nb==0)} {
	 SetCursor $beg
      } else {
	 if {$play} {PauseAudio}
	 SetCurrentSegment [expr $v(segmt,curr)+$dir]
      }
   }
   if {$play} {Play}
}

################################################################

# Join transcription tag with previous one, updating XML transcription
# editor display and segmentation widgets.
# Allows: 
#  - Turn->Sync  or  Section->Sync  (level=1 / tag=turn)
#  - Section->Turn  (level=2 / tag=section)
# Called by: DeleteSegment, ChangeSegType, and itself.
proc JoinTransTags {level tag2} {
   global v

   # Verify we are not the first segment
   set segmt "seg$level"
   set nb2 [SearchSegmtId $segmt $tag2]
   set nb1 [expr $nb2-1]
   if {$nb1 < 0} return
   set tag1 [GetSegmtId $nb1 $segmt]

   # Verify if propagate to upper level
   set fath1 [$tag1 getFather]
   set fath2 [$tag2 getFather]
   if {$fath1 != $fath2} {
      set answer [tk_messageBox -message [Local "You will also destroy the current section. Continue?"] -type okcancel -icon question]
      if {$answer != "ok"} {
	 return -code error cancel
      }
   }

   # Propagate new overlapping state
   if {$level == 1} {
      if {[OverlappingTurn $tag1]} {
	 if {![OverlappingTurn $tag2]} {
	    DoWho $tag2
	 }
      } else {
	 if {[OverlappingTurn $tag2]} {
	    NoWho $tag2
	 }
      }
   }

   # Join two segments in segmentation
   set timeOld [GetSegmtField $segmt $nb1 -endId]
   JoinSegmt $segmt $nb1 -first
   set time [GetSegmtField $segmt $nb1 -endId]

   # Suppress turn or section button in editor
   set t $v(tk,edit)-bis
   $t delete "$tag2.first" "$tag2.last"
   $t tag delete $tag2

   # Update ML transcription and keep time synchro
   if {$fath1 != $fath2} {
      JoinTransTags [expr $level+1] $fath2
   }
   $tag1 addChilds [$tag2 getChilds]
   $tag1 setAttr "endTime" [$tag2 getAttr "endTime"]
   Synchro::TagToForget $tag1 "endTime" $timeOld
   Synchro::TagToForget $tag2 "startTime" $timeOld
   Synchro::TagToForget $tag2 "endTime" $time
   Synchro::TagToUpdate $tag1 "endTime" $time
   $tag2 delete

   #DoModif "JOIN"
}

################################################################

# Split transcription tag, updating XML transcription
# editor display and segmentation widgets.
# Called by: ChangeSegType
proc SplitTransTags {level child vals} {
   global v

   # Level-dependent settings
   set atts ""
   if {$level == 1} {
      set insertButton InsertTurnButton
      set type "Turn"
      set atts ""
      set speaker [lindex $vals 0]
      if {$speaker != ""} {
	 lappend atts "speaker" $speaker
      }
      set mode [lindex $vals 1]
      if {$mode != ""} {
	 lappend atts "mode" $mode
      }
      set fidelity [lindex $vals 2]
      if {$fidelity != ""} {
	 lappend atts "fidelity" $fidelity
      }
      set channel [lindex $vals 3]
      if {$channel != ""} {
	 lappend atts "channel" $channel
      }
      set name [::speaker::name $speaker]
   } else {
      set insertButton InsertSectionButton
      set type "Section"
      set sectype [lindex $vals 0]
      set topic [lindex $vals 1] 
      set atts "type $sectype"
      if {$topic != ""} {
	 lappend atts "topic" $topic
	 set name [::topic::get_atts $topic]
      } else {
	 set name $sectype
      }
   }

   # Get child position
   set segmt "seg[expr $level-1]"
   set nb [SearchSegmtId $segmt $child]
   set time [GetSegmtField $segmt $nb -beginId]

   # Get tag position
   set segmt "seg$level"
   set tag1 [$child getFather]
   set nb1 [SearchSegmtId $segmt $tag1]
   if {$nb1 < 0} return
   if {$time == [GetSegmtField $segmt $nb1 -beginId]} {
      return $tag1
   }
   set timeEnd [GetSegmtField $segmt $nb1 -endId]

   # Update transcription
   set tag2 [::xml::element $type "$atts startTime [Synchro::GetTime $time] endTime [$tag1 getAttr endTime]" -after $tag1]
   $tag1 setAttr "endTime" [Synchro::GetTime $time]
   Synchro::TagToForget $tag1 "endTime" $timeEnd
   Synchro::TagToUpdate $tag1 "endTime" $time
   Synchro::TagToUpdate $tag2 "startTime" $time
   Synchro::TagToUpdate $tag2 "endTime" $timeEnd
   set childs [$tag1 getChilds]
   set pos [lsearch $childs $child]
   $tag1 setChilds [lrange $childs 0 [expr $pos-1]]
   $tag2 setChilds [lrange $childs $pos end]
   
   # Split segmentation at child begin position
   SplitSegmt $segmt $nb1 $time -keep $name $tag2

   # Insert turn or section button in editor
   set t $v(tk,edit)-bis
   $t mark set "memo" insert
   $t mark set insert "$child.first"
   $insertButton $tag2
   $t mark set insert "memo"

   # Update overlapping state
   if {$level == 1} {
      if {[OverlappingTurn $tag1]} {
	 if {[llength $speaker] <= 1} {
	    NoWho $tag2
	 }
      } else {
	 if {[llength $speaker] > 1} {
	    DoWho $tag2
	 }
      }
   }

   #DoModif "SPLIT"
   return $tag2
}

################################################################

# Split data field at requested position in two contiguous area
# before inserting some locked field (icon, etc.) - the last char
# of which should be tagged with the data id returned by this proc.
proc SplitData {{pos "insert"}} {
   global v
   set t $v(tk,edit)-bis

   set data1 [GetDataFromPos $pos]
   if {$data1 == ""} return
   set text1 [$t get "$data1.first+1c" $pos]
   set text2 [$t get $pos "$data1.last"]
   $data1 setData $text1
   set data2 [::xml::data $text2 -after $data1]
   $t tag add "$data2" "$pos" "$data1.last"
   $t tag remove "$data1" "$pos" "$data1.last"
   return $data2
}

proc JoinData {tag} {
   global v
   set t $v(tk,edit)-bis

   # Tags for data
   set data1 [GetDataFromPos "$tag.first"]
   set data2 [GetDataFromPos "$tag.last"]

   # Join contiguous data if possible
   if {$data1 != "" && $data2 != ""} {
      # Tag data2 as data1 and destroy data2
      if {[$t tag ranges $data2] != ""} {
	 $t tag add $data1 "$data1.last" "$data2.last"
      }
      $t tag delete $data2
      $data2 delete
   } elseif {$data2 != ""} {
      # Expand data2
      $t tag add $data2 "$tag.first-1c"      
   }

   # Suppress object tag in editor and transcription
   $t delete "$tag.first" "$tag.last"
   $t tag delete $tag
   # ...and in transcription
   $tag delete

   # Update data1
   if {$data1 != ""} {
      $data1 setData [$t get "$data1.first+1c" "$data1.last"]
   }
}

################################################################

proc InsertSegment {} {
   global v

   if {![info exist v(segmt,curr)]} return
   set nb $v(segmt,curr)
   set beg [GetSegmtField seg0 $nb -begin]
   set end [GetSegmtField seg0 $nb -end]

   set pos [GetCursor]
   if {$pos - $beg < 0.001 || $end - $pos < 0.001} {
      tk_messageBox -message "New segment boundary must be at least 1ms from existing boundaries" -type ok -icon error
      return
   }

   # Verify that sync and background are in right order
   set t $v(tk,edit)-bis
   set nbg [GetSegmentFromPos bg $pos]
   set back0 [GetSegmtId $nbg bg]
   set back1 [GetSegmtId [expr $nbg+1] bg]
   if {($back0 != "" && [$t compare $back0.last > insert])
    || ($back1 != "" && [$t compare $back1.first < insert])} {
      tk_messageBox -message "Please check background position inside segment before" -type ok -icon error
      return
   }

   # Simplified insertion on overlapping segments: don't split text
   set over [Overlapping $nb]
   if {$over} {
      set bp [GetSegmtId $nb]
      set last [lindex [$t tag nextrange "sync" "$bp.first"] 1]
      $v(tk,edit) mark set insert "$last"
    }
   
   # Update transcription and editor
   SpaceMagic
   set data2 [SplitData "insert"]
   set id2 [::xml::element Sync {} -before $data2]
   set pos [Synchro::NewTimeTag $id2 "time" $pos]
   InsertSyncButton $id2
   $v(tk,edit)-bis tag add "$data2" "insert-1c"

   if {$over} {
      CreateWho $id2
   }

   # Update segmentation
   set id1 [GetSegmtId $v(segmt,curr)]
   SplitSegmt seg0 $nb $pos [TextFromSync $id1] [TextFromSync $id2] $id2

   DoModif "INSERT"
   # let cursor move further inside segment if playback in course
   update
   SetCurrentSegment [incr nb]
   tkTextSetCursor $v(tk,edit) "insert linestart"
}

################################################################

proc DeleteSegment {{nb2 ""}} {
   global v

   if {$nb2 == ""} {
      if {![info exist v(segmt,curr)]} return
      set nb2 $v(segmt,curr)
   }
   if {$nb2 <1} {
      tk_messageBox -message "Can not destroy first segment" \
	  -type ok -icon error
      return
   }
   set nb1 [expr $nb2-1]

   set beg [GetSegmtField seg0 $nb1 -begin]
   set mid [GetSegmtField seg0 $nb1 -endId]
   set end [GetSegmtField seg0 $nb2 -end]
   if {$end <= $beg} {
      error "Problem with segment boundaries" 
   }

   set bp1 [GetSegmtId $nb1]
   set bp2 [GetSegmtId $nb2]

   # Suppress section and turn boundaries if necessary
   set turn1 [$bp1 getFather]
   set turn2 [$bp2 getFather]
   if {$turn1 != $turn2} {
      JoinTransTags 1 $turn2
   }

   # Deletion between overlapping segments
   if {[Overlapping $nb2]} {
      set wh0 [$bp2 getBrother "element" "Who" -1]
      set wh1 [$bp2 getBrother "element" "Who"]
      set wh2 [$wh1 getBrother "element" "Who"]
      set t $v(tk,edit)-bis
      $t mark set "insert" "$wh0.first"
      for {set tag [$wh1 getBrother]} {$tag != $wh2} {set tag $nexttag} {
	 if {[$tag class] == "element"} {
	    switch [$tag getType] {
	       "Background" {
		  InsertImage $tag "music"
	       }
	       "Event" - "Comment" {
		  InsertEvent $tag
	       }
	    }
	 } elseif {[$tag class] == "data"} {
	    InsertData $tag
	 }
	 set nexttag [$tag getBrother]
	 ::xml::node::link $tag -before $wh0
      }
      $t delete "$wh1.first" "$wh2.first"
      $wh1 delete
      #JoinData $wh1
      JoinData $wh2
   }

   # Suppress synchro button in editor and in transcription
   JoinData $bp2

   # Modify segmentation
   JoinSegmt seg0 $nb1 -text [TextFromSync $bp1]
   Synchro::TagToForget $bp2 "time" $mid
   DoModif "DELETE"
   SetCurrentSegment $nb1
}

################################################################

proc ChangeSegType {category {nb {}}} {
   global v

   if {$nb == ""} {
      if {![info exist v(segmt,curr)]} return
      set nb $v(segmt,curr)
   }
   set sync    [GetSegmtId $nb]
   set turn    [$sync getFather]
   set section [$turn getFather]

   switch $category {
      "Section" {
	 if {[$section getAttr "startTime"] != [$sync getAttr "time"]} {
	    if [catch {
	       set sec_atts [::section::choose "report"]
	    }] return
	    if {[$turn getAttr "startTime"] != [$sync getAttr "time"]} {
	       set type [lindex $sec_atts 0]
	       if {$type == "nontrans"} {
		  set tur_atts ""
	       } else {
		  set spk [lindex [lindex [::turn::get_atts $turn] 0] 0]
		  if [catch {
		     set tur_atts [::turn::choose $spk]
		  }] return
	       }
	       set turn [SplitTransTags 1 $sync $tur_atts]
	    }
	    set section [SplitTransTags 2 $turn $sec_atts]
	 } else {
	    #::section::edit
	 }
      }
      "Turn" {
	 if {[$turn getAttr "startTime"] != [$sync getAttr "time"]} {
	    set spk [::speaker::second_one]
	    if [catch {
	       set tur_atts [::turn::choose $spk]
	    }] return
	    #puts $tur_atts
	    set turn [SplitTransTags 1 $sync $tur_atts]
	 } else {
	    #::turn::edit

	    #if {[$turn getAttr "startTime"] == [$section getAttr "startTime"]} {
	    #   JoinTransTags 2 $section
	    #}
	 }
      }
      "Sync" {
	 #if {[$turn getAttr "startTime"] == [$sync getAttr "time"]} {
	 #    JoinTransTags 1 $turn
	 #}
      }
   }
   DoModif "TYPE"
}

################################################################
