# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval Synchro {
   variable time
   variable value
   variable atts
   variable id
   setdef id 0

   proc InitTime {} {
      variable time
      variable value
      variable atts
      variable id 0

      catch {unset time}
      catch {unset value}
      catch {unset atts}
   }

   proc NewTime {val} {
      variable time
      variable value
      variable id

      # keep only 3 digits (1ms precision)
      set val [expr double([format "%.3f" $val])]

      # Look inside existing times
      if [catch {
	 set ti $value($val) 
      }] {
	 # Get unique time id
	 set ti "tm$id"
	 incr id

	 # Store in two associative arrays
	 set time($ti) $val
	 set value($val) $ti
      }
      return $ti
   }

   proc RemoveTime {id} {
      variable time
      variable value
      variable atts

      if {[info exists atts($id)]} {
	 if {[llength $atts($id)] > 0} {
	    #puts "$time($id) in use: $atts($id)"
	    return
	 }
	 unset atts($id)
      }
      unset value($time($id))
      unset time($id)
   }

   proc NextTimeTag {tag attrib} {
      set id [NewTime [$tag getAttr $attrib]]
      TagToUpdate $tag $attrib $id
      return $id
   }

   proc NewTimeTag {tag attrib val} {
      variable time
      set id [NewTime $val]
      # Register new value
      $tag setAttr $attrib $time($id)
      TagToUpdate $tag $attrib $id
      return $id
   }

   # Return time from value or from id
   proc GetTime {t} {
      if [catch {expr double($t)}] {
	 variable time
	 return $time($t)
      }
      return $t
   }

   # Get left and right values around current time
   proc GetBoundaries {t cN lN rN} {
      variable time
      variable value
      upvar $cN c
      upvar $lN l
      upvar $rN r

      set c $time($t)
      set sorted [lsort -real [array names value]]
      set i [lsearch -exact $sorted $c]
      set l [lindex $sorted [expr $i-1]]
      set r [lindex $sorted [expr $i+1]]
   }

   # Change time value; automatically propagated to segment widgets.
   # If necessary, user should not forget to call UpdateTimeTags also.
   proc ModifyTime {id val} {
      variable time
      variable value

      unset value($time($id))
      set time($id) $val
      if [info exists value($val)] {
	 error "Double time reference to $val"
      }
      set value($val) $id
   }

   # Add to list of attributes to modify
   proc TagToUpdate {tag attrib id} {
      variable atts
      lappend atts($id) [list $tag $attrib]
   }

   # Suppress from list of attributes to modify
   proc TagToForget {tag attrib id} {
      variable atts
      set pos [lsearch $atts($id) [list $tag $attrib]]
      set atts($id) [lreplace $atts($id) $pos $pos]
      if {[llength $atts($id)] == 0} {
	 #puts "RemoveTime $id"
	 RemoveTime $id
      }
   }

   # Modify tags associated with give time id
   proc UpdateTimeTags {id} {
      variable time
      variable atts
      catch {
	 set list $atts($id)
	 # Limit precision to 3 digits
	 set val  [format "%.3f" $time($id)]
	 ModifyTime $id $val
	 foreach elt $list {
	    foreach {tag attrib} $elt break ;
	    catch {
	       $tag setAttr $attrib $val
	    }
	 }
      }
   }
}

