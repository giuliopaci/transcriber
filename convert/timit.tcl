# RCS: @(#) $Id$

# Read TIMIT segmentation in a list
namespace eval timit {

   variable msg "TIMIT format"
   variable ext ".phn .wrd .txt"

   proc guess {name} {
      variable ext
      set filext [string tolower [file extension $name]]
      if {[lsearch $ext $filext]>=0} {
	 # Get fields 1,2,3 of 1st line
	 set f [open $name]
	 foreach {a b c} [split [gets $f]] break
	 close $f
	 # Must be 'integer integer string'
	 if {[regexp {^[0-9]+$} $a] && [regexp {^[0-9]+$} $b] && $c != ""} {
	    return 1
	 }
      }
      return 0
   }

   proc readSegmt {content} {
      set segmt {}
      foreach line [split $content "\n"] {
	 set line [string trim $line]
	 if {$line == ""} continue
	 set begin [expr [lindex $line 0]/16000.0]
	 set end   [expr [lindex $line 1]/16000.0]
	 set text  [lrange $line 2 end]
	 lappend segmt [list $begin $end $text]
      }
      return $segmt
   }
}