# RCS: @(#) $Id$

# Copyright (C) 1998, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval typ {

   variable msg "LDC .typ format"
   variable ext ".typ"

   # Read LDC typ (added field for topic, <bg> for Background)

   proc import {name} {
      global v

      set content [ReadFile $name]

      array set typ2ML {"sn" "nontrans" "sr" "report" "sf" "filler"}

      ::xml::dtd::xml_read $v(file,dtd)
      set v(trans,root) [::xml::element "Trans"]
      #    if {[info exists v(file,speakers)]} {
      #       $v(trans,root) addChilds [::xml::parser::read_file $v(file,speakers) -dtdname $v(file,dtd)]
      #       ::speaker::register
      #    }
      set episode [::xml::element "Episode" {} -in $v(trans,root)]

      # Transcription begins implicitly with a "nontrans" section
      set begin 0
      set text ""
      set type "sn"
      set topic ""
      set speaker ""
      set sec ""
      set tur ""
      set lines [split $content "\n"]
      if {$v(sig,name) != ""} {
	 set lines [concat $lines [list "<sn $v(sig,max)>"]]
      }
      foreach line $lines {
	 if [regexp {<([a-z][a-z0-9]*) ([0-9.]+)( ([^>]+))?>( <<((male|female|child), ((I|O), )?)?(.*)>>)?} \
		 $line match code time hasattrib attrib hasname hasgender gender hasnativ nativ name] {
	    if {[info exists begin] && $time>0} {
	       if {$time<$begin} {
		  continue
		  #error "Segments are not in right order ($time<$begin)" 
	       } elseif {$time == $begin} {
		  if {$time == $v(sig,max)} continue
		  # This can also happen for near values with the 1ms precision
	       }
	       if {![catch {set t $typ2ML($type)}]} {
		  if {$tur != ""} {
		     $tur setAttr "endTime" $begin
		  }
		  set tur ""
		  if {$sec != ""} {
		     $sec setAttr "endTime" $begin
		  }
		  set sec [::xml::element "Section" "type $t" -in $episode]
		  if {$topic != ""} {
		     $sec setAttr "topic" $topic
		  }
		  $sec setAttr "startTime" $begin
	       } else {
		  set t ""
	       }
	       if {$speaker != "" || $t != "" || $type == "t" || $type == "e1" || $type == "e2"} {
		  if {$type == "e2"} {
		     set speaker [lindex $overspk 0]
		  } elseif {$type == "e1"} {
		     set speaker [lindex $overspk 1]
		  }
		  if {$tur != ""} {
		     $tur setAttr "endTime" $begin
		     if {$type == "o"} {
			set speaker [concat [$tur getAttr "speaker"] $speaker]
			set overspk $speaker
		        # Following conversion handled in ConvertData
			#regexp ".*SPEAKER1: ?(.*) SPEAKER2: ?(.*)" $text all t1 t2
			#set text "\[1] $t1 \[2] $t2"
		     }
		  }
		  set tur [::xml::element "Turn" {} -in $sec]
		  if {$speaker != ""} {
		     $tur setAttr "speaker" $speaker
		  }
		  $tur setAttr "startTime" $begin
	       }
	       if {$type == "bg"} {
		  set m [expr [llength $bg]-1]
		  set bgTyp [lrange $bg 0 [expr $m-1]]
		  set bgLvl [lrange $bg $m end]
		  set attrs [list "time" $begin "type" $bgTyp "level" $bgLvl]
		  set sync [::xml::element "Background" $attrs -in $tur]
	       } else {
		  set sync [::xml::element "Sync" "time $begin" -in $tur]
	       }
	       if {$time > $begin} {
		  if {$text != ""} {::xml::data $text -in $tur}
	       }
	    } else {
	       # Just in case first line is not marked as a section
	       if {[lsearch [array names typ2ML] $code] < 0} {
		  set code "sr"
	       }
	    }
	    set begin $time
	    set type  $code
	    if {$type != "bg"} {
	       set topic [::topic::create $attrib]
	    } else {
	       set bg [string tolower $attrib]
	       set topic ""
	    }
	    regsub -all "_" $name " " name
	    set speaker ""
	    foreach onename [split $name "+"] {
	       set onename [string trim $onename]
	       lappend speaker [::speaker::create $onename "" $gender]
	    }
	    set text ""
	 } else {
	    if {$text != ""} {
	       append text " "
	    }
	    append text $line
	 }
      }
      if [info exists begin] {
	 if {$tur != ""} {
	    $tur setAttr "endTime" $begin
	 }
	 if {$sec != ""} {
	    $sec setAttr "endTime" $begin
	 }
      }
   }

   # By default, extend typ format with topic and background infos
   # Do not convert overlapping speech to standard typ format  <o> <e.>
   # but as: <t> <<speaker A + speaker B>> \n [1] ... [2] ...
   proc export {name {extend 1}} {
      global v
      array set ML2typ {"nontrans" "sn" "report" "sr" "filler" "sf"}

      set topic ""
      set channel [open $name w]
      set episode [$v(trans,root) getChilds "element" "Episode"]
      foreach sec [$episode getChilds "element" "Section"] {
	 set type $ML2typ([$sec getAttr "type"])
	 set time [$sec getAttr "startTime"]
	 if {$extend} {
	    set topic [$sec getAttr topic]
	    if {$topic != ""} {
	       set topic " [::topic::get_atts $topic]"
	    }
	 }
	 if {$time > 0 || $type != "sn" || $extend} {
	    puts -nonewline $channel [format "<$type %.3f$topic>" $time]
	 }
	 set turns [$sec getChilds "element" "Turn"]
	 for {set nt 0} {$nt < [llength $turns]} {incr nt} {
	    set tur [lindex $turns $nt]
	    set spk [$tur getAttr "speaker"]
	    if {$spk != ""} {
	       set spk [::speaker::name $spk]
	    }
	    if {[string index $type 0] != "s"} {
	       set time [$tur getAttr "startTime"]
	       puts -nonewline $channel [format "<t %.3f>" $time]
	    }
	    if {$spk != ""} {
	       puts $channel " <<$spk>>"
	    } elseif {$time > 0 || $type != "sn" || $extend} {
	       puts $channel ""
	    }
	    set type "t"
	    set do_nl 0
	    foreach chn [$tur getChilds] {
	       if {[$chn class] == "data"} {
		  set text [$chn getData]
		  if {$text != ""} {
		     puts -nonewline $channel $text
		     set do_nl 1
		  }
	       } elseif {[$chn class] == "element"} {
		  switch [$chn getType] {
		     "Sync" {
			if {$type != "t"} {
			   set time [$chn getAttr "time"]
			   if {$do_nl} {puts $channel ""; set do_nl 0}
			   puts $channel [format "<b %.3f>" $time]
			}
			set type "b"
		     }
		     "Background" {
			set time [$chn getAttr "time"]
			set bgTyp [$chn getAttr "type"]
			set bgLvl [$chn getAttr "level"]
			# Background saved as extension of typ format
			if {$extend} {
			   if {$do_nl} {puts $channel ""; set do_nl 0}
			   puts $channel [format "<bg %.3f $bgTyp $bgLvl>" $time]
			}
			set type "b"
		     }
		     "Who" {
			set nb [$chn getAttr "nb"]
			if {$nb > 1} { puts $channel "" }
			puts -nonewline $channel "SPEAKER$nb: "
			set do_nl 1
		     }
		     "Event" - "Comment" {
			puts -nonewline $channel [StringOfEvent $chn]
			set do_nl 1
		     }
		  }
	       }
	    }
	    if {$do_nl} {puts $channel ""; set do_nl 0}
	 }
      }
      set time [$sec getAttr "endTime"]
      puts $channel "<sn $time>"
      close $channel
   }

}
