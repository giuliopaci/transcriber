#!/bin/sh
#\
exec wish "$0" "$@"

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)
# WWW:          http://www.etca.fr/CTA/gip/Projets/Transcriber/Index.html
# Author:       Claude Barras

################################################################

# Library for checking of XML well-formedness and validity
# Constraint: only one DTD in memory

namespace eval ::xml::dtd {
   #variable state 0; 0: disabled; 1: type active; 2: type+ids active
   #variable name ""

   # Empty current DTD
   proc init {} {
      variable state 0
      variable name ""
      element::init
      attribute::init
      entity::init	    
      id::init
      notation::init
   }

   # set/return state of DTD for dynamic validation: 1=active, 0=inactive
   proc active {{new_state ""}} {
      variable state
      if {$new_state != ""} {
	 set state $new_state
      }
      return $state
   }

   # set/return name of current active external DTD
   proc name {{new_name ""}} {
      variable name
      if {$new_name != ""} {
	 set name $new_name
      }
      return $name
   }

   # read new external DTD and switch to dynamic validating mode
   proc xml_read {fileName args} {
      init
      eval ::xml::parser::read_file [list $fileName] $args -type dtd
      active 1
   }

   #=======================================================================
   # Element types management

   namespace eval element {

      proc init {} {
	 variable contents
	 catch {unset contents}
	 array set contents {}
      }

      proc declare {type content} {
	 upvar ::xml::parser::rgS rgS
	 upvar ::xml::parser::Name Name

	 if {[info exists contents($type)]} {
	    error "Element '$type' already defined"
	 }
	 if {$content == "EMPTY" || $content == "ANY"} {
	    # Empty/Any type
	 } elseif {[string first "\#PCDATA" $content] >= 0} {
	    # Mixed type
	    regsub -all -- "\[()$rgS*]" $content "" content
	    set content [split $content "|"]
	 } else {
	    # Element content type
	    # We should verify that $content really matches $children
	    regsub -all -- "$Name" $content "(\\0;)" content
	    regsub -all -- "\[,$rgS]" $content "" content
	 }

	 # Content can be: a word (EMPTY/ANY), a list (beginning with #PCDATA)
	 # or a regular expression for a list of sub-elements
	 variable contents
	 set contents($type) $content
      }

      # Check if $type is declared
      proc exists {type} {
	 variable contents

	 if {![info exists contents($type)]} {
	    error "Element type '$type' was not declared in DTD"
	 }
      }

      # Check if $child type can occur inside element of $father type
      proc authorized {father child} {
	 variable contents

	 if {[catch {set content $contents($father)}]} {
	    error "Element type '$father' was not declared in DTD"
	 }

	 # Any type
	 if {$content == "ANY"} {
	    return
	 }

	 # Empty type
	 if {$content == "EMPTY"} {
	    error "Element '$father' should be empty"
	 }

	 # Mixed type
	 if {[lindex $content 0] == "\#PCDATA"} {
	    if {[lsearch -exact $content $child] < 0} {
	       error "Element '$father' should not contain '$child' element"
	    }
	    return
	 }

	 # Element content type
	 if {$child == "\#PCDATA"} {
	    error "Element '$father' should not contain data"
	 }
	 if {![regexp $child $content]} {
	    error "Element '$father' should not contain '$child' element"
	 }
      }

      proc rightOrder {element} {
	 set type [$element getType]
	 variable contents
	 set content $contents($type)

	 # Verify elements order for element content type
	 if {$content == "ANY" || $content == "EMPTY" 
	     || [lindex $content 0] == "\#PCDATA"} {
	    return
	 }
	 set types ""
	 foreach child [$element getChilds "element"] {
	    append types [$child getType] ";"
	 }
	 #puts "^$content$\n$types"
	 if {![regexp "^$content$" $types]} {
	    error "Element content doesn't match order for '$type'"
	 }
      }

      # Validation of element childs
      proc validate {element} {
	 set type [$element getType]
	 foreach child [$element getChilds "element"] {
	    authorized $type [$child getType]
	 }
	 rightOrder $element
      }
   }

   #=======================================================================
   # Attributes list management

   namespace eval attribute {
      proc init {} {
	 variable atts
	 catch {unset atts}
	 array set atts {}
      }

      proc declare {type content} {
	 upvar ::xml::parser::AttDef AttDef
	 upvar ::xml::parser::rgS rgS
	 variable atts

	 if {![info exists atts($type)]} {
	    set atts($type) {}
	 }
	 while {[regexp "^($AttDef)(.*)$" $content all attdef name attype notation enumeration default v0 fixed value v1 r1 r2 r3 v2 r4 r5 r6 content]} {
	    # If attribute is already defined, keep initial declaration
	    if {[lsearch -exact $atts($type) $name] >= 0} {
	       continue
	    }
	    lappend atts($type) $name
	    # Attribut type:
	    if {$enumeration != ""} {
	       # Enumaration
	       regsub -all -- "\[()$rgS]" $attype "" names
	       set names [split $names "|"]
	       set attype "ENUMERATION"
	    } elseif {$notation != ""} {
	       # Notation
	       regsub -all -- "\[()$rgS]" [string range $attype 8 end] "" names
	       set names [split $names "|"]
	       set attype "NOTATION"
	       # Validity: Notation Attributes - (declaration of notations)
	       foreach not $names {
		  ::xml::dtd::notation::get $not
	       }
	    } else {
	       # String or Tokenized
	       set names {}
	    }
	    # Default value:
	    if {$value != ""} {
	       set value [::xml::dtd::entity::replace \
			  [::xml::dtd::unquote $value] -char]
	       if {$fixed != ""} {
		  # Fixed default value
		  set default "\#FIXED"
	       } else {
		  # Default value
		  set default "\#DEFAULT"
	       }
	    }
	    set atts($type,$name) [list $attype $names $default $value]
	    # Default value must be legal
	    if {$default == "\#FIXED" || $default == "\#DEFAULT"} {
	       authorized $type "" $name $value
	    }
	 }
      }
      
      # Return list of declared attributes for type
      proc declared {type} {
	 variable atts
	 if {[catch {set attnames $atts($type)}]} {
	    error "Attributes for type '$type' not declared in DTD"
	 }
	 return $attnames
      }

      # Return list of declared attribute with default value for $type
      proc defaultList {type} {
	 variable atts
	 set defs ""
	 foreach name [declared $type] {
	    foreach {attype list def val} $atts($type,$name) {}
	    if {$def == "\#FIXED" || $def == "\#DEFAULT"} {
	       append defs $name
	    }
	 }
	 return $defs
      }

      # Check if attribute/value pair authorized for type element
      proc authorized {type element name newval} {
	 variable atts
	 if {[catch {
	    foreach {attype list def val} $atts($type,$name) {}
	 }]} {
	    error "Attribute '$name' for type '$type' not declared in DTD"
	 }
	 if {$def == "\#FIXED" && $newval != $val} {
	    error "Attribute '$name' for type '$type' can't be modified"
	 }
	 # Validity: Notation Attributes / Enumeration
	 if {$list != "" && [lsearch -exact $list $newval] < 0} {
	    error "Attribute '$name' for type '$type' must be in {$list}"
	 }
	 # Verify Tokenized and String Types too
	 #  - has to check for IDs consistency
	 switch $attype {
	    "CDATA" {
	    }
	    "ID" {
	       ::xml::dtd::check Name $newval
	       ::xml::dtd::id::new $element $name $newval
	    }
	    "IDREF" {
	       ::xml::dtd::check Name $newval
	       ::xml::dtd::id::refs $element $name $newval
	    }
	    "IDREFS" {
	       ::xml::dtd::check Names $newval
	       ::xml::dtd::id::refs $element $name $newval
	    }
	    "ENTITY" {
	       ::xml::dtd::check Name $newval
	       ::xml::dtd::entity::is_unparsed $newval
	    }
	    "ENTITIES" {
	       ::xml::dtd::check Names $newval
	       foreach ent $newval {
		  ::xml::dtd::entity::is_unparsed $ent
	       }
	    }
	    "NMTOKEN" {
	       ::xml::dtd::check Nmtoken $newval
	    }
	    "NMTOKENS" {
	       ::xml::dtd::check Nmtokens $newval
	    }
	 }
	 # Entities references in default value have to be expanded !!!
      }

      # Returns 1 for implied tokenized or enumerated types
      # (for them, an empty value is forbidden but can be simulated by
      # unsetting the attributes)
      proc implied_nonull {type name} {
	 variable atts
	 if {[catch {
	    foreach {attype list def val} $atts($type,$name) {}
	 }]} {
	    error "Attribute '$name' for type '$type' not declared in DTD"
	 }
	 if {$def == "\#IMPLIED" && $attype != "CDATA"} {
	    return 1
	 } else {
	    return 0
	 }
      }

      # Check if all required attributes for $type are in $names list
      proc required {element} {
	 variable atts
	 set type  [$element getType]
	 set names [$element listAttr]
	 # Verify required attributes are defined
	 foreach name [declared $type] {
	    foreach {attype list def val} $atts($type,$name) {}
	    if {$def == "\#REQUIRED" && [lsearch -exact $names $name] < 0} {
	       error "attribute '$name' required for $element"
	    }
	 }
      }

      # Validation of attribute/value pairs for an element
      proc validate {element} {
	 # Verify elements attributes are declared and valids
	 set type  [$element getType]
	 foreach name [$element listAttr] {
	    authorized $type $name [$element getAttr $name]
	 }
	 # Verify required attributes are defined
	 required $element
      }

      # Return default value of $type element if it exists, else raise error
      # (at user option, returns empty string for implied types)
      proc default {type name {impty 0}} {
	 variable atts
	 if {[catch {
	    foreach {attype list def val} $atts($type,$name) {}
	 }]} {
	    error "Attribute '$name' for type '$type' not defined in DTD"
	 }
	 if {$def != "\#FIXED" && $def != "\#DEFAULT"} {
	    if {$impty && $def == "\#IMPLIED"} {
	       return ""
	    } else {
	       error "No default value of attribute '$name' for type '$type'"
	    }
	 }
	 return $val
      }
   }

   #=======================================================================
   # Entities management

   namespace eval entity {

      # Reset to default entity values
      proc init {} {
	 variable entities
	 catch {unset entities}
	 foreach {name value} {
	    lt   "&\#38;\#60;"
	    gt   "&\#62;"
	    amp  "&\#38;\#38;"
	    apos "&\#39;"
	    quot "&\#34;"
	 } {
	    declare "&" $name $value
	 }
      }

      # Define value for internal entity
      proc declare {type name value} {
	 variable entities

	 # Check name syntax
	 ::xml::dtd::check Name $name
	 # Expand entity chars in value
	 set value [replace $value -char]

	 # Accept only first declaration
	 if {![info exists entities($type$name,val)] 
	     && ![info exists entities($type$name,ext)]} {
	    set entities($type$name,val) $value
	 }
      }

      # Define new external entity
      proc external {type name pubid sysid ndata} {
	 variable entities

	 # Accept only first declaration
	 if {![info exists entities($type$name,val)] 
	     && ![info exists entities($type$name,ext)]} {
	    set entities($type$name,ext) [list $pubid $sysid $ndata]
	 }
      }

      # Check for declaration of an unparsed entity
      proc is_unparsed {name} {
	 variable entities

	 if {[info exists entities($type$name,ext)]} {
	    foreach {pubid sysid ndata} $entities($type$name,ext) {}
	    if {$ndata != ""} {
	       return $ndata
	    }
	 }
	 error "$type$name; should be defined as an unparsed entity"
      }

      proc getVal {name {type "&"}} {
	 variable entities

	 if {[info exists entities($type$name,val)]} {
	    set value $entities($type$name,val)
	 } elseif {[info exists entities($type$name,ext)]} {
	    foreach {pubid sysid ndata} $entities($type$name,ext) {}
	    if {$ndata != ""} {
	       error "Can't include unparsed entity $type$name;"
	    }
	    # Should not include external entities inside att values
	    error "Sorry, can't include external entity $type$name;"
	 } else {
	    error "entity $type$name; not defined"
	 }
	 return $value
      }

      # Replace character and internal entities
      # -all: all entities / -char: char entities only
      proc replace {val {mode "-all"}} {
	 upvar ::xml::parser::Reference Reference
	 upvar ::xml::parser::Char Char

	 set done ""

	 # Manual parsing (if not efficient enough, another lexer can be used)
	 while {[regexp "^(\[^&]*)($Reference)(.*)$" \
		     $val all before entity name decimal hexa after]} {
	    append done $before
	    if {$hexa != ""} {
	       #scan $hexa "%x" decimal
	       set decimal 0x$hexa
	    }
	    if {$decimal != ""} {
	       set char [format {%c} $decimal]
	       # Test if $char is in the range of valid chars
	       if {$decimal >= 65536 || ![regexp "\[$Char]" $char]} {
		  error "forbidden character entity &\#x[format %x $decimal];"
	       }
	       append done $char
	    } else {
	       if {$mode == "-all"} {
		  # Recursive internal entities replacement
		  append done [replace [getVal $name] $mode]
	       } else {
		  # Keep entity as is (process only character entities)
		  append done "&$name;"
	       }
	    }
	    set val $after
	 }
	 return [append done $val]
      }

   }

   #=======================================================================
   # IDs management
   # Information about ID definition and references are kept up-to-date
   # (in dynamic validating mode), but consistency between both
   # is only verified when 'xml::dtd::id::validate' is called.

   namespace eval id {
      # Reset all ID definitions and references
      # called from xml::dtd::init
      proc init {} {
	 variable prefix ""
	 foreach name {def_val def_elem ref_vals ref_elems} {
	    catch {
	       variable $name
	       unset $name
	    }
	 }
      }

      proc set_prefix {new_prefix} {
	 variable prefix $new_prefix
      }

      # (Re)define ID for element/attribute
      # called from xml::dtd::attribute::authorized
      proc new {element name value} {
	 # Specific prefix for different documents (ad-hoc)
	 variable prefix
	 set value $prefix$value

	 variable def_val
	 variable def_elem
	 if {[info exists def_elem($value)]} {
	    error "ID $value defined twice"
	 }
	 # Detect if we change an existing value
	 if {![catch {set oldval $def_val($element,$name)}]} {
	    unset def_elem($oldval)
	 }
	 set def_val($element,$name) $value
	 set def_elem($value) $element
      }
      
      # Set or modify ID refs from element/attribute
      # called from xml::dtd::attribute::authorized
      proc refs {element name values} {
	 # Specific prefix for different documents (ad-hoc)
	 variable prefix
	 foreach value $values {lappend newvals $prefix$value}
	 set values $newvals

	 variable ref_vals
	 variable ref_elems
	 # Detect if we change an existing value
	 if {![catch {set oldvals $ref_vals($element,$name)}]} {
	    foreach oldval $oldvals {
	       lsuppress ref_elems($oldval) $element
	    }
	 }
	 foreach value $values {
	    lappend ref_elems($value) $element
	 }
	 set ref_vals($element,$name) $values
      }

      # Update ID infos when an attribute or a whole element is deleted
      # - it could slow down applications
      # called from xml::element::delete and xml::element::unsetAttr
      proc suppress {element {name *}} {
	 # Suppress id of element
	 variable def_val
	 variable def_elem
	 foreach {elemname value} [array get def_val $element,$name] {
	    unset def_elem($value)
	    unset def_val($elemname)
	 }
	 # Suppress references from element
	 variable ref_vals
	 variable ref_elems
	 foreach {elemname values} [array get ref_vals $element,$name] {
	    foreach value $values {
	       lsuppress ref_elems($value) $element
	    }
	    unset ref_vals($elemname)
	 }
      }

      # Verify that all referenced IDs are really defined
      # called from xml::parser::parse_doc
      proc validate {} {
	 variable ref_elems
	 foreach {value refs} [array get ref_elems] {
	    if {[llength $refs] > 0} {
	       get $value
	    }
	 }
      }

      # Return item referenced by ID value
      # called by client application
      proc get {value} {
	 variable def_elem
	 if {[catch {set def $def_elem($value)}]} {
	    error "Reference to undefined ID $value"
	 }
	 return $def
      }

      # Return item references to ID value
      # called by client application
      proc get_refs {value} {
	 variable ref_elems
	 if {[catch {
	    set refs $ref_elems($value)
	 }]} {
	    set refs ""
	 }
	 return $refs
      }
   }

   #=======================================================================
   # Notations management

   namespace eval notation {

      # Reset to default values
      proc init {} {
	 variable notations
	 catch {unset notations}
      }

      proc declare {name pub sys} {
	 variable notations

	 if {![info exist notations($name)]} {
	    set notations($name) [list $pub $sys]
	 }
      }

      proc get {name} {
	 variable notations

	 if {![info exist notations($name)]} {
	    error "Notation $name not defined"
	 }
	 return $notations($name)
      }
   }

   #=======================================================================
   # General procedures

   # Check for well-formedness: value must match regexp of given name
   proc check {re_name value} {
      upvar ::xml::parser::$re_name name
      if {![regexp "^$name\$" $value]} {
	 return -code error "Value '$value' is not well-formed"
      }
   }

   # Normalize public identifier
   proc normPubId {public} {
      upvar ::xml::parser::S S
      set public [string trim [regsub -all $S $public " " public]]
   }

   # Strip quotes around value
   proc unquote {val} {
      if {$val == ""} return
      if {![regexp "^(\[\"'])(.*)(\[\"'])$" $val all sep1 val sep2]
       || $sep1 != $sep2} {
	 error "Wrongly quoted string $val"
      }
      return $val
   }
}

################################################################
