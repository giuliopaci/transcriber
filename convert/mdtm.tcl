# RCS: @(#) $Id$

# mdtm.tcl - extension of the Transcriber program
# Copyright (C) 2003, LIMSI
# distributed under the GNU General Public License (see COPYING file)

namespace eval ::convert::mdtm {

  variable msg "NIST .mdtm data"
  variable ext ".mdtm"

  # only needed for compatibility with version <1.4.6
  proc readSegmt {content} {return [lindex [lindex [readSegmtSet $content] 0] 0]}
  if {[info commands ::ColorMap] == ""} {proc ::ColorMap c {return}}

  proc readSegmtSet {content args} {
    global v
    if {[info exists v(sig,name)]} {
      set sid [file tail [file root $v(sig,name)]]
    } else {
      set sid ""
    }
    array set spk {}
    array set gnd {}
    foreach line [split $content "\n"] {
      if {$line == "" || [string match ";;*" $line]} continue
      set speaker ""
      if {[scan $line "%s%s%f%f%s%s%s%s" id ch begin len type conf subtype speaker] >= 7} {
	# filter on signal id if available, else choose first id met
	if {$sid == ""} {
	  set sid $id
	} elseif {$id != $sid} {
	  continue
	}
	# currently only process speaker tags
	if {$type != "speaker"} continue
	set end [expr $begin+$len]
	set col [ColorMap $speaker]
	lappend spk($ch) [list $begin $end $speaker $col]

	switch -- $subtype {
	  "adult_male" { set val "Male"; set col "#00aaff" }
	  "adult_female" { set val "Female"; set col "#f67000"}
	  "child" { set val "Child"; set col green}
	  default { set val "?"; set col "#00cc00" }
	}
	lappend gnd($ch) [list $begin $end $val $col]

      } else {
	puts stderr "Warning - line '$line' ignored from .mdtm parsing"
      }
    }
    set result {}
    foreach ch [lsort [array names spk]] {
      lappend result [list $spk($ch) "MDTM speaker (chn $ch)"]
      lappend result [list $gnd($ch) "MDTM gender (chn $ch)" 0]
    }
    if {[llength $result] == 0} {
      puts stderr "Warning - no line matched $sid basename during .mdtm parsing"
    }
    return $result
  }
}