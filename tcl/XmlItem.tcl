#!/bin/sh
#\
exec wish "$0" "$@"

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)
# WWW:          http://www.etca.fr/CTA/gip/Projets/Transcriber/Index.html
# Author:       Claude Barras

################################################################

# Methods for XML data management in memory as objects
#  - access through object-oriented procedures
#  - dynamic validation of attribute values/... when DTD is activated


# Object oriented syntax for XML items (elements, data ...)
#
# ::xml::$class
#  => creates and returns an object of given class
#
# $o $method $args
#  => executes given method on object $o
#
# $o $class::$method $args
#  => executes given method on object $o as if it were from $class
#
# $o delete
#  => destroy the object with its associated data


# Object can be of one of the predefined classes
#   - item = independant object with a string value associated
#            and methods for get/put this value
#   - node = an item linked inside a tree structure with methods 
#            for accessing the tree and linking nodes
#   - element = a node with a list of attribute name/value and methods
#            for managing the attributes
#   - data = a node (i.e. with a string value)
#   - comment = a node


# Exemple of utilisation for creation of an HTML title :
# set body [::xml::element "BODY"]
# set h1   [::xml::element "H1" {} -in $body]
# set a    [::xml::element "A" {"HREF" "demo.html"} -in $h1]
# set txt  [::xml::data "Demonstration" -in $a]
# $body dump
# $body deltree


# For a stand-alone use (without XmlDtd.tcl file), uncomment following lines :
# namespace eval xml {
#    namespace eval dtd {
#       proc init {} { }
#       proc active {} { return 0 }
#       proc check {args} { }
#    }
# }

################################################################

namespace eval ::xml {
   variable xml [namespace current]
   
   # init
   proc init {} {
      initItem
      dtd::init
   }

   #-----------------------------------------------------------------------
   # Item objects with an associated value
   #
   # Create an item object from the given class:
   #   ::xml::item ?$class? ?$value?
   #
   # Methods available on item object:
   #   $o delete
   #   $o class
   #   $o setValue $value
   #   $o getValue
   #
   # Initialization of all item objects (of any class):
   #   ::xml::initItem
   #
   # List of all item objects (of any class):
   #   ::xml::listItem
   #

   # Create a new item with an associated private data array and
   # a procedure with the same name for methods access 
   proc item {{class "item"} {value ""}} {
      # Check that the class exists
      if {[namespace children [namespace current] ::*::$class] == ""} {
	 error "Class $class doesn't exist"
      }
      
      # Get new item id
      variable id
      if {![info exists id]} {
	 set id 0
      }
      set item "[namespace current]::$class$id"
      incr id
	 
      # Create object data
      upvar ${item}_priv t
      set t(value) $value
	 
      # Create object proc
      proc $item {method args} "[namespace current]::CheckEval $class \$method $item \$args"
      
      return $item
   }

   # Destroy all items and initialize id counter
   proc initItem {} {
      variable id 0
      foreach item [listItem] {
	 # Don't use virtual del, because we know there is nothing else to do
	 $item item::delete
      }
   }

   # Returns the list of all existing items
   proc listItem {} {
      # all procs in xml namespace ending with a number should be an item
      info commands "[namespace current]::*\[0-9]"
   }

   # Test the beeing of a method before its real evaluation
   # (called from item procs)
   # We should use the 'unknown' function instead to manage errors
   # and speed up valid method access
   proc CheckEval {class method item lst_args} {
      # Try method inside current class
      set cmd [namespace current]::${class}::$method
      if {[info commands $cmd] == ""} {
	 # Try method from specified class
	 set class2 [namespace qualifier $method]
	 set cmd2 [namespace current]::$method
	 if {[info commands $cmd2] != "" && 
	     [namespace children [namespace current] ::*::$class2] != "" } {
	    set cmd $cmd2
	 } else {
	    set lst ""
	    foreach cmd2 [info commands [namespace qualifiers $cmd]::*] {
	       lappend lst [namespace tail $cmd2]
	    }
	    error "$item error - method '$method' not in: [lsort $lst]"
	 }
      }
      eval $cmd $item $lst_args
   }

   # Methods for item objects
   namespace eval item {
      namespace export *

      proc delete {myself} {
	 # Delete object data
	 catch {unset ${myself}_priv}

	 # Delete object proc
	 rename $myself {}
      }

      proc class {myself} {
	 return [namespace tail [namespace current]]
      }

      proc setValue {myself value} {
	 upvar ${myself}_priv t
	 set t(value) $value
      }

      proc getValue {myself} {
	 upvar ${myself}_priv t
	 return $t(value)
      }
   }

   #-----------------------------------------------------------------------
   # Items structured as nodes of a tree
   #
   # Creation of a node object:
   #    ::xml::node $class ?-in/-begin/-before/-after $item?
   #
   # Available methods for a node object $o:
   #   $o delete ?-recursive?
   #   $o deltree
   #   $o class
   #   $o getFather
   #   $o getChilds ?$class? ?$value? ?-recursive?
   #   $o getBrother ?$class? ?$value? ?+1/-1?
   #   $o link -in/-begin/-before/-after $item
   #   $o unlink
   #   $o unlinkChilds
   #   $o setChilds $list
   #   $o addChilds $list ?$pos?
   #
   # Methods inherited from item object:
   #   $o setValue
   #   $o getValue
   #
   # List of all orphans nodes (i.e., with no father)
   #    ::xml::orphanNodes

   # Create a new node; can be linked relative to another node.
   proc node {{class "node"} {position ""} {node ""}} {
      # Create empty item
      set item [item $class]
      upvar ${item}_priv t
      set t(childs) {}
      set t(father) {}

      # Insert in tree structure
      if {$position != "" && $node != ""} {
	 if {[catch {
	    node::link $item $position $node
	 } err]} {
	    # In case of error in linking, destroy object before leaving
	    node::delete $item
	    return -code error $err
	 }
      }
      
      return $item
   }

   # Check consistency of links (but doesn't check for cycles)
   # Returns orphan (i.e. root) nodes
   proc orphanNodes {} {
      set orphans {}
      # All items (commands ending with a number)
      foreach item [listItem] {
	 upvar ${item}_priv t
	 # Select only node items or derivatives
	 if {[info exists t(father)]} {
	    if {$t(father) == {}} {
	       lappend orphans $item
	    } else {
	       # Verify father still exists
	       if {[info command $t(father)] == ""} {
		  error "Item $item lost father $t(father)"
	       }
	       # Verify item is declared in the childs of its father
	       upvar $t(father)_priv u
	       if {[lsearch -exact $u(childs) $item] < 0} {
		  error "Item $t(father) lost child $item"
	       }
	    }
	 }
      }
      return $orphans
   }

   # Definition of node methods
   namespace eval node {
      namespace export *
      set xml [namespace parent]
      namespace import ${xml}::item::setValue
      namespace import ${xml}::item::getValue

      proc delete {myself {mode ""}} {
	 upvar ${myself}_priv t

	 set childs [$myself node::getChilds]

	 # Suppress from tree structure
	 unlink $myself
	 unlinkChilds $myself

	 # Optionnal recursive delete
	 if {$mode == "-recursive"} {
	    foreach child $childs {
	       catch {
		  $child delete $mode
	       }
	    }
	 }

	 # Delete item
	 [namespace parent]::item::delete $myself
      }

      proc deltree {myself} {
	 $myself delete -recursive
      }

      proc class {{myself ""}} {
	 return [namespace tail [namespace current]]
      }

      proc getFather {myself} {
	 upvar ${myself}_priv t
	 return $t(father)
      }

      proc getChilds {myself {class ""} {value "*"} {mode ""}} {
	 upvar ${myself}_priv t
	 set childs $t(childs)

	 # Trivial case: all direct childs
	 if {$class=="" && $value=="*" && $mode==""} {
	    return $childs
	 }

	 # Recursive case and/or selection upon class/value
	 lock $myself -on
	 set list {}
	 foreach child $childs {
	    # Selection upon class and value
	    if {($class=="" || [$child class] == $class)
		&& ($value=="*" || [string match $value [getValue $child]])} {
	       lappend list $child
	    }
	    # Recursive search mode (
	    if {$mode == "-recursive"} {
	        eval lappend list [getChilds $child $class $value $mode]
	    }
	 }
	 lock $myself -off
	 return $list
      }
      
      proc getBrother {myself {class "*"} {value "*"} {dir +1}} {
	 set fath [$myself getFather]
	 if {$fath == ""} {
	    error "$myself has no father"
	 }
	 set bros [$fath getChilds]
	 set pos [expr [lsearch -exact $bros $myself] + $dir]
	 set tag [lindex $bros $pos]
	 while {$tag != "" && 
		(($class != "*" && ![string match $class [$tag class]])
		||($value != "*" && ![string match $value [getValue $tag]]))} {
	    set tag [lindex $bros [incr pos $dir]]
	 }
	 return $tag
      }

      # Locking mechanism to prevent cycles: lock $item ?-on/-off/-reset?
      proc lock {item {mode "-on"}} {
	 variable lock
	 switch -exact -- $mode {
	    "-on" {
	       if [info exists lock($item)] {
		  unset lock
		  error "Circular tree for item $item"
	       }
	       set lock($item) 1
	    }
	    "-off" {
	       unset lock($item)
	    }
	    "-reset" {
	       catch {unset lock}
	    }
	 }
      }
      
      proc unlink {myself} {
	 upvar ${myself}_priv t
	 if {$t(father) != ""} {
	    upvar $t(father)_priv u
	    set pos [lsearch -exact $u(childs) $myself]
	    set u(childs) [lreplace $u(childs) $pos $pos]	    
	    set t(father) ""
	 }
      }

      proc unlinkChilds {myself} {
	 upvar ${myself}_priv t

	 foreach child $t(childs) {
	    upvar ${child}_priv u
	    set u(father) ""
	 }
	 set t(childs) ""
      }

      proc link {myself mode item} {
	 # Get father and insert pos
	 switch -exact -- $mode {
	    "-begin" {
	       set father $item
	       set pos 0
	    }
	    "-in" {
	       set father $item
	       set pos "end"
	    }
	    "-after" -
	    "-before" {
	       set father [$item getFather]
	       upvar ${father}_priv u
	       set pos [expr [lsearch -exact $u(childs) $item]]
	       if {$mode == "-after"} {
		  incr pos
	       }
	    }
	    default {
	       error "linking mode '$mode' unknown"
	    }
	 }
	 $father addChilds $myself $pos
      }

      # Add new childs at requested position inside node
      # (the only one proc which really adds childs to a node)
      proc addChilds {myself childs {pos "end"}} {
	 upvar ${myself}_priv t

	 foreach child $childs {
	    # Unlink from previous father and link to new one
	    unlink $child

	    upvar ${child}_priv u
	    set u(father) $myself
	    if {$pos != "end"} {
	       set t(childs) [linsert $t(childs) $pos $child]
	       incr pos
	    } else {
	       lappend t(childs) $child
	    }
	 }
      }

      proc setChilds {myself childs} {

	 # Unlink previous childs
	 unlinkChilds $myself

	 # Add new childs
	 $myself addChilds $childs
      }

      # Dump recursively the element and its content
      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 set sep "\n"
	 append var [getValue $myself]
	 foreach child [getChilds $myself] {
	    append var $sep
	    $child dump var
	 }
	 return $var
      }
   }

   #-----------------------------------------------------------------------
   # XML elements
   #
   # Creation of an element object:
   #   ::xml::element $type ?{attribute value ...}? \
   #                       ?-in/-begin/-before/-after $item?
   #
   # Available methods for an element object $o:
   #   $o class
   #   $o setType
   #   $o getType
   #   $o listAttr
   #   $o setAttr attribute value
   #   $o getAttr attribute
   #   $o dumptag ?-start/-end/-empty? ?var?
   #   $o dump ?var?
   #   $o getElementChilds
   #   $o getDataChilds
   #
   # Methods inherited from node object:
   #   $o delete ?-recursive?
   #   $o deltree
   #   $o getFather
   #   $o getChilds ?$class? ?$value? ?-recursive?
   #   $o setChilds $list
   #   $o addChilds $list ?$pos?
   #

   proc element {type {attr_pairs {}} {position ""} {node ""}} {
      set xml [namespace current]
      
      set item [node "element"]
      if {[catch {
	 $item setType $type
	 
	 # Link after setting the type, so we can check validity of types
	 if {$position != "" && $node != ""} {
	    node::link $item $position $node
	 }
	 
	 # Clear attributes
	 upvar ${item}_priv t
	 set t(attr-list) ""
	 set t(valid-elem) 0
	 set t(valid-attr) 0

	 foreach {attr value} $attr_pairs {
	    # Well-formedness: attribute can only be defined once
	    if {[$item setAttr $attr $value] != ""} {
	       error "Non unique attribute specification for '$attr'"
	    }
	 }
      } err]} {
	 global errorInfo
	 $item delete
	 return -code error $err
      }
      return $item
   }

   namespace eval element {
      variable validate 0
      variable xml [namespace parent]
      namespace import ${xml}::node::deltree
      namespace import ${xml}::node::setChilds
      namespace import ${xml}::node::getChilds
      namespace import ${xml}::node::getFather
      namespace import ${xml}::node::getBrother
      
      proc delete {myself {mode ""}} {
	 variable xml

	 # Suppress from id structure
	 if {[${xml}::dtd::active]} {
	    ${xml}::dtd::id::suppress $myself
	 }
	    
	 # Delete node
	 [namespace parent]::node::delete $myself $mode
      }

      proc class {myself} {
	 return "element"
      }

      proc setType {myself value} {
	 upvar ${myself}_priv t
	 variable xml

	 # Keep well-formedness
	 ${xml}::dtd::check Name $value

	 # Keep validity
	 if {[${xml}::dtd::active]} {
	    # Can't change existing type (or we should re-check everything)
	    if {$t(value) != ""} {
	       error "Sorry, can not change type of already declared element"
	    }
	    ${xml}::dtd::element::exists $value
	 }

	 # Then set the new type
	 set t(value) $value
      }

      proc getType {myself} {
	 upvar ${myself}_priv t
	 return $t(value)
      }

      # Return list of all defined attributes
      # At user request, returns the list of all possible attributes
      proc listAttr {item {mode ""}} {
	 upvar ${item}_priv t
	 variable xml

	 # List of defined attributes
	 set type $t(value)
	 set list $t(attr-list)
	 if {[${xml}::dtd::active]} {
	    switch -- $mode {
	       "-all" {
		  # Defined attributes and with default value
		  foreach name [${xml}::dtd::attribute::defaultList $type] {
		     if {[lsearch -exact $list $name] < 0} {
			lappend list $name
		     }
		  }
	       }
	       "-default" {
		  # Attributes with default value
		  set list [${xml}::dtd::attribute::defaultList $type] 
	       }
	       "-declared" {
		  # Declared attributes
		  set list [${xml}::dtd::attribute::declared $type] 
	       }
	    }
	 } elseif {$mode != ""} {
	    error "No active DTD"
	 }
	 return $list
      }

      # Set new value for the attribute of the element and return previous one
      # Check if the attribute is defined and the value is valid
      proc setAttr {item attr value} {
	 upvar ${item}_priv t
	 variable xml

	 # Verify well-formedness of attribute name
	 ${xml}::dtd::check Name $attr

	 # Verify validity of attribute and value
	 if {[${xml}::dtd::active]} {
	    # For implied tokenized or enumerated types, empty value
	    # imply 'unsetAttr $attr' instead of 'setAttr $attr ""'
	    if {$value == "" &&
		[${xml}::dtd::attribute::implied_nonull $t(value) $attr]} {
	       unsetAttr $item $attr
	       return
	    }
	    ${xml}::dtd::attribute::authorized $t(value) $item $attr $value
	 }


	 # Then set new value
	 if [catch {set t(attr,$attr)} oldval] {
	    set oldval {}
	    lappend t(attr-list) $attr
	 }
	 set t(attr,$attr) $value
	 return $oldval
      }

      # Unset a (potentially existing) attribute
      # no error if attribute doesn't exist or even is not defined in DTD
      proc unsetAttr {item attr} {
	 upvar ${item}_priv t
	 variable xml

	 catch {unset t(attr,$attr)}
	 lsuppress t(attr-list) $attr

	 # Suppress from id structure
	 if {[${xml}::dtd::active]} {
	    ${xml}::dtd::id::suppress $item $attr
	 }	    
      }

      # Return value of given attribute of a tag 
      # (or else default value if it is declared in DTD)
      proc getAttr {item attr} {
	 upvar ${item}_priv t
	 variable xml

	 if {[catch {
	    set val $t(attr,$attr)
	 }]} {
	    if {[${xml}::dtd::active]} {
	       # no error for undefined implied types: returns empty string
	       set val [${xml}::dtd::attribute::default [$item getType] $attr 1]
	    } else {
	       error "$item: attribute $attr not defined"
	    }
	 }
	 return $val
      }

      # The method addChilds is superseded by a new method
      # checking the validity of children types (but not their order)
      proc addChilds {myself childs {pos "end"}} {
	 upvar ${myself}_priv t
	 variable xml

	 if {[${xml}::dtd::active]} {
	    set type [$myself getType]
	    foreach child $childs {
	       ${xml}::dtd::element::authorized $type [$child getType]
	    }
	    set t(valid-elem) 0
	 }
	 ${xml}::node::addChilds $myself $childs $pos
      }

      # Return element childs of given type
      proc getElementChilds {myself {type "*"}} {
	 getChilds $myself "element" $type -recursive
      }

      # Return data childs
      proc getDataChilds {myself} {
	 getChilds $myself "data" "*" -recursive
      }

      # Return tag with element type and attributes formated upon $mode : 
      # -start : "<type attribute1="value1" ...> 
      # -end :   "</type> 
      # -empty : "<type attribute1="value1" .../> 
      proc dumpTag {myself {mode "-start"} {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 append var "<"
	 if {$mode == "-end"} {
	    append var "/[getType $myself]"
	 } else {
	    append var [getType $myself]
	    foreach attr [listAttr $myself] {
	       set val [getAttr $myself $attr]
	       # Dump as entities some special chars
	       regsub -all "&" $val {\&amp;} val
	       regsub -all "<" $val {\&lt;} val
	       regsub -all \" $val {\&quot;} val
	       append var " $attr=\"$val\""
	    }
	    if {$mode == "-empty"} {
	       append var "/"
	    }
	 }
	 append var ">"
	 return $var

      }

      # Dump recursively the element and its content
      # Elements are separated with "\n" (should probably be handled with DTD)
      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 set sep "\n"
 	 set childs [getChilds $myself]
	 if {[llength $childs] > 0} {
	    $myself dumpTag -start var
	    append var $sep
	    foreach child $childs {
	       $child dump var
	       append var $sep
	    }
	    $myself dumpTag -end var
	 } else {
	    $myself dumpTag -empty var
	 }
	 return $var
      }

      # Validation of XML elements according to DTD
      proc validate {myself} {
	 variable xml

	 # Do only necessary part of validation
	 #${xml}::dtd::attribute::validate $myself
	 #${xml}::dtd::element::validate $myself
	 valid-attr $myself
	 valid-elem $myself
	 foreach child [getChilds $myself "element"] {
	    validate $child
	 }
      }

      # Do xml::dtd::attribute::required only once
      proc valid-attr {myself} {
	 upvar ${myself}_priv t
	 variable xml
	 if {[${xml}::dtd::active] && !$t(valid-attr)} {
	    ${xml}::dtd::attribute::required $myself
	    set t(valid-attr) 1
	 }
      }

      # Do xml::dtd::element::rightOrder only once
      proc valid-elem {myself} {
	 upvar ${myself}_priv t
	 variable xml
	 if {[${xml}::dtd::active] && !$t(valid-elem)} {
	    ${xml}::dtd::element::rightOrder $myself
	    set t(valid-elem) 1
	 }
      }
   }

   #-----------------------------------------------------------------------
   # XML data item
   #
   # Creation of a data object:
   #   ::xml::data $value ?-in/-begin/-before/-after $item?
   #
   # Available methods for a data object $o:
   #   $o class
   #   $o dump ?var?
   #   $o setData
   #   $o getData
   #
   # Methods inherited from node object:
   #   $o delete ?-recursive?
   #   $o getFather
   #

   proc data {{value {}} {mode {}} {relative {}}} {
      set item [node "data" $mode $relative]
      $item setData $value
      return $item
   }

   namespace eval data {
      set xml [namespace parent]
      namespace import ${xml}::node::delete
      namespace import ${xml}::node::getFather
      namespace import ${xml}::node::getBrother
      namespace import ${xml}::item::setValue
      namespace import ${xml}::item::getValue
      rename setValue setData
      rename getValue getData

      proc class {myself} {
	 return "data"
      }

      proc getType {{myself ""}} {
	 return "\#PCDATA"
      }

      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 set val [$myself getData]
	 # Dump as entities some special chars
	 regsub -all "&" $val {\&amp;} val
	 regsub -all "<" $val {\&lt;} val
	 regsub -all ">" $val {\&gt;} val
	 append var $val
      }
   }

   #-----------------------------------------------------------------------
   # XML comment
   #
   # Creation of a comment object:
   #   ::xml::comment $value ?-in/-begin/-before/-after $item?
   #
   # Available methods for a comment object $o:
   #   $o class
   #   $o dump ?var?
   #   $o setComment
   #   $o getComment
   #
   # Methods inherited from node object:
   #   $o delete ?-recursive?
   #   $o getFather
   #

   proc comment {{value {}} {mode {}} {relative {}}} {
      set item [node "comment" $mode $relative]
      if {[catch {
	 $item setComment $value
      } err]} {
	 $item delete
	 return -code error $err
      }
      return $item
   }

   namespace eval comment {
      set xml [namespace parent]
      namespace import ${xml}::node::delete
      namespace import ${xml}::node::getFather
      namespace import ${xml}::node::getBrother

      proc class {myself} {
	 return "comment"
      }

      proc setComment {myself value} {
	 upvar ${myself}_priv t
	 if {[regexp -- "--" $value]} {
	    error "Comment can not contain '--' sequence"
	 }
	 set t(value) $value
      }

      proc getComment {myself} {
	 upvar ${myself}_priv t
	 return $t(value)
      }

      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 append var "<!--[getComment $myself]-->"
      }
   }

   #-----------------------------------------------------------------------
   # XML processing instruction
   #
   # Creation of a processing instruction object:
   #   ::xml::pi $target ?$value? ?-in/-begin/-before/-after $item?
   #
   # Available methods for a pi object $o:
   #   $o class
   #   $o dump ?var?
   #   $o setPI $target $value
   #   $o getPI
   #
   # Methods inherited from node object:
   #   $o delete ?-recursive?
   #   $o getFather
   #

   proc pi {target {value {}} {mode {}} {relative {}}} {
      set item [node "pi" $mode $relative]
      if {[catch {
	 $item setPI $target $value
      } err]} {
	 $item delete
	 return -code error $err
      }
      return $item
   }

   namespace eval pi {
      variable xml [namespace parent]
      namespace import ${xml}::node::delete
      namespace import ${xml}::node::getFather
      namespace import ${xml}::node::getBrother

      proc class {myself} {
	 return "pi"
      }

      proc setPI {myself target pi} {
	 upvar ${myself}_priv t
	 variable xml
	 ${xml}::dtd::check Name $target
	 if {[string tolower $target] == "xml"} {
	    error "Processing instruction target '$target' reserved"
	 }
	 if {[regexp "\\?>" $pi]} {
	    error "Processing instruction can not contain '?>' sequence"
	 }
	 set t(value) $target
	 set t(pi) $pi
      }

      proc getPI {myself} {
	 upvar ${myself}_priv t
	 return [list $t(value) $t(pi)]
      }

      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 append var "<?[join [getPI $myself]]?>"
      }
   }

   #-----------------------------------------------------------------------
   # XML cdata
   #
   # Creation of a cdata object:
   #   ::xml::cdata ?$value? ?-in/-begin/-before/-after $item?
   #
   # Available methods for a cdata object $o:
   #   $o class
   #   $o dump ?var?
   #   $o setCData $value
   #   $o getCData
   #
   # Methods inherited from node object:
   #   $o delete ?-recursive?
   #   $o getFather
   #

   proc cdata {{value {}} {mode {}} {relative {}}} {
      set item [node "cdata" $mode $relative]
      if {[catch {
	 $item setCData $value
      } err]} {
	 $item delete
	 return -code error $err
      }
      return $item
   }

   namespace eval cdata {
      variable xml [namespace parent]
      namespace import ${xml}::node::delete
      namespace import ${xml}::node::getFather
      namespace import ${xml}::node::getBrother

      proc class {myself} {
	 return "cdata"
      }

      proc setCData {myself value} {
	 upvar ${myself}_priv t
	 if {[regexp "]]>" $value]} {
	    error "CDATA can not contain ']]>' sequence"
	 }
	 set t(value) $value
      }

      proc getCData {myself} {
	 upvar ${myself}_priv t
	 return $t(value)
      }

      proc dump {myself {varName ""}} {
	 if {$varName != ""} {
	    upvar 3 $varName var
	 }
	 append var "<!\[CDATA\[[getCData $myself]]]>"
      }

   }

}
