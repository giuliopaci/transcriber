# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# called by: ReadTrans, NewTrans, SaveTrans, CloseTrans
proc InitModif {} {
   global v
   
   set v(trans,modif) {}

   # Init auto-save and undo
   InitAutoSave
   InitUndo
}

proc DoModif {descr} {
   global v

   set v(trans,modif) 1

   # Handle auto-save and undo
   RegisterAutoSave
   RegisterUndo $descr
}

proc HasModifs {} {
   global v
   
   return [expr {[info exists v(trans,modif)] && $v(trans,modif) != ""}]
}

################################################################

proc InitUndo {} {
   global v

   set v(undo,list) {}
   set v(undo,redo) 0
}

proc RegisterUndo {descr} {
   global v

   if {[llength $descr] > 1} {
      # Register undoable changes (TEXT, MOVE, SPEAKER, TOPIC)
      if {$v(undo,list) == "" || $v(undo,redo) == 1
	  || [lindex $descr 0] != [lindex $v(undo,list) 0]
	  || [lindex $descr 1] != [lindex $v(undo,list) 1]} {
	 set v(undo,list) $descr
      }
   } else {
      # Can't be undone (INSERT, DELETE, TYPE)
      set v(undo,list) {}
   }
   set v(undo,redo) 0
}

# Returns 0 in case of no undo available, 1 if undo, 2 if redo
proc HasUndo {} {
   global v

   return [expr {($v(undo,list) != "") + $v(undo,redo)}]
}

proc Undo {} {
   global v

   if {$v(undo,list) == ""} return
   # Unset previous value (and allow "redo")
   set undo $v(undo,list)
   set v(undo,list) ""
   switch [lindex $undo 0] {
      "TEXT" {
	 set data [lindex $undo 1]
	 set txt [lindex $undo 2]
	 set t $v(tk,edit)
	 $t mark set insert "$data.first+1c"
	 $t delete insert "$data.last"
	 $t insert insert $txt 
      }
      "MOVE" {
	 set id [lindex $undo 1]
	 set pos [lindex $undo 2]
	 set flt [lindex $undo 3]
	 Synchro::GetBoundaries $id previous left right leftIds rightIds
 	 set prev_flt [Synchro::getElastic $id]
	 Synchro::ModifyTime $id $pos
	 Synchro::setElastic $id $flt
	 Synchro::ModifyElastic $leftIds $previous $pos $left
	 Synchro::ModifyElastic $rightIds $previous $pos $right
	 foreach i [concat $id $leftIds $rightIds] {
	   Synchro::UpdateTimeTags $i
	 }
	 DoModif "MOVE $id $previous $prev_flt"
      }
      "SPEAKER" {
	 ::speaker::set_atts [lindex $undo 1] [lindex $undo 2]
      }
      "TOPIC" {
	 ::topic::set_atts [lindex $undo 1] [lindex $undo 2]
      }
      "TURN" {
	 ::turn::set_atts [lindex $undo 1] [lindex $undo 2]
      }
      "SECTION" {
	 ::section::set_atts [lindex $undo 1] [lindex $undo 2]
      }
   }
   set v(undo,redo) 1
}

################################################################

proc InitAutoSave {} {
   global v

   if {[info exists v(autosave,name)] && $v(autosave,name) != ""} {
      # Destroy previous auto-saved file
      catch {file delete $v(autosave,name)}
   }
   set v(autosave,name) [file join [file dirname $v(trans,name)] "\#[file tail $v(trans,name)]\#"]
   after cancel AutoSave
   set v(autosave,next) 0
}

proc RegisterAutoSave {} {
   global v

   catch {
      if {$v(autosave,time) > 0 && !$v(autosave,next)} {
	 # Register handler for auto-save (time in minutes)
	 after [expr int(1000*60*$v(autosave,time))] AutoSave
	 set v(autosave,next) 1
      }
   }
}

proc AutoSave {} {
   global v

   if {$v(trans,name) == ""} {
      # Auto-save of a newly created transcription: ask user
      SaveTrans
   } else {
      DisplayMessage "Autosaving as $v(autosave,name). Please wait..."
      update
      if {[catch {
	 WriteTrans $v(autosave,name) $v(trans,format)
      }]} {
	 DisplayMessage "Autosaving as $v(autosave,name) failed!"
      } else {
	 DisplayMessage ""
      }
   }
   set v(autosave,next) 0
}

proc AutoRescue {name} {
   global v

   set name2 [file join [file dirname $name] "\#[file tail $name]\#"]
   if    {[file isfile $name]  && [file writable $name] 
       && [file isfile $name2] && [file writable $name2]
       && [file mtime $name2]  >= [file mtime $name]} {
      set answer [tk_messageBox -message [Local "An automatically saved version was found. Rescue from it?"] -type yesno -icon question]
      if {$answer == "yes"} {
	 # keep last regular version in case autosaved file would be damaged
	 file rename -force -- $name "$name$v(backup,ext)"
	 file rename -force -- $name2 $name
      }
   }
   file delete -force $name2
}

################################################################

# called by Main, ConfigureGeneral, TraceAction
proc TraceInit {{dynamic 0}} {
   global v

   if {$v(trace,name) == ""} {
      bind all <Button> {}
      bind all <KeyRelease> {}
      return
   }
   # Initialize times
   set v(trace,day) [clock format [clock seconds] -format %m/%d/%y]
   if {![info exists v(trace,start)]} {
      set v(trace,start) ""
      set v(trace,stop) ""
      set v(trace,sum) 0
      set v(trace,pause) 0
      set v(trace,sum2) 0
      set v(trace,delta) {0 0 0 0 0 0}
      if {$dynamic} {
	 set v(trace,info) [TransInfo]
      } else {
	 set v(trace,info) {}
      }
   }
   # Detect most user actions (button or key press)
   bind all <Button> {TraceAction}
   bind all <KeyRelease> {TraceAction}
}

# One action has been detected : launch timer if necessary
# When nothing occurs for a while (>5min ?), we suppose the transcriber
# is making a break and we pause the counter.
# Called from keyboard and mouse bindings
proc TraceAction {} {
   global v

   if {$v(trace,start) == ""} {
      set v(trace,start) [clock seconds]
      set day [clock format $v(trace,start) -format %m/%d/%y]
      if {$day != $v(trace,day)} {
	 unset v(trace,start)
	 TraceQuit
	 TraceInit 1
	 set v(trace,start) [clock seconds]
      } else {
	 if {$v(trace,stop) != ""} {
	    set duration [expr $v(trace,start)-$v(trace,stop)]
	    incr v(trace,pause) $duration
	    set v(trace,stop) ""
	 }
      }
   }
   # Report trace stop later
   after cancel TraceIdle
   after [expr 1000*int(60*$v(trace,time))] TraceIdle
}

# When interface remains idle for too long, stop timer
proc TraceIdle {} {
   global v

   TraceStop [expr int(60*$v(trace,time))]
}

proc TraceStop {{before 0}} {
   global v

   if {[info exists v(trace,start)] && $v(trace,start) != ""} {
      set v(trace,stop) [expr [clock seconds]-$before]
      set duration [expr $v(trace,stop)-$v(trace,start)]
      incr v(trace,sum) $duration
      incr v(trace,sum2) $duration
      set v(trace,start) ""
   }
}

# called by NewTrans, ReadTrans
proc TraceOpen {} {
   global v

   if {$v(trace,name) == ""} return
   TraceStop
   set v(trace,sum2) 0
   set v(trace,info) [TransInfo]
   TraceAction
}

# called by TraceClose, TraceInfo
proc TraceInfoUpdate {} {
   global v

   if {$v(trace,name) == "" || $v(trace,info) == {}} return
   TraceStop
   set info [TransInfo]
   set delta {}
   foreach old $v(trace,info) new $info del $v(trace,delta) {
      lappend delta [expr $del+$new-$old]
   }
   set v(trace,delta) $delta
   set v(trace,info) $info
}

# called by CloseTrans, TraceQuit
proc TraceClose {} {
   global v

   if {$v(trace,name) == "" || $v(trace,info) == {}} return
   TraceInfoUpdate
   if {$v(trans,name) != ""} {
      set tim [clock format $v(trace,sum2) -format {%H:%M:%S} -gmt 1]
      #IncrementTime $v(trace,sum2)
      #set v(trace,sum2) 0
      TraceMesg [eval [list format "$v(trace,day) total %d sections %d topics %d turns %d speakers %d sync %d words after $tim in [file tail $v(trans,name)]"] $v(trace,info)]
   }
}

# called by Quit (+ TraceAction when day changes)
proc TraceQuit {} {
   global v

   if {$v(trace,name) == ""} return
   TraceClose
   set tim1 [clock format $v(trace,sum) -format {%H:%M:%S} -gmt 1]
   set tim2 [clock format $v(trace,pause) -format {%H:%M:%S} -gmt 1]
   TraceMesg [eval [list format "$v(trace,day) delta %d sections %d topics %d turns %d speakers %d sync %d words after $tim1 (paused $tim2) for $v(scribe,name)"] $v(trace,delta)]
}

# called by UpdateInfo
proc TraceInfo {} {
   global v

   if {$v(trace,name) == ""} return
   TraceInfoUpdate
   TraceAction
   set tim1 [clock format $v(trace,sum) -format {%H:%M:%S} -gmt 1]
   set tim2 [clock format $v(trace,pause) -format {%H:%M:%S} -gmt 1]
   append v(trans,desc) [eval [list format "\n\nToday's session duration: $tim1\t(paused $tim2)\nAmount of work:\n%d sections\t%d topics\n%d turns   \t%d speakers\n%d sync    \t%d words"] $v(trace,delta)]
}

# Register infos in file trace
# called by TraceClose, TraceQuit
proc TraceMesg {mesg} {
   global v

   #puts $mesg
   catch {
      set f [open $v(trace,name) "a"]
      puts $f $mesg
      close $f
   }
}

# Analyze log file (partially)
proc TraceProcess {} {
   global v

   if {$v(trace,name) == ""} return
   set f [open $v(trace,name)]
   set txt [read $f]
   close $f

   set txt [split $txt "\n"]

   foreach line $txt {
      if {[lindex $line 1] != "delta"} continue
      set day [clock scan [lindex $line 0]]
      set dur [clock scan [lindex $line 15] -base 0 -gmt 1]
      incr2 time($day) [expr $dur / 60.0]
      foreach {value name} [lrange $line 2 13] {
	 incr2 tab($day,$name) $value
      }
   }
   foreach day [lsort -integer [array names time]] {
      if {$time($day) <= 0} continue
      # day number since 1/1/99
      set nbd [expr ($day-[clock scan "12/30/98 23:00"])/86400]
      puts "$nbd\t$time($day)"
   }
}