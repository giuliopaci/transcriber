# RCS: @(#) $Id$

# sdt.tcl - extension of the Transcriber program
# Copyright (C) 2001, LIMSI
 
# This conversion filter for Transcriber is distributed in the framework
# of the European project CORETEX (http://coretex.itc.it/)

namespace eval ::convert::sdt {

  variable msg "NIST .sdt data"
  variable ext ".sdt"


proc randomColor {} {
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

proc scaleColor {col scale} {
  if {[scan $col "#%2x%2x%2x" r g b]} {
    set col "\#"
    foreach c {$r $g $b} {
      set d [expr int($scale*$c)]
      append col [format "%02x" [expr $d>255 ? 255 : $d]]
    }
  }
  return $col
}

  # look for .stm (or .stm.norm) in same dir as .sgml or .wav then in their sibling paths 
  proc lookForFiles {name {exts {stm stm.norm}}} {
    global v

    set file_id [file root [file tail $v(sig,name)]]
    set file_id2 [lindex [split [file tail $name] .] 0]
    foreach ext $exts {
      foreach base [list $file_id $file_id2] {
	foreach path [list [file dir $name] [file dir $v(sig,name)] [file dir [file dir $name]]/* [file dir [file dir $v(sig,name)]]/*] {
	  
	  if {![catch {
	    set stm [lindex [glob $path/$base.$ext] 0]
	  }] && [file exists $stm]} {
	    return $stm
	  }
	}
      }
    }
    return ""
  }

  proc import {name} {
    global v

    LookForSignal [file dir $name]/[lindex [split [file tail $name] .] 0] ""
    readSegmt [ReadFile $name]
    
    # Try to open .trs file in main editor, else .stm
    set trs [lookForFiles $name {trs xml}]
    if {$trs != ""} {
      ::trs::import $trs
    } else {
      SegmtToTrans {}
    }
  }
  
# Read NIST .sdt file
proc readSegmt {content} {
  global v

  set file_id ""
  if {$v(sig,name) != ""} {
    set file_id [file root [file tail $v(sig,name)]]
    regsub -all -- "-" $file_id "_" file_id
  }

  foreach line [split $content "\n"] {

    # First, fast match on file name
    set fields [split $line]
    if {$file_id != "" && [lindex $fields 0] != $file_id} continue
    
    if {[scan $line "%s%s%f%f%f%\[^\n]" id type begin end conf opts]>=5} {
      set val $conf

      # Analyze options
      array set atts {}
      while {[regexp "\[ \t]+(\[0-9a-zA-Z_]+)=\"(\[^\"]*)\"(.*)" $opts all name val opts]} {
	set atts($name) $val
      }

      switch $type {
	"svolume" - "energy" - "bspeech" - "bnoise" - "language" {
	  lappend $type [list $begin $end "$type=$val"]
	}
	"story" - "topic" - "nospeech" - "silence" - "music" - "sentence" - "repeat" {
	  lappend $type [list $begin $end $type]
	}
	"speaker" {
	  set col ""
	  set val ""
	  catch {
	    set val $atts(spk_id)
	    if {[info exists color($val)]} {
	      set col $color($val)
	    } else {
	      set col [randomColor]
	      set color($val) $col
	    }
	  }
	  lappend $type [list $begin $end $val $col]
	}
	"gender" {
	  set col ""
	  set val ""
	  catch {
	    switch $atts(gender) {
	      "M" {
		set val "Male"
		set col "#00aaff"
	      }
	      "F" {
		set val "Female"
		set col "#f67000"
	      }
	      default {
		set val "?"
		set col "#00cc00"
	      }
	    }
	  }
	  lappend $type [list $begin $end $val $col]
	}
	"bandwidth" {
	  set col ""
	  set val ""
	  catch {
	    set val $atts(type)
	    switch $val {
	      "narrow" {
		set col "#808080"
	      }
	      "wide" {
		set col "#e0e0e0"
	      }
	    }
	  }
	  lappend $type [list $begin $end $val $col]
	}
	"commercial" {
	  if {$conf >= 0.95} {
	    set col "\#808080"
	  } elseif {$conf >= 0.90} {
	    set col "\#b0b0b0"
	  } else {
	    set col "\#f0f0f0"
	  }
	  lappend $type [list $begin $end "$type ($conf)" $col]
	}
	default {
	  set unkn($type) {}
	}
      }
      unset atts
    }
  }

  if {[llength [array names unkn]] > 0} {
    tk_messageBox -icon warning -message "Unknown SDT type(s) in $fileName: [array names unkn]"
  }

  #########################

  if {[info command LookForSignal] != ""} {
    global v

    #if {$v(sig,name) == ""} {LookForSignal $file_id ""}

    # Create new segmentation tiers
    foreach tier {"speaker" "gender" "bandwidth" "language" "sentence" "topic" "story" "nospeech" "music" "silence" "bnoise" "bspeech" "svolume" "energy" "repeat" "commercial" } {
      if {![info exists $tier]} continue
      set seg "$file_id:$tier"
      set v(trans,$seg) [set $tier]
      foreach wavfm $v(wavfm,list) {
	CreateSegmentWidget $wavfm $seg -full white
      }
    }
  }
  return
}
}