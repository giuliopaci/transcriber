# RCS: @(#) $Id$

# Copyright (C) 1999-2000, DGA; (C) 2000-2002, LIMSI-CNRS
# part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
namespace eval ctm {

  variable msg "NIST .ctm format"
  variable ext ".ctm"
  
   proc readSegmtSet {content} {
     global v
     if {[info exists v(sig,name)]} {
       set sid [file tail [file root $v(sig,name)]]
     } else {
       set sid ""
     }
     array set segmtArr {}
     foreach line [split $content "\n"] {
       if {$line == "" || [string match ";;*" $line]} continue
       # reset optional values
       foreach {conf type speaker} {"" "" "" ""} break
       # <ALT...> sections are ignored (but may be infered from overlap)
       if {[scan $line "%s%s%f%f%s%s%s%s" id ch begin len text conf type speaker] >= 5} {
	 # filter on signal id if available, else choose first id met
	 if {$sid == ""} {
	   set sid $id
	 } elseif {$id != $sid} {
	   continue
	 }
	 set text [string trim $text]
         set end [expr $begin+$len]
	 # choose grey background color according to confidence
	 if {$conf != "" && [string is double -strict $conf]} {
	   set d [format "%02x" [expr {$conf < 0? 0: $conf >=1? 255 : int($conf*255)}]]
	   set col \#$d$d$d
	 } else {
	   set col ""
	 }
	 lappend segmtArr($ch) [list $begin $end $text $col]
	 if {$type != ""} {
	   lappend typeArr($ch) [list $begin $end $type [ColorMap $type]]
	 }
	 if {$speaker != ""} {
	   lappend spkArr($ch) [list $begin $end $speaker [ColorMap $speaker]]
	 }
       } else {
	 puts "Warning - wrong format for line '$line'"
       }
     }
     set result {}
     foreach ch [lsort [array names segmtArr]] {
       lappend result [list $segmtArr($ch) "CTM token (chn $ch)"]
       if {[info exists typeArr($ch)]} {
	 lappend result [list [unify $typeArr($ch)] "CTM type (chn $ch)"]
       }
       if {[info exists spkArr($ch)]} {
	 lappend result [list [unify $spkArr($ch)] "CTM speaker (chn $ch)"]
       }
     }
     if {[llength $result] == 0} {
       puts stderr "Warning - no line matched $sid basename during .ctm parsing"
     }
     return $result
   }

   # only needed for compatibility with version <1.4.6
   proc readSegmt {content} {return [lindex [lindex [readSegmtSet $content] 0] 0]}
   if {[info commands ::ColorMap] == ""} {proc ::ColorMap c {return}}

  # fold adjacent sorted segments with similar label(s) into a single one
  proc unify {list1 {delta 0.1} {lastfield "end"}} {
    set list2 {}
    foreach seg1 $list1 {
      foreach {s2 e2} $seg1 break
      set l2 [lrange $seg1 2 $lastfield]
      if {[info exists e1]} {
	if {abs($s2-$e1) > $delta || $l2 != $l1} {
	  set seg2 [list $s1 $e1]
	  eval lappend seg2 $l1
	  lappend list2 $seg2
	  set s1 $s2
	}
      } else {
	set s1 $s2
      }
      set e1 $e2
      set l1 $l2
    }
    if {[info exists e1]} {
      set seg2 [list $s1 $e1]
      eval lappend seg2 $l1
      lappend list2 $seg2
    }
    return $list2
  }


}
