# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval Synchro {
   variable time
   variable value
   variable float
   variable atts
   variable id
   setdef id 0

   proc InitTime {} {
      variable time
      variable value
      variable float
      variable atts
      variable id 0

      catch {unset time}
      catch {unset value}
      catch {unset atts}
   }

  proc NewTime {val {st 0}} {
      variable time
      variable value
      variable float
      variable id

      # Floating boundary if value starts with a space
      # (hack for backward compatibility; will be handled by explicit attribute
      # if functionnality is kept)
      if {[string index $val 0] == " "} {
	#puts $val
        set st 1
      }
 
      # keep only 3 digits (1ms precision)
      set val [expr double([format "%.3f" $val])]

      # Look inside existing times
      if [catch {
	 set ti $value($val) 
      }] {
	 # Get unique time id
	 set ti "tm$id"
	 incr id

	 # Store in associative arrays
	 set time($ti) $val
	 set value($val) $ti
	 set float($ti) $st
       }
       return $ti
   }

   proc RemoveTime {id} {
      variable time
      variable value
      variable atts
      variable float

      if {[info exists atts($id)]} {
	 if {[llength $atts($id)] > 0} {
	    #puts "$time($id) in use: $atts($id)"
	    return
	 }
	 unset atts($id)
      }
      unset value($time($id))
      unset time($id)
      unset float($id)
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
   # plus ids of floating boundaries in-between
   proc GetBoundaries {t cN lN rN lidN ridN} {
      variable time
      variable value
      variable float
      upvar $cN c
      upvar $lN l
      upvar $rN r
      upvar $lidN lid
      upvar $ridN rid

      set c $time($t)
      set sorted [lsort -real [array names value]]
      set i [lsearch -exact $sorted $c]
      for {set j [expr $i-1]; set lid {}} {$j >= 0} {incr j -1} {
	set l [lindex $sorted $j]
	set id $value($l)
	set st $float($id)
	if {$st} {
	  lappend lid $id
	} else {
	  break
	}
      }
      for {set j [expr $i+1]; set rid {}} {$j < [array size value]} {incr j} {
	set r [lindex $sorted $j]
	set id $value($r)
	set st $float($id)
	if {$st} {
	  lappend rid $id
	} else {
	  break
	}
      }
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
      variable float
      catch {
	 set list $atts($id)
	 # Limit precision to 3 digits
	 set val  [format "%.3f" $time($id)]
	 ModifyTime $id $val
	 # prepend value with a space for floating boundaries
	 # for permanent storing of state
  	 if {$float($id)} {
	   set val " $val"
	 }
	 foreach elt $list {
	    foreach {tag attrib} $elt break
	    catch {
	       $tag setAttr $attrib $val
	    }
	 }
      }
   }

  # Handle floating boundaries
   proc ModifyElastic {ids old new fix} {
     foreach id $ids {
       set val [GetTime $id]
       set val [expr $fix + ($new-$fix) / ($old-$fix) * ($val - $fix)]
       ModifyTime $id $val
     }
   }

  proc setElastic {id {st 1}} {
    variable float
    set float($id) $st
    updateSyncImage $id
    #UpdateTimeTags $id   needs to be called after for consistency
  }

  proc getElastic {id} {
    variable float
    return $float($id)
  }

  # put boundaries within range into given state
  proc setRangeElastic {min max {st 1}} {
    variable time
    variable value
    variable float
    set sorted [lsort -real [array names value]]
    for {set i 1} {$i < [llength $sorted]-1} {incr i} {
      set val [lindex $sorted $i]
      if {$val >= $min && $val < $max} {
	set id $value($val)
	setElastic $id $st
	UpdateTimeTags $id
      }
    }
  }

  # update Sync image according to floating state
  proc updateSyncImage {id} {
      variable float
      variable atts
      foreach elt $atts($id) {
	foreach {tag attrib} $elt break
	if {[$tag getType] == "Sync"} {
	  if {$float($id)} {
	    ChangeSyncButton $tag circle2
	  } else {
	    ChangeSyncButton $tag circle
	  }
	}
      }
  }

  proc syncContextMenu {tag X Y} {
    variable float
    set nb [SearchSegmtId seg0 $tag]
    set id [GetSegmtField seg0 $nb -beginId]
    set ::v(syncState) $float($id)
    catch {destroy .syncMenu}
    set m [menu .syncMenu -tearoff 0]
    # First and last boundary are always fixed
    if {$nb <= 0} {
      set activ "disabled"
    } else {
      set activ "normal"
    }
    $m add check -label "Floating boundary" -variable v(syncState) -command "Synchro::setElastic $id \$v(syncState); Synchro::UpdateTimeTags $id" -state $activ
    $m add separator
    if {[GetSelection min max]} {
      set case "selected"
    } else {
      set case "all"
    }
    $m add command -label "Float $case boundaries" -command "Synchro::setRangeElastic $min $max 1"
    $m add command -label "Anchor $case boundaries" -command "Synchro::setRangeElastic $min $max 0"
    tk_popup .syncMenu $X $Y
  }
}
