# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

# Called from: NewTrans
proc InitEpisode {} {
   global v

   $v(trans,root) setAttr "scribe" $v(scribe,name)
   UpdateFilename
   set v(trans,version) 0
   UpdateVersion
}

# Called from: OpenAudioFile, InitEpisode
proc UpdateFilename {} {
   global v

   if {![info exist v(trans,root)] || $v(trans,root)==""} return
   $v(trans,root) setAttr "audio_filename" [file root [file tail $v(sig,name)]]
}

# called from: ReadTrans
proc GetVersion {} {
   global v

   if {[catch {
      set ver [$v(trans,root) getAttr "version"]
   }]} {
      set ver 0
   }
   set v(trans,version) $ver
}

proc IncrementTime {ti} {
   global v

   set new [expr [$v(trans,root) getAttr "elapsed_time"]+$ti]
   $v(trans,root) setAttr "elapsed_time" $new
   return $new
}

# Called from: SaveTrans, InitEpisode (<= NewTrans), EditEpisode
proc UpdateVersion {} {
   global v

   $v(trans,root) setAttr "version" [expr $v(trans,version)+1]
   $v(trans,root) setAttr "version_date" [clock format [clock seconds] -format "%y%m%d"]
}

proc EditEpisode {} {
   global v dial

   if {[HasModifs]} {
      UpdateVersion
   }
   set episode [$v(trans,root) getChilds "element" "Episode"]
   set w [CreateModal .epi "Episode attributes"]
   set f [frame $w.top -relief raised -bd 1]
   pack $f -fill both -expand true -side top
   if {$v(chatMode)} {
     set namlist {
       {"Audio filename" "Transcriber's name" "Version" "Last modification date" "Principal language" "CH_Coder" "CH_Coding" "CH_Filename" "CH_Font" "CH_Warning"}
       {"Program" "Recording date"}
     }
     set attlist {
       {"audio_filename" "scribe" "version" "version_date" "xml:lang" "coder" "coding" "filename" "font" "warning"}
       {"program" "air_date"}
     }
   } else {
     set namlist {
       {"Audio filename" "Transcriber's name" "Version" "Last modification date" "Principal language"}
       {"Program" "Recording date"}
     }
     set attlist {
       {"audio_filename" "scribe" "version" "version_date" "xml:lang"}
       {"program" "air_date"}
     }
   }
   foreach names $namlist atts $attlist item [list $v(trans,root) $episode] { 
      foreach att $atts name $names {
	 set dial($att) [$item getAttr $att]
	 EntryFrame $f.[string tolower $att] $name dial($att)
      }
   }
   #pack $f.xml:lang -side bottom
   set e $f.xml:lang
   menubutton $e.men -indicatoron 1 -menu $e.men.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -width 20
   menu $e.men.menu -tearoff 0
   foreach subl $v(language) {
      foreach {i name} $subl {}
      if {$name == ""} {
	 set name $i
      }
      if {$i == $dial(xml:lang)} {
	 $e.men configure -text [Local $name]
      }
      $e.men.menu add radiobutton -label [Local $name] -variable dial(xml:lang) -value $i -command [list $e.men configure -text [Local $name]]
   }
   pack $e.men -side right -padx 3m

   foreach name {"version" "version_date"} {
      FrameState $f.$name 0
   }
      set result [OkCancelModal $w $w]
   if {$result != "OK"} {
      return
   }
   DoModif "EPISODE"
   foreach atts $attlist item [list $v(trans,root) $episode] { 
      foreach att $atts {
	 $item setAttr $att $dial($att)
      }
   }
}

