# RCS: @(#) $Id$

# multiwav extension - intended for meeting recordings management
# from an original proposal by David Gelbart and Dan Ellis from ICSI

# management of contextual menu
proc MW_AddMenuEntry {basename} {
  global v

  foreach wavfm $v(wavfm,list) {
    set menu [$v($wavfm,menu) entrycget [Local "Audio file"] -menu]
    $menu add radio -label $basename -variable v(multiwav,file) -command MW_Switch
  }
  eval_menu "Synchronized audio files" add radio -label $basename -variable v(multiwav,file) -command MW_Switch
}

proc MW_RemoveMenuEntry {{index "all"}} {
  global v

  foreach wavfm $v(wavfm,list) {
    set menu [$v($wavfm,menu) entrycget [Local "Audio file"] -menu]
    if {$index == "all"} {
      $menu delete 3 end
      $menu add separator
    } else {
      $menu delete [expr 3+$index]
    }
    #$menu configure -tearoff 1 
  }
  if {$index == "all"} {
    eval_menu "Synchronized audio files" delete 2 end
    eval_menu "Synchronized audio files" add separator
  } else {
    eval_menu "Synchronized audio files" delete [expr 2+$index]
  }
  eval_menu "Synchronized audio files" configure -tearoff 1 
}

# reset to empty list
proc MW_Reset {} {
  global v

  set v(multiwav,files) {}
  set v(multiwav,path) {}
  MW_RemoveMenuEntry
}

# add basenames found in transcription header
proc MW_Update {} {
  foreach basename [GetFilename] {
    MW_AddBase $basename
  }
}

# add given basename
proc MW_AddBase {basename} {
  global v

  if {[lsearch -exact $v(multiwav,files) $basename] < 0} {
    lappend v(multiwav,files) $basename
    lappend v(multiwav,path) {}
    MW_AddMenuEntry $basename
  }
}

#
proc MW_AddFile {args} {
  global v

  foreach filename $args {
    set basename [file root [file tail $filename]]
    if {$basename == ""} continue
    set pos [lsearch -exact $v(multiwav,files) $basename]
    if {$pos < 0 } {
      lappend v(multiwav,files) $basename
      lappend v(multiwav,path) $filename
      MW_AddMenuEntry $basename
    } else {
      set path [lindex $v(multiwav,path) $pos]
      if {$path == ""} {
	set v(multiwav,path) [lreplace $v(multiwav,path) $pos $pos $filename]
      }
    }
  }
  set v(multiwav,file) [file root [file tail $v(sig,name)]]
  # UpdateFilename need to be done later
}

proc MW_Switch {} {
  global v
  # look for basename chosen in v(multiwav,file)
  set pos [lsearch -exact $v(multiwav,files) $v(multiwav,file)]
  if { $pos >= 0 } {
    set file [lindex $v(multiwav,path) $pos]
    if {$file != ""} {
      Signal $file "switch"
    } else {
      LookForSignal $v(trans,name) "" $v(multiwav,file) "switch"
      if {$v(sig,name) == ""} {
	set rep [tk_messageBox -type okcancel -icon warning -message \
		     [concat [Local "Please open signal for signal"] $v(multiwav,file)]]
	if {$rep == "ok"} {
	  OpenAudioFile "add"
	}
	if {$v(sig,name) == ""} {
	  EmptySignal "switch"
	}
      }
      #set v(multiwav,path) [lreplace $v(multiwav,path) $pos $pos $v(sig,name)]
    }
  }
}