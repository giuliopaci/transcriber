# RCS: @(#) $Id$

# Read xwaves label format
namespace eval xwaves {

   variable msg "ESPS/xwaves"
   variable ext ".lab"

   proc readSegmt {content} {
      set end 0.0
      set header 1
      set segmt {}
      foreach line [split $content "\n"] {
	 set line [string trim $line]
	 if {$line == ""} continue
	 if {$header} {
	    switch -glob -- $line {
	       "\#" {
		  set header 0
	       }
	    }
	 } else {
	    set begin $end
	    set end   [lindex $line 0]
	    set text  [lrange $line 2 end]
	    lappend segmt [list $begin $end $text]
	 }
      }
      return $segmt
   }
}
