# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval hub4 {

  variable msg "LDC/NIST Hub4 format"
  variable ext ".txt .sgml .utf"

   proc guess {name} {
     variable ext
     set filext [string tolower [file extension $name]]
     set f [open $name]; set magic [read $f 8]; close $f
     if {([string match "<utf*" $magic]
	  || [string match -nocase "<episode" $magic])
	 && [lsearch $ext $filext]>=0} {
       return 1
     } else {
       return 0
     }
   }

  proc getOne {arrayName args} {
    upvar $arrayName atts
    foreach n $args {
      set m [string tolower $n]
      if {[info exists atts($m)]} {
	return $atts($m)
      }
    }
    return ""
  }

  proc readSegmtSet {content {import 0} args} {
    global v
   
    set esec ""
    set etur ""
    set text ""
    foreach tier {"section" "speaker" "transcript" "nonspeech" "noscore"
      "bgmusic" "bgspeech" "bgother" "overlap"} {
      set $tier {}
    }
    if {$import} {
      set sec ""
      set tur ""
      set speakers ""
      set episode ""
      set v(trans,root) [::xml::element "Trans"]
    }
    foreach line [split $content "\n"] {
      if {[anaTag $line type kind attlist]} {
	set type [string tolower $type]
	if {$kind == "close"} {
	  if {$type == "turn" || $type == "segment"} {
	    if {$text != ""} {
	      lappend transcript [list $sync $etur $text "white"]
	    }
	    unset sync
	  }
	  if {$type == "section"  && $nseg == 0} {
	    # mark empty sections as non-trans
	    set lastseg [lindex $section end]
	    set lastseg [lreplace $lastseg 2 2 "(non-trans) [lindex $lastseg 2]"]
	    set section [lreplace $section end end $lastseg]
	  }
	  continue
	}
	
	array set atts $attlist
	switch $type {
	  "episode" - "utf" {
	    set filename [getOne atts "filename" "audio_filename"]
	    if {$import} {
	      set episode [::xml::element "Episode" [list "program" [getOne atts "program"] \
		"air_date" [getOne atts "date"]] -in $v(trans,root)]
	      $v(trans,root) setAttr "audio_filename" [file root $filename]
	      $v(trans,root) setAttr "version" [getOne atts "version"]
	      $v(trans,root) setAttr "version_date" [getOne atts "version_date"]
	    }
	  }
	  "section" {
	    set tsec [getOne atts "type"]
	    set top ""
	    switch $tsec {
	      "Story" { set t "report" }
	      "Filler" { set t "filler" }
	      "Commercial" { set t "nontrans"; set top "commercial" }
	      "Local_News" { set t "nontrans"; set top "local news" }
	      "Sports_Report" { set t "nontrans"; set top "sport report" }
	      default { set t $tsec }
	    }
	    set nseg 0
	    set ssec [format %.3f [getOne atts "S_time" "startTime"]]
	    set esec [format %.3f [getOne atts "E_time" "endTime"]]
	    lappend section [list $ssec $esec $tsec]
	    if {$import} {
	      set sec [::xml::element "Section" \
		[list "startTime" $ssec "endTime" $esec \
		     "type" $t "topic" [::topic::create $top]] -in $episode]
	    }
	  }
	  "segment" - "turn" {
	    incr nseg
	    set stur [format %.3f [getOne atts "S_time" "startTime"]]
	    set etur [format %.3f [getOne atts "E_time" "endTime"]]
	    set s [getOne atts "speaker"]
	    lappend speaker [list $stur $etur $s]
	    set sync $stur
	    set text ""
	    if {$import} {
	      if {![info exists spkid($s)]} {
		set gender [getOne atts "spkrtype"]
		if {$gender == "altered"} {set gender "unknown"}
		set spkid($s) [::speaker::create $s "" $gender] 
	      }
	      # PB: don't properly manage overlapping speech
	      if {[info exists eetur] && $stur < $eetur} {
		set stur $eetur
		if {$stur >= $etur} {
		  set etur [expr $stur + 0.001]
		}
	      }
	      set tur [::xml::element "Turn" \
		   [list "startTime" $stur "endTime" $etur "speaker" $spkid($s) \
			"mode" [string tolower [getOne atts "mode"]] \
			"fidelity" [string tolower [getOne atts "fidelity"]] \
			"channel" ""] -in $sec]
	      set eetur $etur
	    }
	  }
	  "sync" - "time" {
	    set t [format %.3f [getOne atts "Time" "sec"]]
	    # some data files are corrupted
	    if {$t<$stur || $t>$etur} {
	      puts "wrong turn boundaries: $line"
	      continue
	    }
	    if {$text != ""} {
	      lappend transcript [list $sync $t $text "white"]
	    }
	    set sync $t
	    set text ""
	    if {$import} {
	      ::xml::element "Sync" [list "time" $t] -in $tur
	    }
	  }
	  "background" {
	    set t [format %.3f [getOne atts "Time" "startTime"]]
	    # within segments, handle background also as a Sync
	    if {[info exists sync]} {
	      if {$text != ""} {
		lappend transcript [list $sync $t $text "white"]
	      }
	      set sync $t
	      set text ""
	    }
	    if {$import && $t <= $etur} {
	      ::xml::element "Sync" [list "time" $t] -in $tur
	      # PB: should not reset other background kinds
 	      ::xml::element "Background" [string tolower $attlist] -in $tur
 	    }
	    # handle Music/Speech/Other types independantly
	    set typ [getOne atts "type"]
	    set lvl [string tolower [getOne atts "level"]]

	    set kbg "bg[string tolower $typ]"
	    if {[info exists tbg($kbg)] && $tbg($kbg) != ""} {
	      lappend $kbg [list $sbg($kbg) $t $tbg($kbg) $cbg($kbg)]
	    }
	    set tbg($kbg) "$typ=$lvl"
	    set sbg($kbg) $t
	    switch $lvl {
	      "high" {
		set cbg($kbg) "grey50"
	      }
	      "low" {
		set cbg($kbg) "grey80"
	      }
	      "off" {
		set tbg($kbg) ""
		set cbg($kbg) "white"
	      }
	    }
	  }
	  "comment" {	    #
	  }
	  "overlap" - "b_overlap" {
	    lappend overlap [list $atts(startTime) $atts(endTime) ""]
	  }
	  "b_noscore" {
	    lappend noscore [list $atts(startTime) $atts(endTime) ""]
	  }
	  "unclear" - "b_unclear" {
	    append text { [unclear]}
	  }
	  "foreign" - "b_foreign" {
	    append text { [foreign]}
	  }
	  "speaker_list" {
	    if {$import} {
	      set speakers [::xml::element "Speakers" {} -in $v(trans,root)]
	    }
	  }
	  "speaker" {
	    if {$import} {
	      set name [getOne atts "name"]
	      set gender [string tolower [getOne atts "sex"]]
	      if {[getOne atts "age"]=="Child"} {set gender "child"}
	      if {$gender == "unk"} {set gender "unknown"}
	      set dialect [string tolower [getOne atts "dialect"]]
	      set spkid($name) [::speaker::create $name "" $gender $dialect] 
	    }
	  }
	}
	unset atts
      } else {
	set line [string trim $line]
	if {$line != "" && $line != {[[NS]]}} {
	  if {$text != ""} {
	    append text " "
	  }
	  append text $line
	  if {$import} {
	    ::xml::data "$line " -in $tur
	  }
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
    set background [support [union $bgmusic $bgspeech $bgother]]
    # Overlapping speech on clean background added to explicit overlap tags
    set overlap [support [union $overlap [intersect [overlap $speaker] [complement $background]]] "Speech+Overlap"]
    # Speech is where transcript was typed in - plus a 0.2 sec. margin
    set speech [support $transcript "speech" 0.2]
    # non-speech segments are only reliable on non-empty report/filler segments
    set nonspeech [intersect [complement $noscore] [intersect [select $section {[rf]*}] [complement $speech]] ""]
    # Detect pure music and music+speech segments
    set puremusic [intersect [support $bgmusic] $nonspeech "Music"]
    set musiconspeech [intersect [support $bgmusic] $speech "Speech+Music"]
    # Detect speech on noise != music/speech
    set noise [intersect [support $bgother] [complement [union $bgmusic $bgspeech]]]
    set purenoise [intersect $noise $nonspeech "Noise"]
    set noisyspeech [intersect $noise $speech "Speech+Noise"]
    # Detect speech on speech != music/noise
    set speechonspeech [intersect [intersect [support $bgspeech] [complement [union $bgmusic $bgother]]] $speech "Speech+Speech"]
    # Pure speech
    set purespeech [intersect [complement [union $overlap $background]] $speech "Speech"]
    set silence [intersect [complement $background] $nonspeech "Silence"]
    # Combine all
    set all [selectlen [union $purespeech $silence $overlap $puremusic $musiconspeech $purenoise $noisyspeech $speechonspeech] 0.2]

    set result {}
    lappend result [list $all "Hub4 speech/non speech" 0]
    lappend result [list $bgmusic "Hub4 background music" 0]
    lappend result [list $bgspeech "Hub4 background speech" 0]
    lappend result [list $bgother "Hub4 background noise" 0]
    lappend result [list $section "Hub4 section" 1 $v(color,bg-sect)]
    lappend result [list [colorize $speaker] "Hub4 speaker"]
    lappend result [list $transcript "Hub4 transcription"]
    #LookForSignal $filename ""
    return $result
  }

  proc readSegmt {content} {
    # when requesting a single layer, just return transcription
    return [lindex [lindex [readSegmtSet $content] end] 0]
  }

  proc import {name} {
    global v
   
    if {![info exists v(file,speakers)]} {
      set v(file,speakers) [file join [file dir [file dir $name]] spkrlist.sgml]
    }
    if {[file exists $v(file,speakers)]} {
      set content [ReadFile $v(file,speakers)]
      append content "\n"
    }
    append content [ReadFile $name]
    ::xml::dtd::xml_read $v(file,dtd)
    readSegmtSet $content 1
  }

}

namespace eval :: {

# only needed for compatibility with version <1.4.6
if {[info commands ::ColorMap] == ""} {proc ::ColorMap c {return}}

# attribute random color to segments according to label id
proc colorize {list1} {
  set list2 {}
  foreach seg1 $list1 {
    foreach {s1 e1 t1} $seg1 break
    lappend list2 [list $s1 $e1 $t1 [ColorMap $t1]]
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

# map segment label to list
proc map {list1 maplist} {
  array set map $maplist
  set list2 {}
  foreach seg1 $list1 {
    foreach {s1 e1 l1} $seg1 break
    catch {
      set l1 $map($l1)
    }
    lappend list2 [list $s1 $e1 $l1]
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
	lappend listAtts [string tolower $name] $val
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
