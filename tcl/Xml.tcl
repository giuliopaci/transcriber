#!/bin/sh
#\
exec wish "$0" "$@"

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)
# WWW:          http://www.etca.fr/CTA/gip/Projets/Transcriber/Index.html
# Author:       Claude Barras

################################################################

# XML parsing and management, version 0.2a

# What it does:
#  - parsing of XML documents
#       (should be rather strict about well-formedness of documents)
#  - access through object-oriented procedures
#  - dynamic validation of element content (except element order)
#  - dynamic validation of attributes values (including ID/IDREFS)
#  - full support for Unicode (only available for Tcl/Tk 8.1 or higher)

# Yet lacking: 
#  - declaration/use of parameter references
#  - use of external entities (but external DTD subset is recognized)
#  - use of references containing markup
#  - correct white space handling, attribute-value normalization, etc.
# ... but perhaps in the future ?

################################################################

package provide xml 1.0
package require tcLex

# join parts of xml library
set name [info script]
catch {set name [file readlink $name]}
foreach part {XmlItem.tcl XmlDtd.tcl XmlParse.tcl} {
   source [file join [file dirname $name] $part]
}

xml::dtd::init

################################################################

proc xml_tst1 {} {
   namespace eval xml {
      initItem
      set e1 [element "Section" {"Type" "Report" "Topic" "politic"}]
      set e2 [element "Turn" {"Speaker" "Smith"} -in $e1]
      element "Sync" {"Time" "1.3"} -in $e2
      set d1 [data "Hello" -in $e2]
      element "Sync" {"Time" "2.7"} -after $d1
      data "and we will discuss today about the economy" -in $e2
      element "Sync" {Time "3.2"} -in $e2
      comment " This is a comment " -begin $e1
      $d1 setData "Hello, I am Smith"
      $e1 setAttr "Topic" "economy"
      puts [$e1 dump]
      $e1 deltree
   }
}

proc xml_tst {file args} {
   set root [eval ::xml::parser::read_file [file join "xmltest/not-wf/sa" $file] -valid 0 -debug 1 $args]
   puts [$root dump]
   $root deltree
}

proc xml_chk {{name "toto"}} {
   if {$name != ""} {
      set chn [open $name w]
   } else {
      set chn stdout
   }
   cd "xmltest/not-wf/sa"
   foreach file [glob *.xml] {
      if {[catch {
	 set root [::xml::parser::read_file $file -valid 0]
	 puts $chn "OK $file:"
	 puts $chn [$root dump]
	 $root deltree
      } err]} {
	 puts $chn "ERR $file: $err"
      }
   }
   if {$chn != "stdout"} {
      close $chn
   }
}
