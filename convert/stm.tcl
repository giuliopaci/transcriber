# RCS: @(#) $Id$

# Copyright (C) 1999-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
# conversion rules: updated 8 jan. 2001; 27 jun. 2001; 10 jul. 2001; 26 oct. 2004 ; 09 déc. 2004
#
# Export to stm (with option):
# ----------------------------
#
# While using stm export on command line, options can be specified by
# setting the global variable "stmopt":
# 
#   ex: trans -set stmopt value -export stm file 
#
#   value can be:
#
#       "pron" => Replace the string to which a pronouce event applies to, only
#                 if the "desc" attributes contains the string: "(...:)".
#                 ex: www.tf1.fr+[pron="(URL:) WWW point TF1 point fr]
#                  => WWW point TF1 point FR
#           
#       "svl" => in case of overlapping speech, keeps the name of tje 2 speakers
#                for the SVL task. The segment is always ignorated for transcription task. 
#
#       this values are exclusives => it is not possible to have svl and pron at the same time
#
#   file format: id channel speaker startTime endTime <o,cond,gender> transcript
# with
#   id = stm basename (up to 1st dot) restricted to alphanum chars (else "_")
#   channel = 1
#   speaker = speaker name restricted to alphanum chars (other mapped to "_")
#     <speaker scope!="global"> => prefixed by id"_"
#   cond =
#     f0 for default case
#     f1 for <turn mode="spontaneous" ...>
#     f2 for <turn channel="telephone" ...>
#     f3 for <background type="music" level="low/high">
#     f4 for <turn fidelity="low"...>
#         or <background type="speech/shh/other" level="low/high">
#     f5 for <speaker dialect="nonnative" ...> and !f3 and !f4
#     fx for f3&f4 or f3&f5 or f4&f5
#        or change of background condition in the middle of segment boundaries
#   gender = male/female/unknown ("child" type ignored)
#
# For <section type="nontrans" ...>
#     or turn with overlapping speech (spk1+spk2)
#     or segments containing instantaneous [nontrans] or [conv] or [lang...] tag
#     or segments between [nontrans-] and [-nontrans] or [lang-] and [-lang] tag:
#  "$id 1 excluded_region $t0 $t1 <o,,unknown> ignore_time_segment_in_scoring"
# 
# For segments containing only tags (other than nontrans/conv/lang*)
# or empty (no speaker):
#  "$id 1 inter_segment_gap $t0 $t1 <o,$cond,>"
#
# Note: 
#  - background tag within "nontrans" sections or overlapping speech may be ignored
#  - "child" speaker type ignored (gender=unknown)
#  - transcription from overlapping speech ignored
#  - comment tags, lexical or pronounce events ignored
#      (except instantaneous pronounce tags [pi] and [pif] similar to noises)
#  - non-instantaneous language events ignored if they apply to a single word
#      eg.  I say [lang=fr-] bonjour [-lang]        =>  I say bonjour
#      but  [lang=fr-] je vous dis bonjour [-lang]  =>  ignore_time_segment_in_scoring
#  - any noise event dumped within brackets -  eg. [b-] ... [-b]
#
#
# Import from .stm:
# ----------------
# by convention, each condition is mapped to a specific configuration
#     f0 -> nothing
#     f1 -> <turn mode="spontaneous">
#     f2 -> <turn channel="telephone">
#     f3 -> <background type="music" level="high">
#     f4 -> <background type="other" level="high">
#     f5 -> <speaker dialect="nonnative"> 
#     fx -> <background type="music other" level="high">
# the choice may be wrong, but export should put back the original condition.
#
# in speaker name, _ are replace by " ", and id prefix is stripped.
#
# ignore_time_segment_in_scoring is replaced by a "[nontrans]" string
#    in a "(no speaker)" turn
#
# inter_segment_gap is replaced by an empty string in a "(no speaker)" turn
#
# gaps not indicated by "inter_segment_gap" and shorter than 0.2 sec
#   are ignored and concatenated to the previous segment
# (this can be disabled using command line option '-set importMinGap 0.0')
namespace eval stm {

    variable msg "STM format"
    variable ext ".stm"
    
    # if set to 1, also process deprecated tag format <lang=...> </lang> etc.
    variable deprecated 0
    
    proc export {name} {
    global v
	
	# export any 'event'?
	setdef v(exportEvent) false
	
	# other export option
	setdef v(stmopt) ""
	
	variable head ""
	variable bgTime ""
	variable bgLvl "off"
	variable bgTyp ""
	variable oldtime ""
	variable time ""
	variable cond
	variable turncond
	variable txt
	variable channel [open $name w]
	variable base
	variable nontrans ""
	variable nontime 0
	variable alnum
	set nxt ""
	
    # provide explicit informations on export and used encoding in header
	if {![catch {encoding system}]} {
	    fconfigure $channel -encoding [EncodingFromName $::v(encoding)]
	    set msg " with encoding $::v(encoding)"
	} else {
	    set msg ""
	}
	set rev [lindex [split {$Revision$}] 1]
	puts $channel ";; Transcriber export by stm.tcl,v $rev on [clock format [clock seconds]]$msg"
	set episode [$v(trans,root) getChilds "element" "Episode"]
	if {[$episode getAttr program] != "" || [$episode getAttr air_date] != ""} {
	    puts $channel ";; program [$episode getAttr program] of [$episode getAttr air_date]"
	}
	puts $channel ";; transcribed by [$v(trans,root) getAttr scribe], version [$v(trans,root) getAttr version] of [$v(trans,root) getAttr version_date]"
	puts $channel ";;"
	
	# provide header for NIST sclite analysis
	puts $channel \
{;; CATEGORY "0" "" ""
;; LABEL "O" "Overall" "Overall"
;;
;; CATEGORY "1" "Hub4 Focus Conditions" ""
;; LABEL "F0" "Baseline//Broadcast//Speech" ""
;; LABEL "F1" "Spontaneous//Broadcast//Speech" ""
;; LABEL "F2" "Speech Over//Telephone//Channels" ""
;; LABEL "F3" "Speech in the//Presence of//Background Music" ""
;; LABEL "F4" "Speech Under//Degraded//Acoustic Conditions" ""
;; LABEL "F5" "Speech from//Non-Native//Speakers" ""
;; LABEL "FX" "All other speech" ""
;; CATEGORY "2" "Speaker Sex" ""
;; LABEL "female" "Female" ""
;; LABEL "male"   "Male" ""
;; LABEL "unknown"   "Unknown" ""}
	
	# get basename from filename up to first dot,
	# then keep only alphanumeric chars
	#set base [$v(trans,root) getAttr "audio_filename"]    
	set base [lindex [split [file tail $name] .] 0]
	if {[info tclversion] >= 8.3} {
	set alnum {[^[:alnum:]]+}
	} else {
	    set alnum "\[^\x30-\x39\x41-\x5A\x61-\x7A\xC0-\xD6\xD8-\xF6\xF8-\xFF]+"
	}
	regsub -all $alnum $base "_" base
	set base [string trim $base "_"]
	
	set episode [$v(trans,root) getChilds "element" "Episode"]
	foreach sec [$episode getChilds "element" "Section"] {
	    # ignore "nontrans" sections
	    if {[$sec getAttr "type"] == "nontrans"} {
		set t0 [format %.3f [$sec getAttr "startTime"]]
		set t1 [format %.3f [$sec getAttr "endTime"]]
		dump $t0
		ignore $t0 $t1
		continue
	    }
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
		if {$spk == ""} {
		    set spk "inter_segment_gap"
		    set gender ""
		} elseif {[llength $spk] == 1} {
		    catch {
			set atts [::speaker::get_atts $spk]
			set gender [lindex $atts 2]
			if {[lsearch -exact {"male" "female"} $gender] < 0} {
			    set gender "unknown"
			}
			set scope [lindex $atts 5]
			if {[lindex $atts 3] == "nonnative"} {
			    if {$turncond == "f4"} {
				set turncond "fx"
			    } else {
				set turncond "f5"
			    }
			}
		    }

		    set spk [normalize_name $spk]
		} else {
		    # exclude overlapping speech from stm
		    set t0 [format %.3f [$tur getAttr "startTime"]]
		    set t1 [format %.3f [$tur getAttr "endTime"]]
		    dump $t0
		    #  exclude overlapping speech from stm but keep the speaker names for SVL task
		    if {$v(stmopt) == "svl"} {
			set spk1 [normalize_name [lindex $spk 0]]
			set spk2 [normalize_name [lindex $spk 1]]
			ignoreSVL $t0 $t1 $spk1 $spk2
		    } else {
			ignore $t0 $t1
		    }
		    continue
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
			if {$txt != "" && [string index $txt [expr [string length $txt]-1]] != " "} {
			    append txt " "
			}
			append txt $data
		    } elseif {[$chn class] == "element"} {
			# Only if the gobal variable stmopt is set to "pron" on command line.
			# If the next event element type is "pronouce" and its extent "previous"
			# Replace the last word by the "desc" of the element tag, only if this
			# desc contains (...:) or (cent...), for example (URL:) or (19 cent...).
			# Note that because of tne NE, some previous event are no more closed to the
			# word it apllies to, that why there is the test ($|\s$)
			if {$v(stmopt) == "pron"} {
			    if {[$chn getType] == "Event" && [$chn getAttr "type"] == "pronounce"} {
				if {[$chn getAttr "extent"] == "previous"} { 
				    set desctmp [$chn getAttr "desc"]
				    # Replace the "19 cent..."
				    if {[regexp {cent\.\.\.} $desctmp all]} {
					regexp {([^ ]+)$} $txt all lastwrd
					if {[regexp {([0-9][0-9])([0-9][0-9])} $lastwrd all cent ten]} {
					    if { $ten != "00"} {
						regsub {[^ ]+($|\s$)} $txt "$cent cent $ten\2" txt
					    } else {
						regsub {[^ ]+($|\$)} $txt "$cent cents\2" txt	
					    }
					}
				    }
				    # Replace the Roman numbers "VI" or "URL" by the right pron
				    if {[regexp {^\(.*\:\)(\s*)(.*$)} $desctmp all type subst]} {
					regexp {([^ ]+)($|\s$)} $txt all lastwrd
					regsub {([^ ]+)($|\s$)} $txt "$subst" txt
				    }
				}
			    }
			}
			switch [$chn getType] {
			    "Background" {
				set bgTyp [$chn getAttr "type"]
				set bgLvl [$chn getAttr "level"]		      
				# detect first bg change after beginning of segment
				set newtime [format %.3f [$chn getAttr "time"]]
				if {$newtime == $time} {
				    setcond
				} elseif {$newtime > $time && $bgTime == ""} {
				    set bgTime $newtime
				}
			    }
			    "Sync" {
				set newtime [format %.3f [$chn getAttr "time"]]
				if {$time == "" || $newtime > $time} {
				    set time $newtime
				}
				dump $time
				set head "$base 1 $spk $time %s <o,%s,$gender> %s"
				set oldtime "$time"
				set bgTime ""
				setcond
			    }
			    "Who" {
				#set nb [$chn getAttr "nb"]
				#append txt " \[$nb] "
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
				if {$type == "language"} {
				    catch {set desc $::iso639($desc)}
				    set f(begin) " \[$type=$desc-] "
				    set f(end) " \[-$type] "
				    set f(instantaneous) " \[$type=$desc] "
				} else {
				    set f(begin) " \[$desc-] "
				    set f(end) " \[-$desc] "
				    set f(instantaneous) " \[$desc] "
				}
				switch $extn {
				    "previous" {
					if {$type == "noise" || $v(exportEvent)} {
					    if {[regexp {(.* )([^ ]+) *} $txt all txt prv]} {
						append txt "$f(begin) $prv $f(end)"
					    }
					}
				    }
				    "next" {
					if {$type == "noise" || $v(exportEvent)} {
					    set nxt "$f(begin) %s $f(end)"
					}
				    }
				    "begin" - "end" - "instantaneous" {
					if {$type == "noise" || $type == "language"|| $v(exportEvent)} {
					    append txt $f($extn)
					} elseif {$type == "pronounce" && $extn == "instantaneous"
						  && ($desc == "pi" || $desc == "pif")} {
					    append txt $f($extn)
					}
				    }
				}
			    }
			}
		    }
		}
	    }
	}
	if {[info exists tur]} {
	    dump [format %.3f [$tur getAttr "endTime"]]
	}
	if {$nontrans != ""} {
	    puts stderr "WARNING - unclosed nontrans/language/comment segment starting at $nontime in $name"
	}
	close $channel
    }
    
proc normalize_name {id} {
    variable base
    variable alnum
    # keep only alphanumeric chars in speaker name, replace other by _    
    set spk  [::speaker::name $id]
    set atts [::speaker::get_atts $id]
    set scope [lindex $atts 5]
    # the following line remove the comment int speaker name wich begins with ","
    regsub ",.*" $spk "" speaker
    regsub -all $alnum $spk "_" spk
    set spk [string trim $spk "_"]
    # prefix local names by file id
    if {$scope != "global" && ![string match ${base}* $speaker]} {
	set spk "${base}_$spk"
    } 
    return $spk
}

  proc setcond {} {
    variable turncond
    variable cond
    variable bgTyp
    variable bgLvl
    # set background condition for next segment
    if {$bgLvl == "off"} {
      set cond $turncond
    } elseif {$bgTyp == "music"} {
      if {$turncond == "f4" || $turncond == "f5" || $turncond == "fx"} {
	set cond "fx"
      } else {
	set cond "f3"
      }
    } elseif {[lsearch -exact $bgTyp "music"] >= 0} {
      set cond "fx"		    
    } else {
      if {$turncond == "f5" || $turncond == "fx"} {
	set cond "fx"
      } else {
	set cond "f4"
      }
    }
  }

  proc dump {t1} {
    variable head
    variable bgTime
    variable oldtime
    variable cond
    variable txt
    variable channel
    variable base
    variable nontrans
    variable nontime
    variable deprecated

    if {$head != ""} {
      # if bg condition changed in the middle of the segment
      if {$bgTime != "" && $bgTime < $t1} {
	set cond "fx"
      }
      if {$deprecated} {
	# normalize <...> </...> tags to [...-] [-...] syntax
	regsub -nocase -all "<((lang|nontrans|comment|pronounce)\[^/>\]*)>" $txt "\[\\1-\]" txt
	regsub -nocase -all "</((lang|nontrans|comment|pronounce)\[^>\]*)>" $txt "\[-\\1\]" txt
	# suppress [comment...-] ... [-comment...] or [comment...] tags
	regsub -nocase -all "\\\[(comment)\[^\]\]*(\]|-\].*\\\[-comment\[^\]\]*\])" $txt "" txt      
	# suppress [pronounce...-] and [-pronounce...] tags
	regsub -nocase -all "\\\[-?(pronounce)\[^\]\]*-?\]" $txt "" txt      
      }
      set notthis 0
      if {$nontrans == "" && [regexp -nocase "\\\[(nontrans|lang|comment)" $txt]} {
	# ignore language tags around a single word
	regsub -nocase -all "\\\[lang\[^\]\]*-\]( *\[^ \[\]* *)\\\[-lang\[^\]\]*\]" $txt "\\1" txt
	# replace other [lang...-] ... [-lang...] by [lang], idem for nontrans tags.
	regsub -nocase -all "\\\[(lang|nontrans)(\[^\]\]*)-\].*\\\[-\\1\[^\]\[\]*\]" $txt "\[\\1\\2\]" txt
	# detect beginning of unclosed nontrans or lang or comment segment
	if {[regexp -nocase "\\\[(nontrans|lang|comment)\[^\]\]*-\]" $txt all typ]} {
	  set nontrans $typ
	  set nontime $oldtime
	} elseif {[regexp -nocase "\\\[(nontrans|lang|conv)(\[^\]-\])*\]" $txt]} {
	  # exclude segments with nontrans/lang/conv intantaneous tags
	  set notthis 1
	}
      }
      # exclude segments within nontrans sections
      if {$nontrans != ""} {
	set notthis 1
      }
      if {$notthis || [regexp "^(\\\[\[^\]\]*\]|<\[^>\]*>| )*$" $txt]} {
	if {$notthis} {
	  if {$oldtime < $t1} {
	    ignore $oldtime $t1
	  }
	  # detect end of nontrans or lang or comment segment
	  if {$nontrans != "" && [regexp "\\\[-$nontrans\[^\]\[\]*\]" $txt]} {
	    set nontrans ""
	  }
	} else {
	  # segment contains only space or tags (except nontrans/lang./conv tags)
	  if {$oldtime < $t1} {
	    puts $channel "$base 1 inter_segment_gap $oldtime $t1 <o,$cond,>"
	  }
	}
      } else {
	# normalize spacing for text output
	regsub -all "  +" $txt " " txt
	puts $channel [format $head $t1 $cond [string trim $txt]]
	if {$oldtime >= $t1} {
	  puts stderr "WARNING - non-positive stm segment $oldtime-$t1 in $base.stm"
	}
	if {[string first "inter_segment_gap" $head] >= 0 } {
	  puts stderr "WARNING - transcription for no-speaker stm segment $oldtime-$t1 in $base.stm"	
	}
      }
    }
    set head ""
    set txt ""
  } 

  proc ignore {t0 t1} {
    variable channel
    variable base
    puts $channel "$base 1 excluded_region $t0 $t1 <o,,unknown> ignore_time_segment_in_scoring"
  }

  proc ignoreSVL {t0 t1 spk1 spk2} {
    variable channel
    variable base
    puts $channel "$base 1 $spk1,$spk2 $t0 $t1 <o,,unknown> ignore_time_segment_in_scoring"
  }


  proc import {name} {
    global v

    # intra-speaker inter-segment gaps which are not explicitly marked
    # and of lower duration than given will be merged with following segment
    setdef v(importMinGap) 0.2

    set file_id ""
    if {$v(sig,name) != ""} {
      set file_id [file root [file tail $v(sig,name)]]
      regsub -all -- "-" $file_id "_" file_id
    }

    set content [ReadFile $name]

    if {[info command ::xml::dtd::xml_read] != ""} {
      ::xml::dtd::xml_read $v(file,dtd)
    } else {
      ::xml::dtd::read $v(file,dtd)
    }
    set v(trans,root) [::xml::element "Trans"]
    set episode [::xml::element "Episode" {} -in $v(trans,root)]
    set sec [::xml::element "Section" "type report startTime 0 endTime 10" -in $episode]

    set speaker ""
    set tur ""
    set oldbg ""
    set precond ""
    set prev 0.0
    foreach line [split $content "\n"] {
      if {[string match ";;*" $line]} continue
      if {[regexp "^(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+\"(\[^\"]*)\"\[ \t]+(\[0-9.eE+-]+)\[ \t]+(\[0-9.eE+-]+)(\[ \t]+<\[^ \t]+>)?\[ \t]*(\[^\x01-\x1f]*)" $line all id chn spk begin end cnd text]
	  || [regexp "^(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+(\[0-9.eE+-]+)\[ \t]+(\[0-9.eE+-]+)(\[ \t]+<\[^ \t]+>)?\[ \t]*(\[^\x01-\x1f]*)" $line all id chn spk begin end cnd text]} {
	#if {$file_id !="" && $id != $file_id} continue
	set cnd [split [string tolower [string trim $cnd " \t<>"]] ","]
	set cond [lindex $cnd 1]
	if {$begin-$prev < $v(importMinGap)} {set begin $prev}
	# synchro times starting with "+" are floating
	if {[string index $begin 0] == "+"} {set begin " [string range $begin 1 end]"}
	if {[string index $end 0] == "+"} {set end "  [string range $end 1 end]"}
	if {$text == "ignore_time_segment_in_scoring"} {
	  set speaker ""
	  set text "\[nontrans]"
	}
	if {$tur == "" || $spk != $speaker || ($precond != $cond && $precond <= "f3" && $cond <= "f3")} {
	  set speaker $spk
	  set tur [::xml::element "Turn" "startTime $begin" -in $sec]
	  if {$speaker != "" && $speaker != "." && $speaker != "inter_segment_gap" && $speaker != "excluded_region"} {
	    # suppress id prefix from local names, and convert _ back to spaces
	    if {[string match ${id}* $spk]} {
	      set name [string range $spk [string length $id] end]
	      set scope "local"
	    } else {
	      set name $spk
	      set scope "global"
	    }
	    regsub -all "_" $name " " name
	    set name [string trim $name]
	    # gender (restricted to male/female/unknown)
	    set gender [lindex $cnd 2]
	    if {[lsearch -exact {"male" "female"} $gender] < 0} {
	      set gender "unknown"
	    }
	    # dialect
	    if {$cond == "f5"} {
	      set dialect "nonnative"
	    } else {
	      set dialect "native"
	    }
	    $tur setAttr "speaker" [::speaker::create $name "" $gender $dialect "" $scope]
	  }
	} elseif {$begin > $prev} {
	  set sync [::xml::element "Sync" "time $prev" -in $tur]
	}

	# turn conditions
	if {$cond == "f1"} {
	  $tur setAttr "mode" "spontaneous"
	}
	if {$cond == "f2"} {
	  $tur setAttr "channel" "telephone"
	}
	# dialect
	if {$cond == "f5"} {
	  set spkid [$tur getAttr "speaker"]
	  catch {
	    ::speaker::set_atts $spkid [lreplace [::speaker::get_atts $spkid] 3 3 "nonnative"]
	  }
	}
	# time
	$sec setAttr "endTime" $end
	$tur setAttr "endTime" $end
	set sync [::xml::element "Sync" "time $begin" -in $tur]
	set prev $end
	# background tier
	if {$cond == "f3"} {
	  set newbg "music"
	} elseif {$cond == "f4"} {
	  set newbg "other"
	} elseif {$cond == "fx"} {
	  set newbg "other music"
	} else {
	  set newbg ""
	}
	if {$oldbg != $newbg} {
	  if {$newbg == ""} {
	    set type "other"
	    set level "off"
	  } else {
	    set type $newbg
	    set level "high"
	  }
	  ::xml::element "Background" [list time $begin type $type level $level] -in $tur
	}
	set oldbg $newbg
	set precond $cond
	# transcription
	::xml::data [string trim $text] -in $tur
      } else {
	puts "Warning - wrong format for line '$line'"
      }
    }
  }

  # import transcription from .stm as labels
   proc readSegmtSet {content} {
     global v
     if {[info exists v(sig,name)]} {
       set sid [file tail [file root $v(sig,name)]]
     } else {
       set sid ""
     }
     array set segmt {}
     foreach line [split $content "\n"] {
       if {$line == "" || [string match ";;*" $line]} continue
       if {[scan $line "%s%s%s%f%f%\[^\n\]" id ch spk begin end remain] == 6} {
	 # filter on signal id if available, else choose first id met
	 if {$sid == ""} {
	   set sid $id
	 } elseif {$id != $sid} {
	   continue
	 }
	 regexp "(\[ \t]+<(\[^ \t>]+)>)?\[ \t]*(.*)" $remain all cnd cond text
	 set text [string trim $text]
	 set cond [split [string tolower $cond] ","]

	 if {[string tolower $text] != "ignore_time_segment_in_scoring" && $text != ""} {
	   lappend segmt($ch) [list $begin $end $text]
	   if {[string tolower $spk] != "inter_segment_gap"} {
	     lappend speaker($ch) [list $begin $end $spk [ColorMap $spk]]
	   }
	 }

	 if {[lsearch $cond "male"] >= 0} {
	   lappend gender($ch) [list $begin $end "Male" "#00aaff"]
	 } elseif {[lsearch $cond "female"] >= 0} {
	   lappend gender($ch) [list $begin $end "Female" "#f67000"]
	 }

	 # extract f-cond - narrow bandwidth, noise or music infos
	 # mutually exclusives (so fx considered simply as noise)
	 set fcond [lindex $cond [lsearch -glob $cond f?]]
	 if {$fcond == "f2"} {
	   lappend bandwidth($ch) [list $begin $end "Narrow" "#808080"]
	 } elseif {$fcond != "" && $fcond != "fx"} {
	   lappend bandwidth($ch) [list $begin $end "Wide" "#e0e0e0"]
	 }
	 if {$fcond == "f3"} {
	   lappend background($ch) [list $begin $end "Music" "#e0e0e0"]
	 } elseif {$fcond == "f4" || $fcond == "fx"} {
	   lappend background($ch) [list $begin $end "Noise" "#808080"]
	 }
       } else {
	 puts "Warning - wrong .stm format for line '$line'"
       }
     }
     set result {}
     foreach ch [lsort [array names segmt]] {
       lappend result [list $segmt($ch) "STM text (chn $ch)"]
       foreach var {speaker gender bandwidth background} {
	 if {[info exists ${var}($ch)]} {
	   lappend result [list [unify [set ${var}($ch)]] "STM $var (chn $ch)"]
	 }
       }
     }
     if {[llength $result] == 0} {
       puts stderr "Warning - no line matched $sid basename during .stm parsing"
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
