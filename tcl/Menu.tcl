#!/bin/sh
#\
exec wish "$0" "$@"

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

#######################################################################
# Automatic creation of menus for Tcl/Tk 8.0 (generic functions)
#
# Syntax : create_menu description_list
#
# with description = list of {name type options [arguments]}
# and
#  - name = name of menu or item
#  - type options = command {command content}
#		    radio {variable [value]}
#		    check variable
#		    cascade {sub-items list}
#  - arguments = options for item configuration
#
# At first level, one should use only "cascade"
#

proc add_menu {m liste} {
   global Menu

   if ![winfo exists $m] {
      menu $m -tearoff 0
   }
   if ![info exists Menu(uid)] {
      set Menu(uid) 0
   }
      
   foreach item $liste {
      set name [Local [lindex $item 0]]
      if {[string length $name]==0} {
	 $m add separator
	 continue
      }
      set type ""
      set option ""
      set sequence ""
      foreach {cmd arg} [lrange $item 1 end] {
	 switch -glob -- $cmd {
	    cmd -
	    com* {
	       set type "command"
	       lappend option -command $arg
	    }
	    rad* {
	       set type "radio"
	       if {[llength $arg] > 1} {
		  foreach {var val} $arg break
		  lappend option -variable $var -value $val
	       } else {
		  lappend option -variable $arg
	       }
	    }
	    ch* {
	       set type "check"
	       lappend option -variable $arg
	    }
	    cas* {
	       set type "cascade"
	       if {![string compare $name [Local "Help"]]} {
		  set new_m $m.help
	       } else {
		  set new_m $m.item[incr Menu(uid)]
	       }
	       set Menu(menu,$name) $new_m
	       lappend option -menu [add_menu $new_m $arg]
	    }
            -acc {
               if {[info tclversion] < 8.4 || [tk windowingsystem] != "aqua"} {
                  lappend option $cmd $arg
               }
           }
	    -bind {
               if {![regsub -- {-([^-]*)$} $arg {-Key-\1} sequence]} {
                  set sequence "Key-$arg"
               }
               if {[info tclversion] >= 8.4 && [tk windowingsystem] == "aqua"} {
                  if {[regsub "C(trl)?-" $arg "Cmd-" arg] 
                  || [regsub "A(lt)?-" $arg "Alt-" arg]
                  || [regsub "S(hift)?-" $arg "Shift-" arg]} {
                     lappend option -accelerator [string toupper $arg]
                  }
                  foreach {short long} {
                     "C(trl)?-" "Command-"
                     "A(lt)?-" "Option-" 
                     "S(hft)?-" "Shift-"
                  } {
                     regsub $short $sequence $long sequence
                  }
               } else {
                  lappend option -accelerator $arg
                  foreach {short long} {
                     "C(trl)?-" "Control-"
                     "A-" "Alt-" 
                     "S(hft)?-" "Shift-"
                  } {
                     regsub $short $sequence $long sequence
                  }
               }
	    }
	    -* {
	       lappend option $cmd $arg	       
	    }
	    default {error "$name : Bad menu syntax $cmd $arg"}
	 }
      }
      eval {$m add $type -label $name} $option
      if {$sequence != ""} {
	 bind . <$sequence> [list invoke_from_bind $m [$m index last]]
	 bind . <$sequence> +break
      }
   }
   return $m
}

proc create_menu {liste} {
   global Menu
   catch {unset Menu}
   catch {destroy .menu}
   . configure -menu [add_menu .menu $liste]
}

proc append_menu {menu liste} {
   global Menu
   set menu [Local $menu]
   add_menu $Menu(menu,$menu) $liste
}

proc config_menu {menu args} {
   global Menu
   set menu [Local $menu]
   if [catch {set Menu(menu,$menu)} menu_id] {
      error "Unknown menu $menu"
   }
   eval $menu_id config $args
}


proc eval_menu {menu args} {
   global Menu
   set menu [Local $menu]
   if [catch {set Menu(menu,$menu)} menu_id] {
      error "Unknown menu $menu"
   }
   eval $menu_id $args
}

proc config_entry {menu item args} {
   global Menu
   set menu [Local $menu]
   set item [Local $item]
   if [catch {set Menu(menu,$menu)} menu_id] {
      error "Unknown menu $menu"
   }
   eval [list $menu_id entryconfig $item] $args
}

proc invoke_from_bind {menu_id item_id} {
   # just to be sure menu is in the right state, call post command
   set cmd [$menu_id cget -post]
   if {$cmd != ""} {
      eval $cmd
   }
   eval $menu_id invoke $item_id
}

proc bind_menu {sequence menu item} {
   global Menu
   set menu [Local $menu]
   set item [Local $item]
   if [catch {set Menu(menu,$menu)} menu_id] {
      error "Unknown menu $menu"
   }
   if [catch {$menu_id index $item} item_id] {
      error "Unknown item $item"
   }
   bind . $sequence "invoke_from_bind $menu_id $item_id; break"
   set sequence [string trim $sequence "<>"]
   regsub "Key(Press)?-" $sequence "" sequence
   regsub "Control-" $sequence "Ctrl-" sequence
   $menu_id entryconfigure $item_id -accelerator $sequence
}

#######################################################################

# Menus for Transcriber
proc InitMenus {} {
   global v

   # Global menu
   #{"Close"               -bind "Ctrl-w"  cmd {CloseAndDestroyTrans}}
   create_menu {
      {"File" -underline 0	cascade {
	 {"New trans"		-bind "Ctrl-n"	cmd {NewTrans}}
	 {"Open trans..." 	-bind "Ctrl-o"	cmd {OpenTransFile}}
	 {"Save"		-bind "Ctrl-s"	cmd {SaveTrans}}
	 {"Save as..."				cmd {SaveTrans as}}
	 {"Export"		cascade {}}
	 {""}
	 {"Revert"				cmd {RevertTrans}}
	 {""}
	 {"Informations"	cmd {CreateInfoFrame}}
	 {"Edit episode attributes..."	cmd {EditEpisode}}	
	 {""}
	 {"Open video file..." 			cmd {OpenVideoFile}}
	 {"Open audio file..." 	-bind "Ctrl-a"	cmd {OpenAudioFile}}
	 {"Synchronized audio files"		cascade {
	   {"Add audio file..." 	cmd {OpenAudioFile add}}
	   {""}
	 }}
	 {"Save audio selection as..."          cmd {SaveAudioSegment as}}
	 {""}
	 {"Open segmentation file..." 	cmd {OpenSegmt}}
	 {""}
	 {"Quit"		-bind "Ctrl-q"	cmd {Quit}}
      }}
      {"Edit" -underline 0	cascade {
	 {"Undo"	-bind "Ctrl-z"		cmd {Undo} -state disabled}
	 {""}
	 {"Cut"		-acc "Ctrl-x"		cmd { TextCmd Cut }}
	 {"Copy"	-acc "Ctrl-c"		cmd { TextCmd Copy }}
	 {"Paste"	-acc "Ctrl-v"		cmd { TextCmd Paste }}
	 {""}
	 {"Find/Replace"   	cmd {Find} -bind "Ctrl-f"}
	 {"Spell checking"   	cmd {SpellChecking}}
	 {"Glossary"		cmd {EditGlossary} -bind "Ctrl-k"}
	 {"Speakers"		cascade {
	     {"Find speaker"		cmd {::speaker::find}}	
	     {"Import from file..." 	cmd {::speaker::import}}
	     {"Remove unused speakers" 		cmd {::speaker::purge}}
	     {"Update global speakers database" 		cmd {::speaker::Maj_bdg}}
	     {""}
	     {"Automatic import from selected file"	check v(importSpeakers)}
	 }}
	 {"Topics"		cascade {
	    {"Find topic"		cmd {::topic::find}}	
	    {"Import from file..." 	cmd {::topic::import}}
	    {"Remove unused topics" 		cmd {::topic::purge}}
	    {""}
 	    {"Automatic import from selected file"	check v(importTopics)}
	 }}
	 {""}
	 {"Insert event..."		cascade {
	    {"Isolated noise"	cmd {CreateEvent "b" "noise" "instantaneous" 1}  -bind "Ctrl-d"}
	    {"Overlapping noise"	cmd {CreateAutoEvent "b" "noise" "previous" 1}}
	    {"Pronounce"		cmd {CreateAutoEvent "" "pronounce" "previous" 1} -bind "Alt-equal"}
	    {"Language"			cmd {CreateAutoEvent "en" "language" "previous" 1}}
	    {"Lexical"			cmd {CreateAutoEvent "" "lexical" "previous" 1}}
	    {"Comment"			cmd {CreateAutoEvent "" "comment"}}
	    {"Named Entities"                 cmd {CreateAutoEvent "" "entities"} -bind "Ctrl-e"} 
	 }}
      }}
      {"Signal" -underline 0	cascade {
	 {"Play/Pause"		cmd {PlayOrPause} -bind "Tab"}
	 {"Play segment"	cmd {PlayCurrentSegmt} -bind "Shift-Tab"}
	 {"Play next segment"	cmd {PlayNextSegmt} -bind "Ctrl-Return"}
	 {"Play around cursor"	cmd {PlayAround} -bind "Alt-space"}
	 {"Playback mode"		cascade {
	    {"Continuous playback"	radio {v(playbackMode) "continuous"}}
	    {"Pause at segment boundaries"	radio {v(playbackMode) "pause"}}
	    {"Beep at segment boundaries"	radio {v(playbackMode) "beep"}}
	    {"Stop before next segment boundary" radio {v(playbackMode) "next"}}
	    {"Stop at next segment boundary"	radio {v(playbackMode) "stop"}}
	    {"Loop on segment or selection after a pause" radio {v(playbackMode) "loop"}}
	 }}
 	 {"Stereo channel"		cascade {
	   {"Left"	radio {v(sig,map) "1 0 1 0"} -command {if {[IsPlaying]} {PauseAudio; Play}} -bind "Alt-6"}
	    {"Right"	radio {v(sig,map) "0 1 0 1"} -command {if {[IsPlaying]} {PauseAudio; Play}} -bind "Alt-7"}
	    {"Both"	radio {v(sig,map) "1 0 0 1"} -command {if {[IsPlaying]} {PauseAudio; Play}} -bind "Alt-8"}
	 }}
	 {""}
	 {"Go to..."		cascade {
	    {"Forward"		cmd {PlayForward +1} -bind "Alt-Right"}
	    {"Backward"		cmd {PlayForward -1} -bind "Alt-Left"}
	    {"Previous"		cmd {MoveNextSegmt -1} -bind "Alt-Up"}
	    {"Next"		cmd {MoveNextSegmt +1} -bind "Alt-Down"} 
	    {""}
	    {"Position"		cmd {EditCursor}} 
	 }}
	 {""}
	 {"Resolution"		cascade {
	    {"1 sec"	cmd {Resolution 1} -bind "Alt-1"}
	    {"10 sec"	cmd {Resolution 10} -bind "Alt-2"}
	    {"30 sec"	cmd {Resolution 30} -bind "Alt-3"}
	    {"1 mn"	cmd {Resolution 60} -bind "Alt-4"}
	    {"5 mn"	cmd {Resolution 300} -bind "Alt-5"}
	    {""}
	    {"up"	cmd {ZoomReso -1} -bind "Alt-9"}
	    {"down"	cmd {ZoomReso +1} -bind "Alt-0"}
	    {""}
	    {"View all"		cmd {ViewAll} -bind "Alt-a"}
	 }}
	 {"Zoom selection"	cmd {ZoomSelection} -state disabled -bind "Alt-z"}
	 {"Unzoom selection"	cmd {UnZoom} -state disabled  -bind "Alt-u"}
	 {""}
	 {"Control panel"	cmd {CreateGainFrame}}
      }}
      {"Segmentation" -underline 2	cascade {
	 {"Move to..."	cascade {
	    {"Next synchro"	cmd {TextNextSync +1} -acc "Down"}
	    {"Previous synchro"	cmd {TextNextSync -1} -acc "Up"}
	    {"First segment"	cmd {TextFirstSync} -acc "Ctrl-Home"}
	    {"Last segment"	cmd {TextLastSync} -acc "Ctrl-End"}
	    {""}
	    {"Next turn"	cmd {TextNextTurn +1} -acc "Ctrl-Down"}
	    {"Previous turn"	cmd {TextNextTurn -1} -acc "Ctrl-Up"}
	    {""}
	    {"Next section"	cmd {TextNextSection +1} -acc "Page Down"}
	    {"Previous section"	cmd {TextNextSection -1} -acc "Page Up"}
	 }}
	 {""}
	 {"Insert breakpoint"	cmd {InsertSegment} -bind "Return"}
	 {"Insert background"	cmd {CreateBackground}}
	 {""}
	 {"Create turn..."	cmd {ChangeSegType Turn} -bind "Ctrl-t"}
	 {"Create section..."	cmd {ChangeSegType Section} -bind "Ctrl-r"}
	 {"Edit turn attributes..."	cmd {::turn::edit} -bind "Ctrl-Alt-t"}	
	 {"Edit section attributes..."	cmd {::section::edit}}	
	 {""}
	 {"Move breakpoint"   cmd { tk_messageBox -type ok -message "Just click on the segment boundary with central button (or control-click with left button) and drag it to the new position! Use shift modifier for a forced move."}}
	 {"Delete breakpoint"   cmd { DeleteSegment } -bind "Shift-BackSpace"}
      }}
      {"Options" -underline 0	cascade {
	 {"General..."		cmd {ConfigureGeneral}}
	 {"Audio file..."	cmd {ConfigureAudioFile}}
	 {"Events"	cascade {
	    {"Events display..."	cmd {ConfigureEvents}}
	    {"Edit noise list..."	cmd {ConfEventName "noise" "Noise"}}
	    {"Edit pronounce list..."	cmd {ConfEventName "pronounce" "Pronounce"}}
	    {"Edit lexical list..."	cmd {ConfEventName "lexical" "Lexical"}}
	    {"Edit language list..."	cmd {ConfEventName "language" "Language"}}
	    {"Edit named entities list..."	cmd {ConfEventName "entities" "Named Entities"}} 
	 }}
	 {"Display" -underline 0	cascade {
	    {"Text editor"	check v(view,.edit) -command {SwitchTextFrame} -bind "F2"}
	    {"NE buttons"  check v(view,.edit.ne) -command {SwitchNEFrame .edit.ne} -bind "F3"}
	    {"Command buttons"	check v(view,.cmd) -command {SwitchFrame .cmd  -after .edit} -bind "F4"}
	    {"First signal view"	check v(view,.snd) -command {SwitchFrame .snd} -bind "F5"} 
	    {"Second signal view"	check v(view,.snd2) -command {SwitchFrame .snd2} -bind "F6"}
	    {"Messages"  check v(view,.msg) -command {SwitchFrame .msg -side bottom} -bind "F7"}
	    {"Smart segmentation display"	check v(hideLevels) -command {UpdateSegmtView}}
	    {"Colorize speaker segments"	check v(colorizeSpk) -command {ColorizeSpk}}
	 }}
	 {"Fonts"	cascade {
	    {"Text"		cmd {set v(font,text)  [ChooseFont text] }}
	    {"Events"		cmd {set v(font,event) [ChooseFont event] }}
	    {"Segmentation"	cmd {set v(font,trans) [ChooseFont trans]}}
	    {"Information"	cmd {set v(font,info)  [ChooseFont info] }}
	    {"Messages"		cmd {set v(font,mesg)  [ChooseFont mesg] }}
	    {"Lists"		cmd {set v(font,list)  [ChooseFont list] }}
	    {"Axis"		cmd {set v(font,axis)  [ChooseFont axis] }}
	    {"NE buttons"      cmd {set v(font,NEbutton) [ChooseFont NEbutton];UpdateNEFrame .edit.ne }} 
	 }}
	 {"Colors..."		cmd {ConfigureColors}}
	 {"Bindings..."		cmd {ConfigureBindings}}
	 {""}
 	 {"Load configuration file..."	cmd {LoadConfiguration}}
	 {"Save configuration"		cmd {SaveOptions}}
 	 {"Save configuration as..."	cmd {SaveOptions as}}
      }}
      {"Help" -underline 0 cascade {
	 {"About..."		cmd {ViewHelp "Index"} -bind "F1"}
	 {""}
	 {"Presentation"	cmd {ViewHelp "Presentation"}}
	 {"Main features"	cmd {ViewHelp "Main features"}}
	 {"User guide"		cmd {ViewHelp "User guide"}}
	 {"Reference manual"	cmd {ViewHelp "Reference manual"}}
      }}
   }

   config_menu "File" -postcommand UpdateFileMenu
   config_menu "Edit" -postcommand UpdateEditMenu
   config_menu "Segmentation" -postcommand UpdateSegmentationMenu

   if {$v(debug)} {
      if {[info tclversion] >= 8.4 && [tk windowingsystem] == "aqua"} {
	 append_menu "Help" {
	    {""}
	    {"Update"		cmd {LoadModules}}
            {"Refresh"		cmd {Refresh}}
            {"Expert mode"	cmd {console show}}
         }
      } else {
	 append_menu "Help" {
	    {""}
	    {"Debug"		cascade {
	      {"Update"		cmd {LoadModules}}
	      {"Refresh"	cmd {Refresh}}
	      {"Expert mode"	cmd {CreateDebug}}
	    }}
	 }
      }
   }
   if {$v(chatMode)} {
     append_menu "Edit" {
	 {"Insert Dependent"    cmd {InsertDependent } -bind "Ctrl-p"}  
	 {"Insert Header"    cmd {InsertHeader } -bind "Ctrl-h"}  
	 {"Insert Scope"    cmd {InsertScope } -bind "Ctrl-i"}  
     }
   }
   UpdateConvertorMenu
}   

#######################################################################

# post command called by menus

proc UpdateFileMenu {} {
   global v

   if [info exists v(tk,edit)] {
      if {[HasModifs]} {
	 set state normal
      } else {
	 set state disabled
      }
      foreach type {"Save" "Revert"} {
	 config_entry "File" $type -state $state
      }
      foreach type {"Save as..."} {
	 config_entry "File" $type -state normal
      }
      
   } else {
      foreach type {"Save" "Save as..." "Revert"} {
	 config_entry "File" $type -state disabled
      }
   }

}

# set state for undo/cut/copy/paste menus
proc UpdateEditMenu {} {
   global v

   if [info exists v(tk,edit)] {
      # Undo has to be the first Edit menu line
      switch [HasUndo] {
	 0 { config_entry "Edit" 0 -label [Local "Undo"] -state disabled }
	 1 { config_entry "Edit" 0 -label [Local "Undo"] -state normal }
	 2 { config_entry "Edit" 0 -label [Local "Redo"] -state normal }
      }
      if [catch {$v(tk,edit) index sel.first}] {
	 set state disabled
      } else {
	 set state normal
      }
      foreach type {"Cut" "Copy"} {
	 config_entry "Edit" $type -state $state
      }
      foreach type {"Paste" } {
	 config_entry "Edit" $type -state normal
      }
   } else {
      foreach type {"Cut" "Copy" "Paste"} {
	 config_entry "Edit" $type -state disabled
      }
      config_entry "Edit" 0 -label [Local "Undo"] -state disabled 
   }
}

proc UpdateSegmentationMenu {} {
   global v

   if {[GetSegmtNb seg0] > 0} {
      set state normal
   } else {
      set state disabled
   }
   for {set i 0} {$i <= [eval_menu "Segmentation" index end]} {incr i} {
      catch {
	 config_entry "Segmentation" $i -state $state
      }
   }
}

