#!/bin/sh
#  -*-tcl-*-\
exec wish "$0" ${1:+"$@"}

# RCS: @(#) $Id$

# TRANSCRIBER - a free tool for segmenting, labeling and transcribing speech
# Copyright (C) 1998-2000, DGA

# WWW:          http://www.etca.fr/CTA/gip/Projets/Transcriber/Index.html
# Mailing list: transcriber@etca.fr
# Author:       Claude Barras, DGA/DCE/CTA/GIP
# Coordinators: Edouard Geoffrois, DGA/DCE/CTA/GIP
#               Mark Liberman & Zhibiao Wu, LDC

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with GNU Emacs; see the file COPYING.  If not, write to
# the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

################################################################

proc Main {argv} {
   global v

   wm title . "Transcriber 1.4.5"
   wm protocol . WM_DELETE_WINDOW { Quit }

   InitDefaults $argv
   LoadModules
   InitConvertors
   BuildGUI
   TraceInit
   StartWith $argv
}

proc Quit {} {
   global v

   if [catch {SaveIfNeeded}] return   

   if {$v(keepconfig)} {
      set answer [tk_messageBox \
		      -message [Local "Save configuration before leaving?"] \
		      -type yesnocancel -icon question]
      if {$answer == "yes"} {
	 SaveOptions
      }
      if {$answer == "cancel"} {
	 return
      }
   }
      
   # Suppress autosave file
   InitAutoSave
   # Update log file
   TraceQuit
   # Stop ongoing subprocesses
   ShapeAbort
   #exit
   destroy .
}

################################################################

# Global settings defaults

# Meaning of global variables $v(...) :
# -----------------------------------
#  autosave,name: name under which current transcription is auto-saved
#  autosave,next: flag on if autosave handler is registred
#  autosave,time: time before autosave after a modif (in minutes)/ 0:disabled
#  backup,ext:    extension for backup (default to ~)
#  bgPos,chosen:  chosen position for background selection
#  bindings:      pairs of key/inserted string
#  color,bg :     background color
#  color,bg-back: background color for background noise
#  color,bg-evnt: background color for events
#  color,bg-sect: background color for section
#  color,bg-sel:  background color for selected signal
#  color,bg-sync: background color for synchro
#  color,bg-text: background color for text
#  color,bg-turn: background color for turns
#  color,fg-back: foreground color for background noise
#  color,fg-evnt: foreground color for events
#  color,fg-sect: foreground color for section
#  color,fg-sync: foreground color for synchro
#  color,fg-text: foreground color for text
#  color,fg-turn: foreground color for turns
#  color,hi-sync: current synchro color
#  color,hi-text: current text color
#  convert_events:convert strings [i] to events for old .xml files
#  curs,event :   next event for cursor move
#  curs,fast :    callback for fast fwd/bwd auto repeat
#  curs,max :     maximal cursor position during play (end of signal or sel.)
#  curs,min :     start of play for repeat (begin of signal or selection)
#  curs,pos :     current position of cursor in signal
#  curs,start :   playback start time
#  debug :        flag for debug menu display
#  demo :         switch to demonstration mode
#  encoding :     if a different encoding is to be used
#  encodingList:  list of IANA encoding names/usual names
#  ext,lbl :      list of extensions for importable label files
#  ext,snd :      list of known extensions for sound files
#  ext,trs :      list of extensions for importable transcription files
#  file,default : default configuration file
#  file,dtd :     DTD file for transcriptions in XML format
#  file,local :   user localization file
#  file,user :    user configuration file
#  find,case :    case sensitiveness for find ("-nocase" or "")
#  find,direction:search direction for find ("-forward" or "-backward")
#  find,mode :    mode for find ("-exact" or "-regexp")
#  find,replace : replacement string
#  find,what :    string to look for
#  font,axis :    font used for axis
#  font,event :   font used for events
#  font,info :    font used for infos
#  font,list :    font used for fixed length lists
#  font,mesg :    font used for messages
#  font,text :    font used for text editor
#  font,trans :   font used for transcriptions in segments
#  geom,$w :      default geometry for window $w
#  glossary :     value/comment word pairs of user glossary
#  img,$name :    bitmap image
#  keepconfig :   ask to save configuration before leaving
#  lang :         language for menus ("fr" for french, default to english)
#  language :     list of pairs iso639-code/language-name for localization
#  multiwav,file: stores the current MultiWav menu file selection
#  multiwav,files:list of all the files in the MultiWav menu
#  multiwav,path: list of the full pathnames of the MultiWav menu files
#  newtypes :     list of supported import formats with description
#  options,file:  default file for user configuration
#  options,list:  values to be saved in user configuration
#  path,base :    base directory of Transcriber
#  path,doc :     directory for help files
#  path,etc :     path for default config values and DTD
#  path,image :   directory for GIF or bitmap images
#  path,shape :   default directory for centi-second sound shapes
#  path,sounds :  last directory used for sound files selection
#  path,tcl :     directory for Tcl scripts
#  play,after :   callback after sound playback is over
#  play,auto :    automatic play new selection or signal (1 or 0)
#  play,no-fast:  temporary inhibition of fast forward/backward
#  play,state :   currently playing or not
#  playbackBeep:  beep sound file
#  playbackBefore:go back before playing
#  playbackMode:  continuous/pause/beep/stop/loop playback mode
#  playbackPause: pause duration between segments
#  playbackSegmt: set if playing a single segment
#  playbackSpeed: speed playback factor (unsupported)
#  preferedPos:   cursor insertion pos in text editor (start/end of line)
#  proc,id :      id for numbering of socket connections to file server
#  scribe,name :  default transcriber's name
#  segmt,curr :   id of current segment
#  segmt,move :   id of segment whose boundary is currently being moved
#  sel,begin :    begin of selected area of signal
#  sel,end :      end of selected area of signal
#  sel,event :    next event for automatic extension of selection
#  sel,start :    position of initial click for selection
#  sel,text :     text describing selection limits
#  shape,bg :     request shape calculation in background
#  shape,cmd :    sound command containing shape of signal
#  shape,min :    minimal duration for shape request (else max for display)
#  shape,wanted : if user wants shape calculation
#  sig,base :     header size for raw files
#  sig,channels : channels for raw audio files
#  sig,cmd :      sound command for signal access
#  sig,desc :     variable containing signal description to be displayed
#  sig,gain :     scale tk widget for volume gain change
#  sig,header :   raw sound file header size
#  sig,len :      length of signal (in seconds)
#  sig,max :      = sig,min + sig,len
#  sig,min :      beginning of signal (should be 0)
#  sig,name :     file name of audio signal
#  sig,open :	  flag to see if an audio file has been opened
#  sig,port :     socket port for audio file server
#  sig,rate :     sound rate for raw audio files
#  sig,remote :   access to files through audio file server or not
#  sig,server :   audio file server
#  sig,shortname: short file name of audio signal
#  space,auto :   automatic space insertion
#  spell,* :      related to spell checker
#  tk,dontmove :  flag to freeze once the cursor update inside text widget
#  tk,edit :      text tk widget
#  tk,play :      button tk widget for play
#  tk,stop :      button tk widget for stop
#  tk,wavfm :     main waveform tk widget
#  trace,* :      related to performance monitoring
#  trans,desc :   description of transcription for info window
#  trans,format:  file format of the transcription
#  trans,list :   ordered list of tags for segments in text widget
#  trans,modif :  flag "transcription modified"
#  trans,name :   file name of transcription
#  trans,path:    default path for open/save transcription dialog boxes
#  trans,root :   id of transcription root tag
#  trans,saved:   flag if transcription has been saved at least once
#  trans,seg? :   list of transcription segments at level ?
#  type,chosen :  section type chosen in dialog or menu
#  undo,list :    infos for undo
#  undo,redo :    flag on if undo is in fact redo
#  var,msg :      variable for selection infos and other messages
#  view,$win :    flag for frame/window display
#  $wav,height :  height of waveform widget (in pixels)
#  $wav,left :    left position of window in signal (in sec)
#  $wav,resolution: initial resolution for signal
#  $wav,right :   = $wav,left + $wav,size
#  $wav,scale :   scrollbar tk widget for scale change
#  $wav,scroll :  scrollbar tk widget for horizontal move
#  $wav,size :    length of window
#  $wav,sync :    list of tk widgets to be synchronized
#  wavfm,list :   list of all waveform views
#  zoom,list :    infos for unzoom

proc InitDefaults {argv} {
   global v env

   catch {unset v}

   # Set paths relative to script path
   set v(path,tcl)   [file dir [info script]]
   set v(path,base)  [file dir $v(path,tcl)]
   set v(path,image) [file join $v(path,base) "img"]
   set v(path,doc)   [file join $v(path,base) "doc"]
   set v(path,etc)   [file join $v(path,base) "etc"]
   set v(file,dtd)   [file join $v(path,etc)  "trans-13.dtd"]

   # Read values from default configuration file
   set v(file,default) [file join $v(path,etc) "default.txt"]
   LoadOptions $v(file,default) 1
   # correct some default values for Mac OS X
   if {[info tclversion] >= 8.4 && [tk windowingsystem] == "aqua"} {
      set v(font,text)   {courier 14}
      set v(color,hi-text) "white"
      set v(color,bg-text) "#f0f0f0"
      set v(color,bg-evnt) "#f0f0f0"
   }

   # Override default values with user values
   # (default name for user configuration file can be 
   # overriden with environnement variable $TRANSCRIBER)
   if {[llength $argv] > 0} {
     for {set i 0} {$i < [llength $argv]} {incr i} {
       set val [lindex $argv $i]
       if { $val == "-cfg"} {
	 set v(file,user) [lindex $argv [incr i]]
	 break
       }
     }
   }
   if {![info exists v(file,user)] } {
     if {[info exists env(TRANSCRIBER)]} {
       set v(file,user) $env(TRANSCRIBER)
     } else {
       switch $::tcl_platform(platform) {
	 "windows" {
	   if {[info exists env(USERPROFILE)]} {
	     set v(file,user) [file join $env(USERPROFILE) $v(options,windows)]
	   } else {
	     set v(file,user) [file join $env(HOME) $v(options,windows)]
	   }
	 }
	 "unix" {
	   if {$::tcl_platform(os) == "Darwin"} {
	     set v(file,user) [file join $env(HOME) Library Preferences $v(options,macintosh)]
	     file mkdir [file dir $v(file,user)]
	   } else {
	     set v(file,user) [file join $env(HOME) $v(options,unix)]
	   }
	 }
       }
     }
   }
   LoadOptions $v(file,user)

   # Init user name
   if {$v(scribe,name)=="(unknown)"} {
      if {[info exists env(USER)] && $env(USER) != ""} {
         set v(scribe,name) $env(USER)
         catch {
            regexp "Name: (\[^\n]*)" [exec finger $env(USER)] all Name
            if {$Name != ""} {
               set v(scribe,name) $Name
            }
         }
      } elseif {[info exists ::tcl_platform(user)] && $::tcl_platform(user) != ""} {
         set v(scribe,name) $::tcl_platform(user)
      }
   }

   # Init beep file
   if {![file readable $v(playbackBeep)]} {
      set v(playbackBeep) [file join $v(path,etc) "beep.au"]
   }

   # Shape settings: disabled for Windows by default
   if {$v(shape,wanted) == -1} {
      if {$::tcl_platform(platform) == "windows"} {
	 set v(shape,wanted) 0
	 set v(shape,bg) 0
      } else {
	 set v(shape,wanted) 1
      }
   }

   # If shape path is not defined by user, look for a writable path
   if {$v(path,shape)==""} {
     if {$::tcl_platform(os) == "Darwin"} {
	 set v(path,shape) $env(HOME)/Library/Caches/Transcriber
	 file mkdir $v(path,shape)
     } else {
       set testpaths {}
       if {[info exists env(TMP)]} {
	 lappend testpaths $env(TMP)
       }
       if {[info exists env(TEMP)]} {
	 lappend testpaths $env(TEMP)
       }
       if {$::tcl_platform(platform) == "unix"} {
	 lappend testpaths "/var/lib/transcriber" "/var/lib/trans" "/var/tmp/trans" "/tmp/trans" "/var/tmp"
       }
       lappend testpaths "/tmp" "/temp"
       foreach path $testpaths {
	 if {[file isdir $path] && [file writable $path]} {
	   set v(path,shape) $path
	   break
	 }
       }
     }
     # We could pop-up a dialog box to the user and inform of the choice
   }

   # Localization file (local.txt kept for backward compatibility with modified files)
   LoadLocal [file join $v(path,etc) "local.txt"]
   LoadLocal [file join $v(path,etc) "local_$v(lang).txt"]
   LoadLocal [format $v(file,local) $v(lang)]
   # We could use env(LC_MESSAGES) and LANG for default value of v(lang)

   UpdateLangList
   UpdateDepList
   UpdateHeaderList
}

proc LoadConfiguration {} {
  global v env
   
  SaveIfNeeded
  set base [file dirname $v(file,user)]
  set types {
    { "configuration file" {.cfg}}
    { "All files" {*}}
  }   
  set fileName [tk_getOpenFile -filetypes $types -defaultextension .cfg -initialfile "$v(scribe,name)" -initialdir $base -title  "Load configuration file"]
  if {$fileName == ""} return
  CloseTrans
  LoadOptions $fileName 
  ChangedLocal
  set pos $v(curs,pos)
  set gain $v(sig,gain)
  if {$v(trans,name) != ""} {
    ReadTrans $v(trans,name) $v(sig,name) $v(multiwav,path)
  } elseif {$v(sig,name) != ""} {
    NewTrans $v(sig,name) $v(multiwav,path)
  }
  SetCursor $pos
  NewGain $gain
}
 
proc LoadOptions {fileName {keep 0}} {
   global v

   readEncoding $fileName
   catch {
      set f [open $fileName r]
      while {[gets $f oneline]>=0} {
	 append wholeline $oneline
	 if {![info complete $wholeline]} {
	    append wholeline "\n"
	    continue
	 }
	 set var [lindex $wholeline 0]
	 if {($var != "") && ([string index $var 0] != "\#")} {
	    set val [lindex $wholeline 1]
	    set v($var) $val
	    if {$keep} {
	       lappend v(options,list) $var $val
	    }
	 }
	 set wholeline ""
      }
      close $f
   }
   restoreEncoding
}

proc SaveOptions {{mode ""}} {
   global v

   if {$mode != "as"} {
      set fileName $v(file,user)
   } else {
     set base [file dirname $v(file,user)]
     set types {
       { "configuration file" {.cfg}}
       { "All files" {*}}
     }
     set fileName [tk_getSaveFile -filetypes $types -defaultextension .cfg -initialfile "$v(scribe,name)" -initialdir $base -title  "Save configuration file"]
   }
   # write options using default system encoding
   set f [open $fileName w]
   set v(geom,.) [wm geom .]
   puts $f "\# Options for Transcriber saved on [clock format [clock seconds]][writeEncoding]"
   set old ""
   foreach {var def} $v(options,list) {
      if {$v($var) != $def} {
	 puts $f [list $var $v($var)]
      } else {
	 append old [list $var $v($var)]\n
      }
   }
   # prepend all lines with comment char for default values
   regsub -all "\n" $old "\n\# " old
   puts $f "\n\# following options use default values\n\# $old"
   close $f

   # also save localization file - now rather done after edition
   # SaveLocal
}

################################################################

# Use encoding informations for reading/writing configuration
# and localization files

# switch system to encoding used for saving a file
# (necessary for sourcing a file, where fconfigure is not possible)
# need to call restoreEncoding after saving
proc readEncoding {fileName} {
  catch {
    if {![info exists ::defaultEncoding]} {
      set ::defaultEncoding [encoding system]
    }
    set f [open $fileName]
    set line [gets $f]
    close $f
    if {[regexp "encoding (\[^ \]+)" $line all enc]} {
      encoding system $enc
    }
  }
}

# switch system to chosen encoding for saving a file
# return a string message to put in the header of the file
# need to call restoreEncoding after writing if encoding not empty
proc writeEncoding {{enc ""}} {
  set msg ""
  catch {
    if {$enc != ""} {
      if {![info exists ::defaultEncoding]} {
	set ::defaultEncoding [encoding system]
      }
      encoding system $enc
    }
    set msg " with encoding [encoding system]"
  }
  return $msg
}

# restore default system encoding
proc restoreEncoding {} {
   catch {
     encoding system $::defaultEncoding
   }
}

################################################################

proc LoadLocal {fileName} {
  global v
  
  if {![file readable $fileName]} return
  readEncoding $fileName
  catch {
    uplevel \#0 [list source $fileName]
  }
  restoreEncoding
}

proc EditLocal {{only_empty 0}} {
   global v
   if {$v(lang) != "en"} {
      upvar \#0 local_$v(lang) local
      if {![catch {
	 foreach nam [lsort -dictionary [array names local]] {
	    if {$only_empty && $local($nam) != ""} continue
	    lappend new [list $nam $local($nam)]
	 }
	 set new [ListEditor $new "Localization in $::iso639($v(lang))" \
		      {"Message" "Translation"}]
	 unset local
         array set local [join $new]
      }]} {
	 # Update menus if needed
	 ChangedLocal
	 # SaveLocal - formerly done within "Options / Save configuration"
	 if {$v(file,local) != "" && [set fileName [SaveLocal]] != ""} {
	   set m [format [Local "Modifications saved in the file %s"] $fileName]
	 } else {
	   set m [Local "To keep your modifications, please provide a valid localization file name, come back to this edition window and click OK. Save also the configuration for reusing this file automatically in a next session."]
	 }
	 tk_messageBox -type ok -icon warning -message $m
      }
   }
}

proc ChangedLocal {} {
   global v

   # try to read language-specific localization file if necessary
   if {![array exists local_$v(lang)]} {
     set fileName [format $v(file,local) $v(lang)]
     if {$fileName != $v(file,local) && [file readable $fileName]} {
       LoadLocal $fileName
     } else {
       LoadLocal [file join $v(path,etc) "local_$v(lang).txt"]
     }
   }
   SetBindings
   InitMenus
   UpdateLangList
   UpdateDepList
   UpdateHeaderList
}

# Save in user localization file
proc SaveLocal {} {
   global v

   if {$v(file,local) == ""} {
      return
   }
   set fileName [format $v(file,local) $v(lang)]
   if {$fileName == $v(file,local)} {
     set langs [info globals local_*]
   } else {
     if {[info globals local_$v(lang)] == {}} return
     set langs local_$v(lang)
   }
   if {[llength $langs] > 1} {
     # save localization file for multiple languages using UTF-8 encoding
     set enc [writeEncoding "utf-8"]
   } else {
     # save language specific localization file using default system encoding
     set enc [writeEncoding]
   }
   set f [open $fileName w]
   puts $f "\# Localization for Transcriber saved on [clock format [clock seconds]]$enc"
   foreach locvar $langs {
      puts $f "\narray set $locvar \{"
      foreach nam [lsort -dictionary [array names ::$locvar]] {
	 puts $f "[list $nam]\n\t[list [set ::${locvar}($nam)]]"
      }
      puts $f "\}\n"
   }
   close $f
   restoreEncoding
   return $fileName
}

# Usage: Local "Message in english"
# Returns : translation of the message in the language given in
#   the global variable v(lang) if it exists in the local_* array;
#   else the original message.

proc Local {message} {
   global v

   if {$v(lang) != "en"} {
     upvar \#0 local_$v(lang) local
     if {[catch {
       set translation $local($message)
       if {$translation != ""} {
	 set message $translation
       }
     }]} {
       # register undefined message for edition
       set local($message) ""
     }
   }
   return $message
}

# Called at startup, and when language list or localization language changes
proc UpdateLangList {} {
   global v

   # Sort language list in right order for given language
   set v(language) [lsort -index 1 -command CmpLocal $v(language)]

   # create array for iso639 language codes
   catch {unset ::iso639}
   array set ::iso639 [join $v(language)]
}

# Called at startup, and when language list or localization language changes
proc UpdateDepList {} {
   global v

   # Sort dependent list in right order for given dependent
   set v(dependent) [lsort -index 1 -command CmpLocal $v(dependent)]
}

proc UpdateHeaderList {} {
   global v

   # Sort header list in right order for given header
   set v(header) [lsort -index 1 -command CmpLocal $v(header)]
}

proc UpdateScopeList {} {
   global v

   # Sort header list in right order for given header
   set v(scope) [lsort -index 1 -command CmpLocal $v(scope)]
}

proc CmpLocal {str1 str2} {
   return [string compare [Local $str1] [Local $str2]]
}

################################################################

proc LoadModules {} {
   global v auto_path env

   pwd; # for Linux Debian 2.0 (else there was an error later with 'pwd')
   lappend auto_path [file dir $v(path,base)]
   # use the whole snack package for Windows rather than sound package
     # Snack 1.7 or 2.0 should both work
     set vsnack [package require snack]
     if {[package vcompare $vsnack 1.7] < 0} {
       error "Found Snack package version $vsnack; needs 1.7 or higher"
     }
     catch {
       # in Snack 1.7, snackSphere package was renamed snacksphere
       package require snacksphere
     }
     package require trans 1.5

   # Install html library
   if {[catch {
      package require html_library
   }]} {
      uplevel \#0 [list source [file join [file dir $v(path,base)] html_library-0.3 html_library.tcl]]
   }

   # Source tcl libraries at global level
   foreach module {
      About Debug Dialog Edit Episode Events Interface Menu Play Segmt
      Signal Speaker Spelling Synchro Topic Trans Undo Waveform Xml MultiWav
   } {
      if {$module == "Xml" && [info commands ::xml::init] != ""} continue
      uplevel \#0 [list source [file join $v(path,tcl) $module.tcl]]
   }

  # Take Tcl/Tk 8.4 text library name changes into account
  if {[info tclversion] >= 8.4} {
    foreach cmd {
      tkButtonInvoke
      tkEntryInsert
      tkTextInsert
      tkTextNextWord
      tkTextPrevPos
      tkTextSetCursor
    } {
      if {![llength [info commands $cmd]]} {
	tk::unsupported::ExposePrivateCommand $cmd
      }
    }
  }

}

################################################################

# Calibration of "clock clicks" (no more in use)
proc ClockCalibrate {{time 5.0}} {
   #DisplayMessage "Calibrating clock for $time seconds. Please wait..."
   update
   set clock0 [clock clicks]
   after [expr int(1000*$time)]
   set clock1  [clock clicks]
   set val [expr ($clock1-$clock0)/double($time)]
   #DisplayMessage "Calibration done ($val clicks per sec.)"
   return $val
}

# Convert time in second to printable string
# precision defaults to 2 digit for durations less than 60 seconds
proc Tim2Str {tim {digit 2}} {
   #set sec [expr int($tim)]
   foreach {sec rem} [split $tim .] {}
   if {$tim>3600} {
      set str [clock format $sec -format "%H:%M:%S" -gmt 1]
   } elseif {$tim>60} {
      set str [clock format $sec -format "%M:%S" -gmt 1]
   } else {
      set str $sec
      #set str [format "%.${digit}g sec" $tim]
   }
   if {$rem != ""} {
      append str [string range ".$rem" 0 $digit]
   }
   return $str
}

################################################################
# Miscellaneous

proc min {a b} { expr $a>$b ? $b : $a }
proc max {a b} { expr $a>$b ? $a : $b }

# Suppress first occurence of a value in a list
proc lsuppress {varName val} {
   upvar $varName list
   set i [lsearch -exact $list $val]
   if {$i >= 0} {
      set list [lreplace $list $i $i]
   }
}

# improved incr procedure
proc incr2 {varName {amount 1}} {
   upvar $varName var
   if {[info exists var]} {
      set var [expr $var + $amount]
   } else {
      set var $amount
   }
   return $var
}

# Set default value if variable is undefined
proc setdef {varName val} {
   upvar $varName var
   if {! [info exists var]} {
      set var $val
   }
   return $var
}

################################################################

# Open audio file and transcription from command line else from defaults
proc StartWith {argv} {
   global v

   # v(sig,open) set to "" if no opened signal
   set v(sig,open) "0"

   set sig ""
   set multiwav {}
   set trans ""
   set pos 0
   set gain 0
   if {[llength $argv] > 0} {
      set ext_tr [concat $v(ext,trs) $v(ext,lbl)]
      set ext_au $v(ext,snd)
      for {set i 0} {$i < [llength $argv]} {incr i} {
	 set val [lindex $argv $i]

	 switch -glob -- $val {
	    "-set" {
	      # set a global variable to a given value, overrinding configuration file
	      # (names with special chars e.g. "shape,wanted" need to be quoted at shell level)
	      # syntax: trans -set varname value ...
	      set varname [lindex $argv [incr i]]
	      set value [lindex $argv [incr i]]
	      set v(varname) $value
	    }
	    "-noshape" {
	       set v(shape,wanted) 0
	    }
	    "-debug" {set v(debug) 1}
	    "-demo" {set v(demo) 1}
	    "-patch" {
	       set path [lindex $argv [incr i]]
	       if {![file exists $path]} {
		  set path [file join $v(path,base) $path]
	       }
	       if {[file isdir $path]} {
		  set path [file join $path *.tcl]
	       }
	       foreach file [glob $path] {
		  uplevel \#0 [list source $file]
	       }
	    }
	    "-convertto" {
	      # convert a set of trs files to given format, if export filter available
	      # syntax: trans -convertto {stm|html|...} *.trs
	      # resulting files are stored in current directory
	      wm withdraw .
 	      update
	      set format [lindex $argv [incr i]]
	      if {[info command convert::${format}::export] == ""} {
		if {$format != ""} {
		  puts stderr "Conversion to format $format unsupported."
		}
		puts stderr "List of supported formats for exporting .trs files:"
		foreach format [namespace children convert] {
		  if {[info command ${format}::export] != ""} {
		    puts stderr "\t[namespace tail $format]"
		  }
		}
		exit
	      }
	      #CloseTrans -nosave 
	      set ext [lindex [set ::convert::${format}::ext] 0]
	      puts stderr "Converting .trs files to $format format ($ext):"
	      set nb 0
	      while {[set name [lindex $argv [incr i]]] != ""} {
		if {[lsearch -exact $::trs::ext [string tolower [file extension $name]]] < 0
		    || ![file readable $name]} {
		  puts stderr "(ignoring non .trs file name $name)"
		  continue
		}
		puts stderr "$name"
		if {[catch {
		  trs::import $name
		  set v(sig,min) 0
		  set v(trans,format) trans
		  NormalizeTrans
		  convert::${format}::export [file tail [file root $name]]$ext
		  incr nb
		} err]} {
		  puts stderr "error with $name: $err"
		}
		CloseTrans -nosave
	      }
	      puts stderr "$nb file(s) processed."
	      exit
	    }
 	    "-cfg" {
	      # The -cfg option is used and detailled in the InitDefault procedure
	      # but has to be declared here just to avoid any option problem.
	      # Increment "i" to avoid interpreting the configuration file as an argument  
	      incr i
 	    }
            "-psn*" { 
	      # id sent by Mac OS X
	    }
	    "-*" {
	       return -code error "unsupported command line option $val"
	    }
	    default {
	       # Audio and transcription given on command line
	      set ext [string tolower [file extension $val]]
	       if {[lsearch -exact $ext_tr $ext] >= 0} {
		  set trans $val
	       } elseif {[lsearch -exact $ext_au $ext] >= 0
			 || [SoundFileType $val] != "RAW"} {
		 if {$sig == ""} {
		   set sig $val
		 } else {
		   lappend multiwav $val
		 }
	       } else {
		  return -code error "unknown format for file $val"
	       }
	    }
	 }
      }
   }

   # Default values if none was given on command line
   if {$sig=="" && $trans == ""} {
      set sig $v(sig,name)
      set multiwav $v(multiwav,path)
      set trans $v(trans,name)
      set pos $v(curs,pos)
      set gain $v(sig,gain)
   }

   EmptySignal

   # Load trans and associated audio
   #set v(trans,path) [pwd]
   if {$::tcl_platform(os) == "Darwin"} {
     set v(trans,path)   [file dir [file dir [file dir $v(path,base)]]]
   } else {
     set v(trans,path)   [file join $v(path,base) "demo"]
   }
   if {$trans == "" || [catch {
      ReadTrans $trans $sig $multiwav
      SetCursor $pos
      NewGain $gain
   } error]} {
      if {$trans != ""} {
	 #global errorInfo; puts $errorInfo
	 #bgerror $error
	 tk_messageBox -message $error -type ok -icon error
      }
      if {$sig != ""} {
	 NewTrans $sig $multiwav
      } else {
	 OpenTransOrSoundFile
      }
   }
}

################################################################

# Let's go !
Main $argv
