# RCS: @(#) $Id$

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
    if {![catch {encoding system}]} {
      fconfigure $channel -encoding [EncodingFromName $v(encoding)]
    }
    set episode [$v(trans,root) getChilds "element" "Episode"]
    set bg ""
    set basename [quote [file root [file tail $v(sig,name)]]]
    puts $channel "<html>\n<head>\n<title>$basename</title>\n"
    if {![catch {encoding system}]} {
      puts $channel "<meta http-equiv=\"ContentType\" content=\"text/html; charset=$v(encoding)\">"
    }
    puts $channel "</head>\n<body>"
    puts $channel "<h1><center>$basename</center></h1>"
    puts $channel [quote "Program [$episode getAttr program]"]
    puts $channel [quote "of [$episode getAttr air_date]"]
    puts $channel "<br>"
    puts $channel [quote "Transcribed by [$v(trans,root) getAttr scribe],"]
    puts $channel [quote "version [$v(trans,root) getAttr version]"]
    puts $channel [quote "of [$v(trans,root) getAttr version_date]"]
    foreach sec [$episode getChilds "element" "Section"] {
      set topic [::section::long_name $sec]
      puts $channel "<h2><center><font color=\"\#990000\">[quote $topic]</font></center></h2>"
      set turns [$sec getChilds "element" "Turn"]
      for {set nt 0} {$nt < [llength $turns]} {incr nt} {
	set tur [lindex $turns $nt]
	set spk [::turn::get_name $tur]
	puts $channel "<h3><font color=\"\#3366FF\">[quote $spk]</font></h3>"
	puts $channel "<ul>"
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
		  puts $channel "</li>"
		}
		puts $channel "<li>"
		set li 1
	      }
	      "Background" {
		if {$bg != ""} {
		  puts $channel " <b>\[-$bg]</b> "
		}
		set bgTyp [$chn getAttr "type"]
		set bgLvl [$chn getAttr "level"]
		if {$bgLvl != "off"} {
		  set bg $bgTyp
		  puts $channel " <b>\[$bg-]</b> "
		} else {
		  set bg ""
		}
	      }
	      "Who" {
		set nb [$chn getAttr "nb"]
		if {$nb > 1} {
		  puts $channel "<br>"
		}
		puts $channel "<b>$nb:</b> "
	      }
	      "Event" - "Comment" {
		puts $channel "<i>[quote [StringOfEvent $chn]]</i>"
	      }
	    }
	  }
	}
	if {$li} {
	  puts $channel "</li>"
	}
	puts $channel "</ul>"
      }
    }
    puts $channel "</body>\n</html>"
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
