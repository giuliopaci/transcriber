# Copyright (C) 2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval html {

  variable msg "HTML format"
  variable ext ".html"

  proc quote val {
    regsub -all "&" $val {\&amp;} val
    regsub -all "<" $val {\&lt;} val
    regsub -all ">" $val {\&gt;} val
    return $val
  }

  proc export {name} {
    global v
    
    set channel [open $name w]
    set episode [$v(trans,root) getChilds "element" "Episode"]
    set bg ""
    puts $channel "<H1><CENTER>[quote [file root [file tail $v(sig,name)]]]</CENTER></H1>"
    puts $channel "Program [$episode getAttr program]"
    puts $channel "of [$episode getAttr air_date]"
    puts $channel "<BR>"
    puts $channel "Transcribed by [$v(trans,root) getAttr scribe],"
    puts $channel "version [$v(trans,root) getAttr version]"
    puts $channel "of [$v(trans,root) getAttr version_date]"
    foreach sec [$episode getChilds "element" "Section"] {
      set topic [::section::long_name $sec]
      puts $channel "<H2><CENTER><FONT COLOR=\"\#990000\">[quote $topic]</FONT></CENTER></H2>"
      set turns [$sec getChilds "element" "Turn"]
      for {set nt 0} {$nt < [llength $turns]} {incr nt} {
	set tur [lindex $turns $nt]
	set spk [::turn::get_name $tur]
	puts $channel "<H3><FONT COLOR=\"\#3366FF\">[quote $spk]</FONT></H3>"
	puts $channel "<UL>"
	set li 0
	foreach chn [$tur getChilds] {
	  if {[$chn class] == "data"} {
	    set text [$chn getData]
	    if {$text != ""} {
	      puts $channel [quote $text]
	    }
	  } elseif {[$chn class] == "element"} {
	    switch [$chn getType] {
	      "Sync" {
		if {$li} {
		  puts $channel "</LI>"
		}
		puts $channel "<LI>"
		set li 1
	      }
	      "Background" {
		if {$bg != ""} {
		  puts $channel " <B>\[-$bg]</B> "
		}
		set bgTyp [$chn getAttr "type"]
		set bgLvl [$chn getAttr "level"]
		if {$bgLvl != "off"} {
		  set bg $bgTyp
		  puts $channel " <B>\[$bg-]</B> "
		} else {
		  set bg ""
		}
	      }
	      "Who" {
		set nb [$chn getAttr "nb"]
		if {$nb > 1} {
		  puts $channel "<BR>"
		}
		puts $channel "<B>$nb:</B> "
	      }
	      "Event" - "Comment" {
		puts $channel "<I>[quote [StringOfEvent $chn]]</I>"
	      }
	    }
	  }
	}
	if {$li} {
	  puts $channel "</LI>"
	}
	puts $channel "</UL>"
      }
    }
    close $channel

    # Launch browser on exported .html
    set url $name
    if {[catch {
      exec iexplore $url &
    }] && [catch {
      exec netscape -remote "openFile ($url)"
    }] && [catch {
      exec netscape $url &
    }]} {
    } 
  }

}