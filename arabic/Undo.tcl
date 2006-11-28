# Copyright (C) 1998, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

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
	 $t mark set insert "$data.first"
	 $t delete insert "$data.last-1c"
	 $t insert insert $txt 
      }
      "MOVE" {
	 set id [lindex $undo 1]
	 set pos [lindex $undo 2]
	 Synchro::GetBoundaries $id previous left right
	 Synchro::ModifyTime $id $pos
	 Synchro::UpdateTimeTags $id
	 DoModif "MOVE $id $previous"
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

