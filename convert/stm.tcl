# RCS: @(#) $Id$

# Copyright (C) 1999-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
namespace eval stm {

  variable msg "STM format"
  variable ext ".stm"

  proc export {name} {
    global v

    #;; LABEL "F0" "Baseline//Broadcast//Speech" ""
    #;; LABEL "F1" "Spontaneous//Broadcast//Speech" ""
    #;; LABEL "F2" "Speech Over//Telephone//Channels" ""
    #;; LABEL "F3" "Speech in the//Presence of//Background Music" ""
    #;; LABEL "F4" "Speech Under//Degraded//Acoustic Conditions" ""
    #;; LABEL "F5" "Speech from//Non-Native//Speakers" ""
    #;; LABEL "FX" "All other speech" ""

    set head ""
    set head2 ""
    set time ""
    set bgLvl "off"
    set bgTyp ""
    set bgTime ""
    set nxt ""
    set channel [open $name w]
    #set base [$v(trans,root) getAttr "audio_filename"]
    set base [string trim [file root [file tail $name]] _]
    set episode [$v(trans,root) getChilds "element" "Episode"]
    foreach sec [$episode getChilds "element" "Section"] {
      foreach tur [$sec getChilds "element" "Turn"] {
	set turncond "f0"
	if {[$tur getAttr "mode"] == "spontaneous"} {
	  set turncond "f1"
	}
	if {[$tur getAttr "channel"] == "telephone"} {
	  set turncond "f2"
	}
	if {[$tur getAttr "fidelity"] == "low"} {
	  set turncond "f4"
	}
	set spk [$tur getAttr "speaker"]
	set gender ""
	set scope "global"
	if {$spk != ""} {
	  if {[llength $spk] == 1} {
	    catch {
	      set atts [::speaker::get_atts $spk]
	      set gender [lindex $atts 2]
	      set scope [lindex $atts 5]
	      if {[lindex $atts 3] == "nonnative"} {
		if {$turncond == "f4"} {
		  set turncond "fx"
		} else {
		  set turncond "f5"
		}
	      }
	    }
	  } else {
	    set turncond "f4"
	  }
	  set spk [string trim [::speaker::name $spk]]
	  if {$scope != "global"} {
	    set spk "$base $spk"
	  }
	  # replace spaces with _ , suppress quotes in name
	  regsub -all "\[ \t\n]+" $spk "_" spk
	  regsub -all "\[\"^]" $spk "" spk
	}
	if {$spk == ""} {
	  set spk "."
	  set gender ""
	}
	foreach chn [$tur getChilds] {
	  if {[$chn class] == "data"} {
	    set data [$chn getData]
	    regsub -all "\n" $data " " data
	    if {$nxt != ""} {
	      if {[regexp { *([^ ]+)( .*)} $data all wrd data]} {
		append txt [format $nxt $wrd]
	      }
	      set nxt ""
	    }
	    if {$txt != "" &&
		[string index $txt [expr [string length $txt]-1]] != " "} {
	      append txt " "
	    }
	    append txt $data
	  } elseif {[$chn class] == "element"} {
	    switch [$chn getType] {
	      "Background" {
		set bgTyp [$chn getAttr "type"]
		set bgLvl [$chn getAttr "level"]		      
		# detect first bg change after beginning of segment
		set newtime [format %.3f [$chn getAttr "time"]]
		if {$newtime == $time} {
		  # set background condition for current segment
		  if {$bgLvl == "off"} {
		    set cond $turncond
		  } elseif {$bgTyp == "music"} {
		    if {$turncond == "f4" || $turncond == "f5"} {
		      set cond "fx"
		    } else {
		      set cond "f3"
		    }
		  } else {
		    if {$turncond == "f5"} {
		      set cond "fx"
		    } else {
		      set cond "f4"
		    }
		  }
		} elseif {$newtime > $time && $bgTime == ""} {
		  set bgTime $newtime
		}
	      }
	      "Sync" {
		set newtime [format %.3f [$chn getAttr "time"]]
		if {$time == "" || $newtime > $time} {
		  set time $newtime
		  if {$head != ""} {
		    # if bg condition changed in the middle of the segment
		    if {$bgTime != "" && $bgTime < $time} {
		      set cond "fc"
		    }
		    if {[regexp "^(\\\[\[^\]\]*\]| )*$" $txt]} {set head $head2}
		    puts $channel [format $head $time $cond $txt]
		  }
		}
		set head "$base 1 $spk $time %s <o,%s,$gender> %s"
		set head2 "$base 1 $spk $time %s <o,%s,> %s"
		set txt ""
		set bgTime ""
		# set background condition for next segment
		if {$bgLvl == "off"} {
		  set cond $turncond
		} elseif {$bgTyp == "music"} {
		  if {$turncond == "f4" || $turncond == "f5"} {
		    set cond "fx"
		  } else {
		    set cond "f3"
		  }
		} else {
		  if {$turncond == "f5"} {
		    set cond "fx"
		  } else {
		    set cond "f4"
		  }
		}
	      }
	      "Who" {
		set nb [$chn getAttr "nb"]
		append txt " \[$nb] "
	      }
	      "Comment" {
		#set desc [$chn getAttr "desc"]
		#append txt "<comment>$desc</comment>"
	      }
	      "Event" {
		set desc [$chn getAttr "desc"]
		set type [$chn getAttr "type"]
		set extn [$chn getAttr "extent"]
		# replace spaces with _ in description
		regsub -all "\[ \t\n]+" $desc "_" desc
		if {$type == "noise"} {
		  set f(begin) " \[$desc-] "
		  set f(end) " \[-$desc] "
		  set f(instantaneous) " \[$desc] "
		} else {
		  if {$type == "language"} {
		    catch {set desc $::iso639($desc)}
		    set desc "nontrans-$desc"
		  }
		  set f(begin) " \[$desc-] "
		  set f(end) " \[-$desc] "
		  set f(instantaneous) " \[$desc] "
		  #set f(begin) "<$type=$desc>"
		  #set f(end) "</$type>"
		  #set f(instantaneous) "$f(begin) $f(end)"
		}		     
		switch $extn {
		  "previous" {
		    if {$type == "noise"} {
		      if {[regexp {(.* )([^ ]+) *} $txt all txt prv]} {
			append txt "$f(begin) $prv $f(end)"
		      }
		    }
		  }
		  "next" {
		    if {$type == "noise"} {
		      set nxt "$f(begin) %s $f(end)"
		    }
		  }
		  "begin" - "end" {
		    if {$type == "noise"} {
		      append txt $f($extn)
		    }
		  }
		  "instantaneous" {
		    append txt $f($extn)
		  }
		}
	      }
	    }
	  }
	}
      }
    }
    set time [format %.3f [$tur getAttr "endTime"]]
    if {$head != ""} {
      # if bg condition changed in the middle of the segment
      if {$bgTime != "" && $bgTime < $time} {
	set cond "fc"
      }
      if {[regexp "^(\\\[\[^\]\]*\]| )*$" $txt]} {set head $head2}
      puts $channel [format $head $time $cond $txt]
    }
    close $channel
  }

  # import only transcription from .stm - no use of spk/conditions
   proc readSegmt {content} {
     set segmt {}
     foreach line [split $content "\n"] {
       if {[string match ";;*" $line]} continue
       if {[regexp "(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+(\[0-9.eE+-]+)\[ \t]+(\[0-9.eE+-]+)(\[ \t]+<\[^ \t]+>)?\[ \t]*(\[\x20-\xff]*)" $line all id chn spk begin end cnd text]} {
	 set text [string trim $text]
	 lappend segmt [list $begin $end $text]
       } else {
	 puts "Warning - wrong format for line '$line'"
       }
     }
     return $segmt
   }
}
