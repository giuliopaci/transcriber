# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
# Native transcription in XML format I/O

namespace eval trs {
   variable msg "Native XML format"
   variable ext ".trs .xml"

   proc guess {name} {
     # any XML file with 'Trans' root tag is supposed to be a .trs file
     set f [open $name]; set magic [read $f 128]; close $f
     if {[string match "<?xml*" $magic] && [string match "*<!DOCTYPE Trans *" $magic]} {
       return 1
     } else {
       return 0
     }
   }

   proc import {name} {
      global v
      
      # Read transcription should follow the original DTD
      ::xml::dtd::xml_read $v(file,dtd)
      set v(trans,root) [::xml::parser::read_file $name -keepdtd 1]
      ::speaker::register
      ::topic::register
   }

   proc export {name} {
      global v
      
      ::xml::parser::write_file $name $v(trans,root)
   }
}

################################################################
# Init handlers for all formats

proc InitConvertors {} {
   global v

   foreach module [glob [file join $v(path,base) "convert" *.tcl]] {
      namespace eval convert [list source $module]
   }

   set v(ext,trs) {}
   set v(ext,lbl) {}
   set v(newtypes) {}
   foreach format [concat "trs" [namespace children convert]] {
      upvar 0 ${format}::msg msg
      upvar 0 ${format}::ext ext
      if {[info command ${format}::import] != ""
	  || [info command ${format}::readSegmt] != ""
	  || [info command ${format}::readSegmtSet] != ""} {
	 lappend v(newtypes) [list $msg $ext]
	 # Add default guess proc from input extensions
	 if {[info command ${format}::guess] == ""} {
	    namespace eval $format {
	       proc guess {name} {
		  variable ext
		  set filext [string tolower [file extension $name]]
		  return [expr [lsearch $ext $filext]>=0]
	       }
	    }
	 }
	 # Add default readSegmt proc from readSegmtSet
	 if {[info command ${format}::readSegmt] == ""
	     && [info command ${format}::readSegmtSet] != ""} {
	   namespace eval $format {
	     proc readSegmt {content} {
	       return [lindex [lindex [readSegmtSet $content] 0] 0]
	     }
	   }
	 }
	 if {[info command ${format}::import] != ""} {
	    eval lappend v(ext,trs) $ext
	 } elseif {[info command ${format}::readSegmt] != ""} {
	    eval lappend v(ext,lbl) $ext
	 }
      }
   }
   #UpdateConvertorMenu
}

proc UpdateConvertorMenu {} {
   global v

   foreach format [namespace children convert] {
      upvar 0 ${format}::msg msg
      if {[info command ${format}::export] != ""} {
	 if {[namespace tail $format] == "cha" && !$v(chatMode)} continue
	 append_menu "Export" [subst {
	    {"Export to $msg..."	cmd {SaveTrans as $format}}
	 }]
      }
   }
}

################################################################
# Read single-level segmentations

# Read any file
proc ReadFile {fileName} {
   global v

   set channel [open $fileName r]
   # Read with chosen encoding (intended for tcl/tk 8.1 only)
   if {![catch {encoding system}]} {
      fconfigure $channel -encoding [EncodingFromName $v(encoding)]
   }
   set text [read -nonewline $channel]
   close $channel
   return $text
}

proc LookForLabelFormat {name} {
   global v
   # Look for a segmentation format matching the file
   set format ""
  foreach ns [lsort [namespace children convert]] {
     if {[info command ${ns}::readSegmt] != "" && [${ns}::guess $name]} {
       set format $ns
       break
     }
   }
   return $format
}

# Open one or severel new independant segmentation files
proc OpenSegmt {args} {
   global v

   if {$args != ""} {
     set names $args
   } else {
     set types [subst {
       {"Label file"   {$v(ext,lbl)}}
       {"All files"   {*}}
     }]
     if {$v(labelNames) != {}} {
       set path [file dir [lindex $v(labelNames) 0]]
     } elseif {$v(trans,name) == "" && $v(sig,name) != ""} {
       set path [file dir $v(sig,name)]
     } else {
       set path $v(trans,path)
     }
     if {[info tclversion] >= 8.4} {
       set names [tk_getOpenFile -filetypes $types -initialdir $path \
		     -multiple 1 -title [Local "Open segmentation file"]]
     } else {
       set names [list [tk_getOpenFile -filetypes $types -initialdir $path \
			   -title [Local "Open segmentation file"]]]
     }
   }
   foreach name $names {
      if {![file readable $name]} continue
      # Look for a segmentation format matching the file
      set format [LookForLabelFormat $name]
      if {$format == ""} {
	 error [format [Local "Unknown format for file %s"] $name]
      }
      # Choose uique segmentation id
      set i 1
      set seg lbl$i
      if {[info command ${format}::readSegmtSet] != ""} {
	set result [${format}::readSegmtSet [ReadFile $name]]
      } else {
	set result [list [list [${format}::readSegmt [ReadFile $name]]]]
      }
      foreach set $result {
	foreach {segments entryname view color} $set break
	if {$view == ""} {
	  set view 1
	}
	if {$color == ""} {
	  set color white
	}
	while {[info exists v(trans,$seg)]} {
	  set seg lbl[incr i]
	}
	set v(trans,$seg) $segments
	foreach wavfm $v(wavfm,list) {
	  set v(view,[winfo parent $wavfm].$seg) $view
	  CreateSegmentWidget $wavfm $seg "[file tail $name] $entryname" -full $color
	}
      }
      lappend v(labelNames) $name
   }
}

# Create a transcription from a segmentation
proc SegmtToTrans {segmt} {
   global v

   # Newly created transcription must follow the DTD
   ::xml::dtd::xml_read $v(file,dtd)

   if {$v(sig,name) != ""} {
      set t0 $v(sig,min)
      set t2 $v(sig,max)
   } else {
      set t0 [lindex [lindex $segmt 0] 0]
      set t2 [lindex [lindex $segmt end] 1]
   }
   set v(trans,root) [::xml::element "Trans"]
   set id0 [::xml::element "Episode" {} -in $v(trans,root)]
   set id1 [::xml::element "Section" [list "type" "report" "startTime" $t0 "endTime" $t2] -in $id0]
   set id2 [::xml::element "Turn" [list "startTime" $t0 "endTime" $t2] -in $id1]
   foreach s $segmt {
      set t1 [lindex $s 0]
      if {$t0 < $t1} {
	 ::xml::element "Sync" [list "time" $t0] -in $id2
	 ::xml::data "" -in $id2
      }
      ::xml::element "Sync" [list "time" $t1] -in $id2
      ::xml::data [lindex $s 2] -in $id2
      set t0 [lindex $s 1]
   }
   if {$t0 < $t2} {
      ::xml::element "Sync" [list "time" $t0] -in $id2
      ::xml::data "" -in $id2
   }
}

################################################################
# Read transcriptions

# Read transcription file in several formats
# Called from: OpenTrans(OrSound)File, RevertTrans, StartWith
proc ReadTrans {name {soundFile ""} {multiwav {}}} {
   global v
   
   # First, try to rescue from last autosaved file if it exists.
   AutoRescue $name

   set format "trs"
   foreach ns [namespace children convert] {
      if {[info command ${ns}::guess] != "" && [${ns}::guess $name]} {
	 set format $ns
	 break
      }
   }
   #puts "format $format"

   DisplayMessage [Local "Cleaning up memory..."]; update
   CloseTrans -nosave
   EmptyVideo

   # Try to open associated sound file as early as possible for non-xml files
   if {$format !="trs"} {
      LookForSignal $name $soundFile
   }

   DisplayMessage [Local "Reading transcription file..."]; update
   if {[info command ${format}::import] != ""} {
      ${format}::import $name
   } elseif {[info command ${format}::readSegmt] != ""} {
      SegmtToTrans [${format}::readSegmt [ReadFile $name]]
   } else {
      error "Can't import from [set ${format}::msg]"
   }

   if {[namespace tail $format] == "cha"} {
     setChatMode 1
   } else {
     setChatMode 0
   }

   set v(trans,name) $name
   UpdateShortName
   set v(trans,format) $format
   set v(trans,saved) 0
   set v(trans,path) [file dirname $name]
   if {$v(importTopics)} {
     ::topic::import $v(topicFile) 0
   }
   if {$v(importSpeakers)} {
     ::speaker::import $v(speakerFile) 0
   }
   InitModif
   GetVersion
   if {[set msg [NormalizeTrans]] != ""} {
     tk_messageBox -message $msg -title [Local "File format checking"] -type ok -icon error
     puts stderr $msg
   }
   DisplayTrans
   TraceOpen

   # Try to open automatically sound file else ask user
   if {$format == "trs"} {
      LookForSignal $name $soundFile [lindex [GetFilename] 0]
   } else {
      # For newly created transcriptions, keep info about signal basename
      UpdateFilename
   }
   if {$v(sig,name) == ""} {
      set rep [tk_messageBox -type okcancel -icon warning -message \
	  [concat [Local "Please open signal for transcription"] $name]]
      if {$rep == "ok"} {
	OpenAudioFile
      }
      if {$v(sig,name) == ""} {
	 EmptySignal
      }
   }
   # add list of sound files found in .trs header
   if {$format == "trs"} {
     MW_Update
   }
   # also add multiple wav files from command line or configuration
   if {[llength $multiwav] > 1} {
     eval MW_AddFile $multiwav
     UpdateFilename
   }
}

proc setChatMode {newMode} {
  global v

  set oldMode $v(chatMode)
  set v(chatMode) $newMode
  if {$v(chatMode) != $oldMode} {
    InitMenus
  }
}

# Open transcription file through selection box
proc OpenTransFile {} {
   global v

   if [catch {SaveIfNeeded} err] return
   set types [subst {
      {"Transcription"   {$v(ext,trs)}}
      {"Label file"   {$v(ext,lbl)}}
   }]
   eval lappend types $v(newtypes) {{"All files"   {*}}}
   set name [tk_getOpenFile -filetypes $types -initialdir $v(trans,path) \
		 -title [Local "Open transcription file"]]
   if {$name != ""} {
      if {[catch {
	 ReadTrans $name
      } error]} {
	 tk_messageBox -message $error -type ok -icon error
	 NewTrans $v(sig,name)
	 return
      }
   }
}

# Open transcription or sound file through selection box at startup
proc OpenTransOrSoundFile {} {
   global v

   set types [subst {
      {"All files"   {*}}
      {"Transcription"   {$v(ext,trs) $v(ext,lbl)}}
      {"Audio files" {$v(ext,snd)}}
   }]
   set name [tk_getOpenFile -filetypes $types -initialdir $v(trans,path) \
		 -title [Local "Open transcription or audio file"]]
   if {$name != ""} {
      if {[catch {
	 set ext [file extension $name]
	 if {[lsearch -exact [lindex [lindex $types 1] 1] $ext] >= 0} {
	    ReadTrans $name
	 } elseif {[lsearch -exact [lindex [lindex $types 2] 1] $ext] >= 0
		   || [SoundFileType $name] != "RAW"} {
	    NewTrans $name
	 } else {
	    tk_messageBox -message "Type of $name unknown" -type ok -icon error
	    NewTrans "<empty>"
	 }
      } error]} {
	 tk_messageBox -message "$error" -type ok -icon error
      } else {
	 return
      }
   }
   NewTrans "<empty>"
}

################################################################
# Write transcriptions

# Write transcription to the file in specified format; returns chosen format.
proc WriteTrans {name format} {
   global v

   set ext [string trimright [string tolower [file extension $name]] "\#"]
   # Try to guess format from extension if not given - unused feature
#    if {$format == ""} {
#       foreach format [concat [namespace children convert] "trs"] {
# 	 if {[info exists ${format}::ext]
# 	     && [lsearch [set ${format}::ext] $ext] >= 0} {
# 	    break
# 	 }
#       }
#    }
   if {[lsearch [set ${format}::ext] $ext] < 0} {
      if {[tk_messageBox -type yesno -icon question -message [format [Local "%s is not a standard extension for %s. Continue?"] $ext [set ${format}::msg]]] != "yes"} {
	 error "" 
      }
   }
   if {[info command ${format}::export] != ""} {
      ${format}::export $name
   } else {
      error [format [Local "unsupported output format %s"] [namespace tail $format]]
   }
   DisplayMessage [format [Local "Transcription %s saved."] $name]
   return $format
}

################################################################
# Open and save transcriptions (user-level)

# Create new transcription. 
# If audio file not given, ask through dialog box.
proc NewTrans {{soundFile ""} {multiwav {}}} {
   global v

   if [catch {CloseTrans} err] return
   EmptyVideo

   if {[catch {
      if {$soundFile == "<empty>"} {
	 EmptySignal
      } elseif {$soundFile != "" 
		&& ([file readable $soundFile] || $v(sig,remote))} {
	 Signal $soundFile
      } else {
	 OpenAudioFile
      }
   }]} {
      if {$v(debug)} {puts $::errorInfo}
      EmptySignal
   }

   # add multiple wav files from command line
   eval MW_AddFile $multiwav

   setChatMode 0
   set v(trans,name) ""
   UpdateShortName
   set v(trans,format) "trs"
   set v(trans,saved) 0
   SegmtToTrans [list [list $v(sig,min) $v(sig,max) ""]]
   InitEpisode
   if {$v(importTopics)} {
     ::topic::import $v(topicFile) 0
   }
   if {$v(importSpeakers)} {
     ::speaker::import $v(speakerFile) 0
   }
   InitModif
   DisplayTrans
   TraceOpen
}

# Save [as] 
#  returns empty string if save failed (or was canceled)
proc SaveTrans {{as ""} {format ""}} {
   global v

   if {[GetSegmtNb seg0] <= 0} return
   if {$format == ""} {
      set format "trs"
   }
   if {$v(trans,name) != "" && $as == "" && $v(trans,format) == $format} {
      set name $v(trans,name) 
   } else {
      if {$v(trans,name) == ""} {
	# default base name is first one from list given in episode tag
	set base [lindex [GetFilename] 0]
      } else {
	set base [file root [file tail $v(trans,name)]]
      }
      set exts [set ${format}::ext]
      set ext [lindex $exts 0]
      set types [list [list [set ${format}::msg] $exts]]
      lappend types {"All files"   {*}}

      set name [tk_getSaveFile -filetypes $types -defaultextension $ext \
		    -initialfile $base$ext -initialdir $v(trans,path) \
		    -title  "Save transcription file $as"]
      if {$name != "" && [file extension $name] == ""} {
	 append name $ext
      }
   }
   if {$name != ""} {
      if {[file exists $name] && $v(backup,ext) != "" 
	  && ($v(trans,name) == "" || $as != "" || !$v(trans,saved))} {
	 file copy -force -- $name "$name$v(backup,ext)"
      }
      if {[HasModifs]} {
	 UpdateVersion
      }
      if [catch {
	 WriteTrans $name $format
      } res] {
	 tk_messageBox -message [format [Local "%s not saved !!"] $name] -type ok -icon error
	 return "" 
      } else {
	  tk_messageBox -message [format [Local "%s saved !!"] $name] -type ok -icon info 
      }
      if {$format == "trs"} {
	 set v(trans,name) $name
	 UpdateShortName
	 set v(trans,format) $res
	 set v(trans,saved) 1
	 set v(trans,path) [file dirname $name]
	 InitModif
      }
   }
   return $name
}

proc SaveIfNeeded {} {
   global v

   if {[HasModifs]} {
      set answer [tk_messageBox -message [Local "Transcription has been modified - Save before closing?"] -type yesnocancel -icon question]
      switch $answer {
	 cancel { return -code error cancel }
	 yes    { if {[SaveTrans]==""} {return -code error cancel} }
	 no     { }
      }
   }
}

proc RevertTrans {} {
   global v

   if {$v(trans,name) != "" && [HasModifs]} {
      set answer [tk_messageBox -message [Local "Warning !\nAll changes will be lost.\nReally revert from file ?"] -type okcancel -icon warning]
      if {$answer == "ok"} {
	 InitModif
	 ReadTrans $v(trans,name) $v(sig,name)
      }
   }
}

# called from: NewTrans, ReadTrans, CloseAndDestroyTrans
proc CloseTrans {{option save}} {
   global v

   if {$option=="save"} {
      SaveIfNeeded
   }
   TraceClose
   EmptyTextFrame
   ::xml::init
   set v(trans,root) ""
   ::speaker::init
   ::topic::init
   InitSegmt seg0 seg1 seg2 bg
   DestroyLabels
   set v(trans,name) ""
   UpdateShortName
   InitModif
}

proc CloseAndDestroyTrans {} {
   global v

   if [catch {
      CloseTrans
   } err] {
      return -code return 
   }
   DestroyTextFrame
   DestroySegmentWidgets
}

################################################################

proc TransInfo {} {
   global v

   return [list [GetSegmtNb seg2] [llength [::topic::all_names]] [GetSegmtNb seg1] [llength [::speaker::all_names]] [GetSegmtNb seg0] [CountWordSegmt seg0]]
}

################################################################

# Normalize the transcription by "filling the holes" with sections or turns,
# check wrong boundary order
# and creates empty data sections between non-contiguous breakpoints

proc NormalizeTrans {} {
   global v
   set msg ""

   if {![info exist v(trans,root)] || $v(trans,root)==""} return
   DisplayMessage [Local "Checking temporal consistency..."]; update

   set episode [$v(trans,root) getChilds "element" "Episode"]

   # Contrain sections to be a partition of the episode
   #if {[namespace tail $v(trans,format)] != "hub4e"}
   if {1} {
     set t1 $v(sig,min)
     foreach sec [$episode getChilds "element" "Section"] {
       set t2 [$sec getAttr "startTime"]
       if {$t2 < $t1} {
	 $sec setAttr "startTime" $t1
	 append msg "shifted start time of overlapping section $t2 -> $t1\n"
       } elseif {$t2 > $t1} {
	 ::xml::element "Section" [list "type" "nontrans" "startTime" $t1 "endTime" $t2] -before $sec
	 #append msg "inserted new section between $t1-$t2\n"
       }
       set t1 [$sec getAttr "endTime"]
       # detect inconsistency in sections
       if {$t1 <= $t2} {
	 append msg "WARNING - section interval inconsistency $t2-$t1\n"
       }
     }
     # Don't add a new section up to the end, because we will synchronize
     # the last breakpoint to the end of signal - else it would be done with:
     #set t2 $v(sig,max)
     #if {$t2 > $t1} {
     #   ::xml::element "Section" [list "type" "nontrans" "startTime" $t1 "endTime" $t2] -in $episode
     #}
   }

   foreach sec [$episode getChilds "element" "Section"] {
     # Constrain turns to be a partition of each section
     if {1} {
	set t1 [$sec getAttr "startTime"]
	foreach turn [$sec getChilds "element" "Turn"] {
	  set t2 [$turn getAttr "startTime"]
	  if {$t2 < $t1} {
	    $turn setAttr "startTime" $t1
	    append msg "shifted start time of overlapping turn $t2 -> $t1\n"
	  } elseif {$t2 > $t1} {
	    ::xml::element "Turn" [list "startTime" $t1 "endTime" $t2] \
		-before $turn
	    #append msg "inserted new turn between $t1-$t2\n"
	  }
	  set t1 [$turn getAttr "endTime"]
	  # detect inconsistency in turns
	  if {$t1 <= $t2} {
	    append msg "WARNING - turn interval inconsistency $t2-$t1\n"
	  }
	}
	set t2 [$sec getAttr "endTime"]
	if {$t2 < $t1} {
	  $turn setAttr "endTime" $t2
	  append msg "shifted end time of overlapping turn $t1 -> $t2\n"
	} elseif {$t2 > $t1} {
	  ::xml::element "Turn" [list "startTime" $t1 "endTime" $t2] -in $sec
	  #append msg "inserted new turn between $t1-$t2\n"
	}
      }

      foreach turn [$sec getChilds "element" "Turn"] {
	 set t1 [$turn getAttr "startTime"]
	 # Each turn must begin with a sync
	 set sync [lindex [$turn getChilds "element" "Sync"] 0]
	 if {$sync == "" || [$sync getAttr "time"] > $t1} {
	    ::xml::element "Sync" [list "time" $t1] -begin $turn
	 }
	 if {$sync != "" && [$sync getAttr "time"] < $t1} {
	   append msg "shifted synchro [$sync getAttr time] -> $t1\n"
	   $sync setAttr "time" $t1
	 }
	 # Create data between non-contiguous breakpoints
	 foreach elem [$turn getChilds "element"] {
	    set next [$elem getBrother "element"]
	    if {$next == ""} {
	       set t2 [$turn getAttr "endTime"]
	    } else {
	       set t2 ""
	       catch {
		  set t2 [$next getAttr "time"]
	       }
	    }
	    if {$t1 == "" || $t2 == "" || $t2 > $t1} {
	       set data [$elem getBrother]
	       if {$data == "" || 
		   ([$data class] != "data" &&
		    !([$data class] == "element"  && [$data getType] == "Who"
		      && [$data getAttr "nb"] == 1))} {
		     ::xml::data "" -after $elem
	       }
	    } else {
	      if {$t2 < $t1} {
		# detect inconsistency in times
		append msg "WARNING - element time inconsistency at $t2\n"
	      }
	    }
	    set t1 $t2
	 }
	 # Convert data [...] to XML tags for .typ and old .xml format
	 if {[namespace tail $v(trans,format)] == "typ"
	     || $v(convert_events)} {
	    foreach data [$turn getChilds "data"] {
	       ConvertData $data
	    }
	 }
      }
   }
   return $msg
}

################################################################

# Try to guess Events from strings in .typ - very rough anyway.
proc ConvertData {data} {
   set text [$data getData]
   if {[regexp ".*SPEAKER1: ?(.*) SPEAKER2: ?(.*)" $text all t1 t2]} {
      set text "\[1]$t1\[2]$t2"
   }
   while {[regexp "^(\[^\\\[]*)\\\[(\[^]]+)](.*)$" $text all t1 evt text]} {
      $data setData $t1
      switch -regexp -- $evt {
	 ^(1|2)$ {
	    set elem [::xml::element "Who" [list "nb" $evt] -after $data]
	 }
	 ^-?(r|i|e|n|pf|bb|bg|tx|rire|sif|ch|b|conv|pap|shh|mic|jingle|musique|indicatif|top|pi|pif|nontrans)-?$ {
	    set extn "instantaneous"
	    # For backward compability: [noise-] ... [-noise] 
	    if {[regexp "^(-)?(.*\[^-])(-)?$" $evt all start evt end]} {
	       if {$start != ""} {
		  set extn "end"
	       } elseif {$end != ""} {
		  set extn "begin"
	       }
	    }
	    set elem [::xml::element "Event" \
			  [list "desc" $evt "extent" $extn] -after $data]
	 }
	 default {
	    set elem [::xml::element "Comment" [list "desc" $evt] -after $data]
	 }
      }
      set data [::xml::data $text -after $elem]
   }
}

################################################################

# Display a (previously normalized) transcription.
# Process sequentially time markers of the transcription and
# register a unique shared time for each different value.
# Create a segmentation at section, speaker and synchro level.

proc DisplayTrans {} {
   global v
   variable ::Synchro::time

   if {![info exist v(trans,root)] || $v(trans,root)==""} return
   set episode [$v(trans,root) getChilds "element" "Episode"]

   DisplayMessage [Local "Displaying transcription..."]; update

   # Init
   set min $v(sig,min)
   set max $v(sig,max)
   InitSegmt seg0 seg1 seg2 bg
   Synchro::InitTime
   InitEditor
   update

   set t0 [Synchro::NewTime $min]; set t6 $t0; set t5 $t0; set tprev $t0
   set bgTim $t0; set bgTxt ""; set bgId ""

   if {$v(chatMode)} {
     InsertEpisodeButton $episode
   }
   foreach sec [$episode getChilds "element" "Section"] {
      set t1 [Synchro::NextTimeTag $sec "startTime"]
      # Editor button
      if {!$v(chatMode)} {
	InsertSectionButton $sec
      }

      # register new section segment
      set t6 [Synchro::NextTimeTag $sec "endTime"]
      set top [::section::short_name $sec] 
      AddSegmt seg2 $t1 $t6 $top $sec

      set turns [$sec getChilds "element" "Turn"] 
      foreach tur $turns {
	 set t2 [Synchro::NextTimeTag $tur "startTime"]

	 # Editor button
	 InsertTurnButton $tur
	 
	 # register new turn segment
	 set t5 [Synchro::NextTimeTag $tur "endTime"]
	 set spk [::turn::get_name $tur]
	 AddSegmt seg1 $t2 $t5 $spk $tur

	 set txt ""
	 set t3 $t2
	 foreach chn [$tur getChilds] {
	    switch [$chn class] {
	    "element" {
	       switch [$chn getType] {
	       "Sync" {
		  # register new synchro segment
		  set t4 [Synchro::NextTimeTag $chn "time"]
		  if {$time($t4)>$time($t3)} {
		     AddSegmt seg0 $t3 $t4 $txt $id
		     # Test overlap with previous turn for display
		     if {$time($tprev) > $time($t3)} {
			ChangeSyncButton $idprev over1
			ChangeSyncButton $id over2
		     }
		  }
		  set t3 $t4
		  set id $chn
		  set txt ""
		  InsertSyncButton $id
		  # update image for floating boundaries
		  if {[Synchro::getElastic $t3]} {
		    Synchro::updateSyncImage $t3
		  }
		  # for first Background breakpoint
		  if {$bgId == ""} {
		     set bgId $chn
		  }
	       }
	       "Background" {
		  set t4 [Synchro::NextTimeTag $chn "time"]
		  if {$time($t4) > $time($bgTim)} {
		     AddSegmt bg $bgTim $t4 $bgTxt $bgId
		  }
		  set bgTim $t4
		  set bgId $chn
		  foreach {bgTxt img} [ReadBackAttrib $chn] {}
		  InsertImage $chn $img
	       }
	       "Dependent" {
		   InsertDependent $chn
	       }
	       "Header" {
		   InsertHeader $chn
	       }
	       "Scope" {
		   InsertScope $chn
	       }
	       "Event" - "Comment" {
		  InsertEvent $chn
		  append txt [StringOfEvent $chn]
	       }
	       "Who" {
		  if {[$chn getAttr "nb"] > 1} {
		     # segment box is splitted vertically at form-feed
		     append txt "\f"
		  }
		  InsertWho $chn
	       }
	       default {
		 InsertOther $chn
		 append txt [StringOfOther $chn]
	       }
	       }
	    }
	    "data" {
	       append txt [$chn getData]
	       InsertData $chn
	    }
	    }
	 }
	 
	 # register last synchro segment
	 if {$time($t5)>$time($t3)} {
	    AddSegmt seg0 $t3 $t5 $txt $id
	    # Test overlap with previous turn for display
	    if {$time($tprev) > $time($t3)} {
	       ChangeSyncButton $idprev over1
	       ChangeSyncButton $id over2
	    }
	 }
	 # For overlapping speech
	 set idprev $id
	 set tprev $t5
      }
   }
   if {$time($t6) > $time($bgTim)} {
      AddSegmt bg $bgTim $t6 $bgTxt $bgId
   }
   #set t7 [Synchro::NewTime $max]

   # For demo purposes only
   if {[info exists v(demo)]} {
      DestroyTextFrame
      DestroySegmentWidgets
      CreateSegmentWidget .snd.w seg0 "Demo" -fg $v(color,fg-sync) -full $v(color,bg-sync) -height 1 -high $v(color,hi-sync)
      destroy .demo
      frame .demo -bd 2 -relief raised
      pack .demo -expand true -fill both -side top
      text .demo.txt -wrap word  -width 40 -height 15 \
	  -fg $v(color,fg-text) -bg $v(color,bg-text) \
	  -font {courier 24 bold} -yscrollcommand [list .demo.ysc set]
      scrollbar .demo.ysc -orient vertical -command [list .demo.txt yview]
      pack .demo.txt -side left -fill both -expand true
      pack .demo.ysc -side right -fill y
      bind .demo.txt <BackSpace> {.demo.txt delete 1.0 end}
      return
   }

   # Create widgets if necessary
   CreateAllSegmentWidgets
   # Only display requested ones
   UpdateSegmtView
   # Fancy colors if needed
   ColorizeSpk

   HomeEditor
   DisplayMessage ""
}

################################################################

# Construct text description associated with Sync tag
proc TextFromSync {bp} {
   set txt ""
   for {set tag [$bp getBrother]} {$tag != ""} {set tag [$tag getBrother]} {
      switch [$tag class] {
	 "data" {
	    append txt [$tag getData]
	 }
	 "element" {
	    switch [$tag getType] {
	       "Sync" {
		  break
	       }
	       "Background" {
		  #append txt " * "
	       }
	       "Who" {
		  set nb [$tag getAttr "nb"]
		  if {$nb > 1} {
		     # segment box is splitted vertically at form-feed
		     append txt "\f"
		  }
	       }
	       "Event" - "Comment" {
		  append txt [StringOfEvent $tag]
	       }
	       default {
		 append txt [StringOfOther $tag]
	       }
	    }
	 }
      }
   }
   return $txt
}

# Get BP from which depends current tag
proc SyncBefore {tag} {
   return [$tag getBrother "element" "Sync" -1]
}
