# RCS: @(#) $Id$

# Copyright (C) 1999-2000, DGA; (C) 2000-2002, LIMSI-CNRS
# part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
namespace eval ctm {

  variable msg "NIST .ctm format"
  variable ext ".ctm"

   proc readSegmt {content} {
     set segmt {}
     foreach line [split $content "\n"] {
       if {[string match ";;*" $line]} continue
       if {[regexp "(\[^ \t]+)\[ \t]+(\[^ \t]+)\[ \t]+(\[0-9.eE+-]+)\[ \t]+(\[0-9.eE+-]+)\[ \t]+(\[\x20-\xff]*)" $line all id chn  begin len text]} {
	 set text [string trim $text]
         set end [expr $begin+$len]
	 lappend segmt [list $begin $end $text]
       } else {
	 puts "Warning - wrong format for line '$line'"
       }
     }
     return $segmt
   }
}
