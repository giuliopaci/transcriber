# convert from Childes format to transcriber format
# Written by Zhibiao Wu for LDC Nov. 3 1999

namespace eval cha {

  # A short string describing your format for use within file chooser
  variable msg "Childes format"
   
  # A list of authorized extensions (can use globbing syntax)
  # The first one is used as default extension for output
  variable ext ".cha"

  # The optional 'guess' proc returns 1 if the filename is of the format
  # else 0.
  # If this proc is not provided, default behaviour is to match one of
  # the extensions given in the variable ext as follows:
  proc guess {filename} {
    variable ext
    set filext [string tolower [file extension $filename]]
    if {[expr [lsearch $ext $filext]>=0]} {
       # Can also try to look at file header/magic number
       return 1
    }
    return 0
  }

  proc import {name} {
      global v

      if [catch {
      set content [ReadFile $name]
      regsub -all "\n\t" $content " " content
      set lines [split $content "\n"]

      ::xml::dtd::xml_read [file join $v(path,etc) "trans-cha.dtd"]
      set v(trans,root) [::xml::element "Trans"]
      set speakers [::xml::element "Speakers" {} -in $v(trans,root)]

      set lineindex 0
      set found 0
      set linelength [llength $lines]
      while {($lineindex < $linelength) && ($found == 0)} {
	  set line [lindex $lines $lineindex]
	  if {[regexp {Participants} $line] == 1} {
	      set found 1
	      set spkline [string range $line 15 end]
	      set spks [split $spkline ","]
	      foreach spk $spks {
		  regsub "^ *" $spk "" spk
		  regsub " *$" $spk "" spk
		  set speaker [::xml::element "Speaker" {} -in $speakers]
		  set sid [lindex $spk 0]
		  $speaker setAttr "id" [lindex $spk 0]
		  $speaker setAttr "name" [lindex $spk 1]
		  $speaker setAttr "role" [lindex $spk 2]
		  set spkname($sid)  [lindex $spk 1]
	      }
	  }
	  incr lineindex
      }
      ::speaker::register 

      set episode [::xml::element "Episode" {} -in $v(trans,root)]     
      set section [::xml::element "Section" {} -in $episode]
      set secStartTime 0
      set secEndTime 0
      set curTime 1
      $section setAttr "type" "report"

      set turn ""

      set found 0
      while {($lineindex < $linelength) && ($found == 0)} {
	  set line [lindex $lines $lineindex]
	  if {[regexp {^(\@[^:]+:).(.*)$} $line a b c] == 1} {
	      if {$turn == ""} {
		  set turn [::xml::element "Turn" {} -in $section]
		  $turn setAttr "startTime" 0
		  $turn setAttr "endTime" $curTime
	      }
	      set atts [list "desc" $b "type" "header" "extent" "instantaneous"] 
	      ::xml::data "\n" -in $turn
	      set event [::xml::element "Event" $atts -in $turn]
	      ::xml::data "$c" -in $turn

	      incr lineindex
	      
	  } else {
	      set found 1
	  }
      }

      set turn ""
      while {$lineindex < $linelength} {
	  set line [lindex $lines $lineindex]


	  if {[regexp {:} $line] == 1} {

	      if {[regexp {^\*([^:]+):.(.*)$} $line a b c] == 1} {

		  set turn [::xml::element "Turn" {} -in $section]
		  $turn setAttr "startTime"  $curTime
		  incr curTime
		  $turn setAttr "endTime" $curTime
	      }

	      set c $line
	      while {[regexp {^(.*)\%snd:.?\"[^\"]+\".([0-9]+).([0-9]+)} $c d2 c a2 b2] == 1} {
		  if {$turn ==""} {
		  } else {
		      $turn setAttr "startTime"  [expr  $a2/ 1000.000]
		      set curTime [expr $a2/1000]
		      $turn setAttr "endTime" [expr $b2 /  1000.000]
		      set secEndTime [expr $b2/1000.000]
		  }
	      }
	      set line $c

	     
	      if {[regexp {^\*([^:]+):.(.*)$} $line a b c] == 1} {
	      
		  $turn setAttr "speaker" [::speaker::create $spkname($b) "" ""]
		  while {[regexp {^([^\[]*)\[([^\]]+)\](.*)$} $c a b d c] == 1} {
		      ::xml::data $b -in $turn
		      
		      if {[regexp {^([^ ]+) (.+)$} $d e f g] == 1} {
			  set atts [list "desc" $f "type" "scope" "extent" "begin"] 
			  set event [::xml::element "Event" $atts -in $turn]
			  ::xml::data $g -in $turn
			  set atts [list "desc" $f "type" "scope" "extent" "end"] 
			  set event [::xml::element "Event" $atts -in $turn]
			  
		      } else { 
			  set atts [list "desc" $d "type" "scope" "extent" "instantaneous"] 
			  set event [::xml::element "Event" $atts -in $turn]
		      }
		  }
		  ::xml::data $c -in $turn
	      } else {
		  if {[regexp {^(\%[^:]+:).(.*)$} $line a b c] == 1} {
		      set atts [list "desc" $b "type" "dependent" "extent" "instantaneous"] 
		      ::xml::data "\n" -in $turn
		      set event [::xml::element "Event" $atts -in $turn]
		      ::xml::data "$c" -in $turn
		  }
		  if {[regexp {^(\@[^:]+:).(.*)$} $line a b c] == 1} {
		      set atts [list "desc" $b "type" "header" "extent" "instantaneous"] 
		      ::xml::data "\n" -in $turn
		      set event [::xml::element "Event" $atts -in $turn]
		      ::xml::data "$c" -in $turn
		  }
	      }
	  }
	  incr lineindex
	  set line [lindex $lines $lineindex]
	  
      }
     

      $section setAttr "startTime" $secStartTime

      if {$secEndTime == 0} {
	  $section setAttr "endTime" $curTime
      } else {
	  $section setAttr "endTime" $secEndTime
      }
  } errresult ] {
      error "$errresult, File Line Number: $lineindex"
  }
   }


  # The 'export' proc can be used to dump the file to the format
  # - see stm.tcl for an example
  proc export {filename} {
      global v

      set sndname $filename
      regexp {^.*[/\\]([^/\\]+)\.[^\.]+$} $sndname a sndname

      set cid() ""
      set channel [open $filename w]
      puts $channel "@Font\tMonaco:9"
      puts $channel "@Begin\t"
      puts -nonewline $channel "@Participants:\t"
      set speakers [$v(trans,root) getChilds "element" "Speakers"]
      set numspk 0
      foreach speaker [$speakers getChilds "element" "Speaker"] {
	  set siid [$speaker getAttr "id"]
          set sid [string range $siid [expr [string length $siid] - 3] end ]
          
	  set sname [$speaker getAttr "name"]
	  set cid($siid) $sid
	  if {$numspk != 0 } {
	      puts -nonewline $channel ", "
	  } 
	  set srole [$speaker getAttr "role"]
	  puts -nonewline $channel "$sid $sname $srole"
	  incr numspk
      }

      puts -nonewline $channel "\n"
      set episode [$v(trans,root) getChilds "element" "Episode"]
      foreach sec [$episode getChilds "element" "Section"] {
	  set time [$sec getAttr "startTime"]
	  
	  
	  set turns [$sec getChilds "element" "Turn"]
	  for {set nt 0} {$nt < [llength $turns]} {incr nt} {
	      set outstring ""
	      set tur [lindex $turns $nt]
	      set spk [$tur getAttr "speaker"]
	      set time  [$tur getAttr "startTime"] 
	      set endtime [$tur getAttr "endTime"] 
	      set time [expr int($time * 1000)]
	      set endtime [expr int($endtime * 1000)]
	      set timestamp "\%snd:.?\"$sndname\"_$time\_$endtime"
	      
	      set type "t"
	      set curspk [lindex $spk 0]
	      if {$cid($curspk) != ""} {
		  set outstring "$outstring\*$cid($curspk):\t"
	     }
	     foreach chn [$tur getChilds] {
		 if {[$chn class] == "data"} {
		     set text [$chn getData]
		     if {$text != ""} {
			 set outstring "$outstring$text"
		     }
		 } elseif {[$chn class] == "element"} {
		     switch [$chn getType] {
			 "Background" {
			     set time [$chn getAttr "time"]
			     set bgTyp [$chn getAttr "type"]
			     set bgLvl [$chn getAttr "level"]
			     # Background saved as extension of typ format
			     set type "b"
			 }
			 "Who" {
			     set nb [$chn getAttr "nb"]
			     if {$nb > 1} {
				 set curspk [lindex $spk [expr $nb - 1]]
				 
				 set outstring "$outstring\*$cid($curspk):\t"
			     }
			 }
			 "Event" {
			     set type [$chn getAttr "type"]
			     if {$type != "scope"} {
				 set os [$chn getAttr "desc"]
				 set outstring "$outstring$os"
				 set outstring "$outstring\t"
			     } else {
				 set desc [$chn getAttr "desc"]
				 if {[$chn getAttr "extent"] == "begin"} {
				     set outstring "$outstring\[$desc "
				 } elseif  {[$chn getAttr "extent"] == "end"} {
				     set outstring "$outstring\]"
				 } else {
				     set outstring "$outstring\[$desc\]"
				 }
			     }
			 }
			 "Comment" {
			     set outstring "$outstring%"
			     set cmt  [StringOfEvent $chn]
			     set cmt [string range $cmt 1 [expr [string length $cmt] -2 ]]
			     if {[regexp {^([a-zA-Z][a-zA-Z][a-zA-Z]:).(.*)$} $cmt a b c ] == 1} {
				 set outstring "$outstring$b\t$c"
			     } elseif {[regexp {^\@[^ ]:} $cmt] == 1} {
				 set outstring "$outstring$cmt\n"
			     } else {
				 set outstring "$outstringcmt:\t$cmt\n"
			     }
			 }
		     }
		     
		     
		 }
	     }
	     if {$spk != ""} {
		 puts $channel "$outstring $timestamp"
	     }
	 }
     }
     
      puts $channel "\n@End\t"
      close $channel
 }
}


