# Read OGI Lola format
namespace eval lola {

   variable msg "OGI lola"
   variable ext ".lola"

   proc readSegmt {content} {
      set mpf 10.0
      set header 1
      set segmt {}
      foreach line [split $content "\n"] {
	 set line [string trim $line]
	 if {$line == ""} continue
	 if {$header} {
	    switch -glob -- $line {
	       "MillisecondsPerFrame:*" {
		  set mpf [lindex $line 1] }
	       "END OF HEADER" {
		  set header 0
	       }
	    }
	 } else {
	    set begin [expr [lindex $line 0]*$mpf/1000.0]
	    set end   [expr [lindex $line 1]*$mpf/1000.0]
	    set text  [lrange $line 2 end]
	    lappend segmt [list $begin $end $text]
	 }
      }
      return $segmt
   }
}