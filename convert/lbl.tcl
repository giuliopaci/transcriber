# RCS: @(#) $Id$

# Read LIMSI LBL format: start [label]
namespace eval lbl {

   variable msg "LIMSI label"
   variable ext ".lbl"

   proc readSegmt {content} {
      set segmt {}
      set begin 0.0
      set text ""
      set col ""
      foreach line [split $content "\n"] {
	 set line [string trim $line]
	 if {$line == "" || [string match "\#*" $line]} continue
         set newtxt ""
	 set newcol ""
	 if {[scan $line "%f%s%s" end newtxt newcol] >= 1} {
	   #[scan $line "%f%*\[ \t]%\[^\n]" end newtxt] >= 1
	    # [regexp "(\[0-9.eE+-]+)\[ \t]+(\[\x20-\xff]*)" $line all end newtxt]
            # limit precision to 3 digits
	    set end [format %.3f $end]
	    # ignore first frame
	    if {$end == 0.010} {
	       set end 0.0
	    }
	    if {$end > $begin} {
	       if {$text != ""} {
		  if {$col == "color"} {
		    set col [ColorMap $text]
		  }
		  lappend segmt [list $begin $end $text $col]
	       }
	       set text ""
	    } else {
	       set text ""
	       if {[llength $segmt] > 0} {
		  set text "\n\n"
	       }
	    }
	    append text $newtxt
	    set col $newcol
	    set begin $end
	 } else {
	    puts stderr "Warning - line '$line' ignored from .lbl parsing"
	 }
      }
      return  [lsort -real -index 0 $segmt]
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
