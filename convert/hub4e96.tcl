# Copyright (C) 1998, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval hub4e {

  variable msg "LDC Hub4e 96"
  variable ext ".txt .sgml"

   proc guess {name} {
     variable ext
     set filext [string tolower [file extension $name]]
     set f [open $name]; set magic [read $f 8]; close $f
     if {$magic == "<Episode" && [lsearch $ext $filext]>=0} {
       return 1
     } else {
       return 0
     }
   }

  proc readSegmt {content} {
    global v
   
    set esec ""
    set etur ""
    set text ""
    foreach tier {"section" "speaker" "transcript" "nonspeech"
      "bgmusic" "bgspeech" "bgother"} {
      set $tier {}
    }
    foreach line [split $content "\n"] {
      if {[anaTag $line type kind attlist]} {
	if {$kind == "close"} {
	  if {$type == "Segment" && $text != ""} {
	    lappend transcript [list $sync $etur $text "white"]
	  }
	  if {$type == "Segment"} {
	    unset sync
	  }
	  if {$type == "Section"  && $nseg == 0} {
	    # mark empty sections with a star
	    set lastseg [lindex $section end]
	    set lastseg [lreplace $lastseg 2 2 "*[lindex $lastseg 2]"]
	    set section [lreplace $section end end $lastseg]
	  }
	  continue
	}
	array set atts $attlist
	switch $type {
	  "Episode" {
	    set filename $atts(Filename)
	  }
	  "Section" {
	    set t ""
	    switch $atts(Type) {
	      "Story" { set t "report" }
	      "Filler" { set t "filler" }
	      "Commercial" { set t "nontrans" }
	      "Local_News" { set t "nontrans" }
	      "Sports_Report" { set t "nontrans" }
	    }
	    set nseg 0
	    set ssec $atts(S_time)
	    set esec $atts(E_time)
	    lappend section [list $ssec $esec $atts(Type) $v(color,bg-sect)]
	  }
	  "Segment" {
	    incr nseg
	    set stur $atts(S_time)
	    set etur $atts(E_time)
	    lappend speaker [list $stur $etur $atts(Speaker) $v(color,bg-turn)]
	    set sync $stur
	    set text ""
	  }
	  "Sync" {
	    # some data files are corrupted
	    if {$atts(Time)<$stur || $atts(Time)>$etur} continue
	    if {$text != ""} {
	      lappend transcript [list $sync $atts(Time) $text "white"]
	    }
	    set sync $atts(Time)
	    set text ""
	  }
	  "Comment" {
	    #
	  }
	  "Background" {
	    # within segments, handle background also as a Sync
	    if {[info exists sync]} {
	      if {$text != ""} {
		lappend transcript [list $sync $atts(Time) $text "white"]
	      }
	      set sync $atts(Time)
	      set text ""
	    }
	    # handle Music/Speech/Other types independantly
	    set kbg "bg[string tolower $atts(Type)]"
	    if {[info exists tbg($kbg)] && $tbg($kbg) != ""} {
	      lappend $kbg [list $sbg($kbg) $atts(Time) $tbg($kbg) $cbg($kbg)]
	    }
	    set tbg($kbg) "$atts(Type)=$atts(Level)"
	    set sbg($kbg) $atts(Time)
	    switch $atts(Level) {
	      "High" {
		set cbg($kbg) "grey50"
	      }
	      "Low" {
		set cbg($kbg) "grey80"
	      }
	      "Off" {
		set tbg($kbg) ""
		set cbg($kbg) "white"
	      }
	    }
	  }
	  "Speaker_list" {
	  }
	  "Speaker" {
	    set name $atts(Name)
	    set gender [string tolower $atts(Sex)]
	    if {$atts(Age)=="Child"} {set gender "child"}
	    if {$gender == "unk"} {set gender "unknown"}
	    set dialect [string tolower $atts(Dialect)]
	  }
	}
	unset atts
      } else {
	set line [string trim $line]
	if {$line != ""} {
	  if {$text != ""} {
	    append text " "
	  }
	  append text $line
	}
      }
    }
    foreach kbg {"bgmusic" "bgspeech" "bgother"} {
      if {[info exists tbg($kbg)] && $tbg($kbg) != ""} {
	lappend $kbg [list $sbg($kbg) $esec $tbg($kbg) $cbg($kbg)]
      }
    }
    # Don't show useless speaker turns at section boundaries
    set speaker [unify $speaker]
    #set background [support [union $bgmusic $bgspeech $bgother]]
    # Overlapping speech on clean background
    #set overlap [intersect [overlap $speaker "Speech+Overlap"] [complement $background]]
    # Speech is where transcript was typed in - plus a 0.2 sec. margin
    #set speech [support $transcript "speech" 0.2]
    # non-speech segments are only reliable on non-empty Filler/Story segments
    #set nonspeech [intersect [select $section {[FS][it]*}] [complement $speech] ""]
    # Detect pure music and music+speech segments
    #set puremusic [intersect [support $bgmusic] $nonspeech "Music"]
    #set musiconspeech [intersect [support $bgmusic] $speech "Speech+Music"]
    # Detect speech on noise != music/speech
    #set noise [intersect [support $bgother] [complement [union $bgmusic $bgspeech]]]
    #set purenoise [intersect $noise $nonspeech "Noise"]
    #set noisyspeech [intersect $noise $speech "Speech+Noise"]
    # Detect speech on speech != music/noise
    #set speechonspeech [intersect [intersect [support $bgspeech] [complement [union $bgmusic $bgother]]] $speech "Speech+Speech"]
    # Pure speech
    #set purespeech [intersect [complement [union $overlap $background]] $speech "Speech"]
    #set silence [intersect [complement $background] $nonspeech "Silence"]
    # Combine all
    #set all [selectlen [union $purespeech $silence $overlap $puremusic $musiconspeech $purenoise $noisyspeech $speechonspeech] 0.2]
    # display (only in the interactive case)
    if {[info command LookForSignal] != ""} {
      # pretty, isn't it?
      set speaker [colorize $speaker]
      LookForSignal $filename ""
      foreach tier {"bgmusic" "bgspeech" "bgother" "section" "speaker"} {
	if {![info exists $tier] || [llength $tier] == 0} continue
	set seg $tier
	set v(trans,$seg) [set $tier]
	foreach wavfm $v(wavfm,list) {
	  CreateSegmentWidget $wavfm $seg -full white
	}
      }
    }
    return $transcript
  }

}

namespace eval :: {

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

# attribute random color to segments according to label id
proc colorize {list1} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s1 e1 t1} $seg1 break
    if {[info exists color($t1)]} {
      set col $color($t1)
    } else {
      set col [randomColor]
      set color($t1) $col
    }
    lappend list2 [list $s1 $e1 $t1 $col]
  }
  return $list2  
}

proc intersect {list1 list2 {formatString "%s"}} {
  set list3 {}
  set n1 [llength $list1]
  set n2 [llength $list2]
  set i1 0
  set i2 0
  while {$i1 < $n1 && $i2 < $n2} {
    foreach {s1 e1 t1} [lindex $list1 $i1] break
    foreach {s2 e2 t2} [lindex $list2 $i2] break
    set s3 [max $s1 $s2]
    set e3 [min $e1 $e2]
    if {$s3 < $e3} {
      lappend list3 [list $s3 $e3  [format $formatString $t1 $t2]]
    }
    if {$e1 < $e2} {
      incr i1
    } else {
      incr i2
    }
  }
  return $list3
}

# sort segments
proc sort {list1} {
  return [lsort -real -index 0 $list1]
}

# join lists
proc union {args} {
  return [sort [eval concat $args]]
}

# select segments matching pattern
proc select {list1 pattern} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s1 e1 l1} $seg1 break
    if {[string match $pattern $l1]} {
      lappend list2 $seg1
    }
  }
  return $list2
}

# select segments with length within min/max range
proc selectlen {list1 min {max -1}} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s1 e1} $seg1 break
    if {$e1-$s1 >= $min && ($max < 0 || $e1-$s1 < $max)} {
      lappend list2 $seg1
    }
  }
  return $list2
}

# Temporal supoprt of list:
# fold adjacent sorted segments into a single one
proc support {list1 {label ""} {thres 0.0}} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s2 e2} $seg1 break
    if {[info exists e1]} {
      if {$s2 > $e1 + $thres} {
	lappend list2 [list $s1 $e1 $label]
	set s1 $s2
      }
      set e1 [max $e1 $e2]
    } else {
      set s1 $s2
      set e1 $e2
    }
  }
  if {[info exists e1]} {
    lappend list2 [list $s1 $e1 $label]
  }
  return $list2
}

proc overlap {list1 {label ""}} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s2 e2} $seg1 break
    if {[info exists e1]} {
      if {$s2 < $e1} {
	lappend list2 [list $s2 [min $e1 $e2] $label]
      }
      set e1 [max $e1 $e2]
    } else {
      set e1 $e2
    }
  }
  return [support $list2 $label]
}

proc complement {list1 {min 0.0} {max 99999.0} {label ""}} {
  set list2 {}
  foreach seg1 [support $list1] {
    foreach {s1 e1} $seg1 break
    if {$s1 > $min} {
      lappend list2 [list $min $s1 $label]
    }
    set min [max $min $e1]
  }
  if {$max > $min} {
    lappend list2 [list $min $max $label]
  }
  return $list2
}

# Temporal supoprt of list:
# fold adjacent sorted segments with similar label into a single one
proc unify {list1} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s2 e2 l2} $seg1 break
    if {[info exists e1]} {
      if {$s2 > $e1 || $l2 != $l1} {
	lappend list2 [list $s1 $e1 $l1]
	set s1 $s2
      }
    } else {
      set s1 $s2
    }
    set e1 $e2
    set l1 $l2
  }
  if {[info exists e1]} {
    lappend list2 [list $s1 $e1 $l1]
  }
  return $list2
}

# returns 1 if $line can be parsed as a tag, 0 else.
# if yes, returns type of tag , kind of tag (open/close/empty)
# and list of attribute name/values in following variables
#
# An error is raised if the line can not be parsed correctily
# but contains a "<"
proc anaTag {line varType varKind varAtts} {
  upvar $varType type
  upvar $varKind kind
  upvar $varAtts listAtts
  set Name {[a-zA-Z_:][a-zA-Z0-9._:-]*}
  set S "\[ \n\r\t\]"
  set Eq "$S*=$S*"
  #set AttValue "(\"\[^%&\"]*\"|'\[^%&']*')"
  # Relaxed match with unquotted values for SGML case - but exclude entities
  set AttValue "(\"\[^%&\"]*\"|'\[^%&']*'|\[^%&'\" \n\r\t<>]*)"
  set Attribute "($Name)$Eq$AttValue"
  if {[regexp "^$S*<(/?)($Name)(($S+$Attribute)*)$S*(/?)>$S*\$" $line \
	   all start type atts att1 nam1 val1 end]} {
    if {$start != ""} {
      if {$end != "" || $atts != ""} {
	error "can not parse tag from $line"
      }
      set kind "close"
    } else {
      set listAtts {}
      while {[regexp "^$S+${Attribute}(.*)" $atts match name val atts]} {
	set c [string index $val 0]
	if {$c == "'" || $c == "\""} {
	  set val [string range $val 1 [expr [string length $val]-2]] 
	}
	lappend listAtts $name $val
      }
      if {$end != ""} {
	set kind "empty"
      } else {
	set kind "open"
      }
    }
    return 1
  } else {
    if {[string first < $line] >= 0} {
      #error "can not parse tag from $line"
    }
    return 0
  }
}

}
