# RCS: @(#) $Id$

# Read Limsi LBL
namespace eval lbl {

   variable msg "LIMSI label"
   variable ext ".lbl"

   proc readSegmt {content} {
      set segmt {}
      set begin 0.0
      set text ""
      foreach line [split $content "\n"] {
	 set line [string trim $line]
	 if {[regexp "(\[0-9.eE+-]+)\[ \t]+(\[\x20-\xff]*)" $line all end newtxt]} {
	    if {$end > $begin} {
	       lappend segmt [list $begin $end $text]
	       set text ""
	    } else {
	       set text ""
	       if {[llength $segmt] > 0} {
		  set text "\n\n"
	       }
	    }
	    append text $newtxt
	    set begin $end
	 }
      }
      return $segmt
   }

   proc export {name} {
     global v
     set channel [open $name w]
     set prv 0.0
     foreach s $v(trans,seg0) {
       foreach {t0 t1 text} $s break
       set t0 [Synchro::GetTime $t0]
       set t1 [Synchro::GetTime $t1]
       if {$t0 > $prv} {
	 puts $channel $prv
       }
       puts $channel "$t0 $text"
       set prv $t1
     }
     puts $channel "$t1"
     close $channel
   }
}
