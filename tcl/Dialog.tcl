# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# procedure CenterWindow taken from tk_messageBox :
# Copyright (c) 1994-1997 Sun Microsystems, Inc.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

proc CenterWindow {w} {
   wm withdraw $w
   update idletasks
   set x [expr [winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 \
	      - [winfo vrootx [winfo parent $w]]]
   set y [expr [winfo screenheight $w]/2 - [winfo reqheight $w]/2 \
	      - [winfo vrooty [winfo parent $w]]]
   wm geom $w +$x+$y
   wm deiconify $w
}

proc FrontWindow {w} {
   set geo [wm geometry $w]
   wm withdraw $w
   wm deiconify $w
   wm geometry $w $geo
}

################################################################

proc CreateModal {w title} {
   catch {destroy $w}
   toplevel $w -class Dialog
   wm title $w [Local $title]
   #wm iconname $w $title
   wm protocol $w WM_DELETE_WINDOW { }
   if {[info tclversion] < 8.4 || [tk windowingsystem] != "aqua"} {
     # transient setting did not seem to work correctly on Mac OS X + aqua
     wm transient $w .
   }
   return $w
}

proc OkCancelModal {w e {names {"OK" "Cancel"}}} {
   global dial

   OkCancelFrame $w.bot dial(result) $names
   WaitForModal $w $e dial(result)
   return $dial(result)
}

proc WaitForModal {w e varName} {
   global v
   if {[info exists v(geom,$w)] && $v(geom,$w) != ""} {
      FrontWindow $w
      update
      wm geom $w $v(geom,$w)
   } else {
      CenterWindow $w
   }
   set oldFocus [focus]
   grab $w
   update
   focus $e
   tkwait variable $varName
   catch {focus $oldFocus}
   if {[info exists v(geom,$w)]} {
      set v(geom,$w) [wm geom $w]
   }
   destroy $w
}

proc OkCancelFrame {w varName {names {"OK" "Cancel"}}} {

    # JOB: create an OkcancelFrame
    #
    # IN: w, name of the window created
    #     varName, variable associated to the frame
    #     names, names of the buttons, default OK and Cancel
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras
    # Version: 1.0
    # Date: 1999
    
    frame $w -relief raised -bd 1
    set t [winfo toplevel $w]
    foreach name $names {
	set but [string tolower $name]
	button $w.$but -text [Local $name] -command [list set $varName $name]
	switch $name {
	    "OK" {
	    $w.$but config -default active
		bind $t <Return> "tkButtonInvoke $w.$but"
	    }
	    "Cancel" {
		bind $t <Escape> "tkButtonInvoke $w.$but"
	    }
	}
	pack $w.$but -side left -expand 1 -padx 3m -pady 2m
    }
    pack $w -side bottom -fill both
}

proc ListFrame {f list} {
    
    # JOB: create a listframe
    #
    # IN: f, name of the window created
    #     list, list associated with to listframe
    # OUT: name of the window created
    # MODIFY: nothing
    #
    # Author: Claude Barras
    # Version: 1.0
    # Date: 1999

    frame $f
    set l $f.lst
    listbox $l -yscrollcommand [list $f.ysc set] -exportselection 0
    scrollbar $f.ysc -orient vertical -command [list $l yview]
    eval $l insert end $list
    pack $l -side left -expand true -fill both
    pack $f.ysc -side right -fill y
    pack $f -side top -fill both -expand 1  -padx 3m -pady 2m
    return $l
}

proc EntryFrame {w title varName {OKbutton no}} {
    
    # JOB: create an entryframe with an optional "OK" button associated
    #
    # IN: w, name of the window created
    #     title, label of the entryframe
    #     varName, associated variable to the entryframe
    #     OKbutton, variable for an optional OK button, default no button
    # OUT: name of the window created
    # MODIFY: nothing
    #
    # Author: Claude Barras, Sylvain Galliano
    # Version: 1.1
    # Date: October 20, 2004
    
    frame $w
    set l [label $w.lab -text "[Local $title]:"]
    set e [entry $w.ent -text $varName]
    $e select range 0 end
    $e icursor end
    $e xview end
    pack $l -side left -padx 3m -pady 2m
    pack $e -expand true -fill x -side left -padx 3m -pady 2m
    if {$OKbutton=="yes"} {
	set b [button $w.but -text "Ok"]
	pack $b -side left  
    }
    pack $w -side top -fill x -expand true
    return $e
}

proc ListEntryFrame {w title varName list} {
   frame $w -relief raised -bd 1
   set l [ListFrame $w.un $list]
   set e [EntryFrame $w.deux $title $varName]
   pack $w -side top -fill both -expand 1
   bind $l <ButtonRelease-1>  "$e delete 0 end; catch {$e insert insert \[%W get \[%W curselection]]}; $e select range 0 end"
   return $e
}

# Length of longest string in list
proc maxlength {list} {
   set m 0
   foreach s $list {
      set l [string length $s]
      if {$l > $m} {
	 set m $l
      }
   }
   return $m
}

proc MenuEntryFrame {w title varName list} {
   frame $w

   set title [Local $title]
   menubutton $w.b -text "$title:" -menu $w.b.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -width [maxlength [concat $list $title]]
   menu $w.b.menu -tearoff 0
   foreach i $list {
      $w.b.menu add radiobutton -label $i -variable $varName
   }
   pack $w.b -side left -padx 3m -pady 2m

   set e [entry $w.ent -textvar $varName]
   pack $e -expand true -fill x -side left -padx 3m -pady 2m
   pack $w -side top -fill x -expand true
   return $e
}

proc MenuFrame {w title varName list {list2 {}}} {
   frame $w
   label $w.lab -text "[Local $title]:"
   menubutton $w.b -indicatoron 1 -menu $w.b.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -direction flush -width [maxlength $list]
   if {$list2 == {}} {
      $w.b configure -textvariable $varName
   } else {
      upvar \#0 $varName var
      $w.b configure -text $var
   }
   menu $w.b.menu -tearoff 0
   foreach txt $list val $list2 {
      if {$list2 == {}} {
	 $w.b.menu add radiobutton -label $txt -variable $varName
      } else {
	 set txt [Local $txt]
	 if {$var == $val} {
	    $w.b conf -text $txt
	 }
	 $w.b.menu add radiobutton -label $txt -value $val -variable $varName -command [list $w.b conf -text $txt]
      }
   }
   pack $w.lab $w.b -side left -padx 3m -pady 2m
   pack $w -fill x -expand true
}

proc RadioFrame {w title varName list {list2 ""}} {
   if {$list2 == ""} {set list2 $list}
   frame $w -relief raised -bd 1
   pack $w -side top -fill both

   set ww [frame $w.left]
   set l [label $ww.lab -text "[Local $title]:"]
   pack $l -side left -padx 3m -pady 2m -expand true
   pack $ww -side left -fill x -expand true

   set rad_lst {}
   set ww [frame $w.right]
   for {set i 0} {$i < [llength $list]} {incr i} {
      set text [lindex $list $i]
      if {$text == "\t"} {
	 pack $ww -side left -expand true -fill x
	 set ww [frame $w.right$i]
	 continue
      }
      set value [lindex $list2 $i]
      radiobutton $ww.rad$i -var $varName -value $value -text [Local $text]
      pack $ww.rad$i -side top -anchor w
      lappend rad_lst $ww.rad$i
   }
   pack $ww -side left -expand true -fill x
   return $rad_lst
}

proc FrameState {w state} {
   if {[catch {
      $w conf -state [lindex {"disabled" "normal"} $state]
   }]} { catch {
      $w conf -foreground [lindex {"\#a3a3a3" "Black"} $state]
   }}
   foreach ww [winfo children $w] {
      FrameState $ww $state
   }
}

proc ScrolledText {w} {
   set t $w.txt
   set s $w.scr
   frame $w -bd 5
   text $t -padx 5 -pady 5 -wrap word -width 80 -height 25 \
       -yscrollcommand [list $s set] -bg white
   scrollbar $s -orient vertical -command [list $t yview]
   pack $t -side left -fill both -expand true
   pack $s -side right -fill y
   pack $w -expand true -fill both
   return $t
}

proc ColorFrame {w title varName} {

    # JOB: Create the color frame to configure the desired colors. Called by ConfigureColors
    #
    # IN: w, name of the subframe corresponding to the element to configure
    #     title, label that appears in the subframe  
    #     varName, variable associated with the subframe
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Claude Barras
    # Version: 1.0
    # Date: 1999

    upvar $varName var
    frame $w
    set l [label $w.lab -width 20 -anchor e -text "[Local $title]:"]
    set b [ColoredButton $w.col [subst {
	ChooseColor $varName; 
	$w.col conf -bg $$varName -activebackground $$varName
    }] -bg $var -activebackground $var -width 2]
    pack $l -side left -padx 3m
    pack $b -side right -padx 3m
    pack $w -side top -fill x -expand true
    return $b
}

proc ColoredButton {w cmd args} {
  if {[info tclversion] >= 8.4 && [tk windowingsystem] == "aqua"} {
    eval {label $w -relief raised} $args
    bind $w <Button-1> $cmd
    return $w  
  } else {
    eval {button $w -command $cmd} $args
  }
}

################################################################

# General list editor
proc ListEditor {list {title "Edit list"} {fields {"name" "value"}} {new {}} {callback {}}} {
   global lst
   set lst(val) $list
   set lst(nb) [llength $fields]

   set w [CreateModal .lst $title]
   #
   set w1 [frame $w.top -relief raised -bd 1]
   pack $w1 -side top -fill both -expand true
   set lst(wdg) [ListFrame $w1.lst ""]
   $lst(wdg) conf -font list -width 40
   bind $lst(wdg) <ButtonRelease-1>  "EditList"
   set lst(stat) {}
   for {set i 0} {$i < $lst(nb)} {incr i} {
      set lst(e$i) [EntryFrame $w1.f$i [lindex $fields $i] lst(f$i)]
      lappend lst(stat) $w1.f$i
   }
   set w2 [frame $w1.but]
   pack $w2 -side top -fill both -expand true
   button $w2.new -text [Local "New"] -command {NewList}
   button $w2.del -text [Local "Delete"] -command {DelList}
   button $w2.mod -text [Local "Modify"] -command {ModifList} -default active

   menubutton $w2.sort -menu $w2.sort.menu -relief raised -bd 2 -highlightthickness 2 -anchor c -text [Local "Sort by..."]
   menu $w2.sort.menu -tearoff 0
   for {set i 0} {$i < $lst(nb)} {incr i} {
      $w2.sort.menu add command -label [Local [lindex $fields $i]] -command [list SortList $i]
   }

   pack $w2.new $w2.sort $w2.del $w2.mod -side left -padx 3m -pady 2m -fill x -expand true
   #
   if {[llength $list] == 0 || [llength $new] > 0} {
      NewList $new
   } else {
      UpdatList
   }

   OkCancelFrame $w.bot lst(result)
   $w.bot.ok conf -default normal -command "ModifList; [$w.bot.ok cget -command]"
   bind $w <Return> "tkButtonInvoke $w2.mod"
   if {$callback != ""} {
      eval $callback
   }
   WaitForModal $w $lst(e0) lst(result)
   if {$lst(result) != "OK"} {
      return -code error cancel
   }
   return $lst(val)
}

proc SortList {i} {
   global lst
   ModifList
   set lst(val) [lsort -index $i $lst(val)]
   UpdatList 0
}

proc NewList {{new {}}} {
   global lst
   set idx [$lst(wdg) curselection]
   if {$idx == ""} {
      lappend lst(val) $new
      UpdatList [expr [llength $lst(val)]-1]
   } else {
      ModifList
      incr idx
      set lst(val) [linsert $lst(val) $idx $new]
      UpdatList $idx
   }
}

proc DelList {} {
   global lst
   set idx [$lst(wdg) curselection]
   if {$idx == ""} return
   set lst(val) [lreplace $lst(val) $idx $idx]
   if {$idx > 0} {
      incr idx -1
   }
   UpdatList $idx
}

proc EditList {} {
   global lst
   set idx [$lst(wdg) curselection]
   if {$idx == ""} {
      set v ""
   } else {
      set v [lindex $lst(val) $idx]
   }
   for {set i 0} {$i < $lst(nb)} {incr i} {
      set lst(f$i) [lindex $v $i]
   }
}

proc ModifList {} {
   global lst
   set idx [$lst(wdg) curselection]
   if {$idx == ""} return
   set v {}
   for {set i 0} {$i < $lst(nb)} {incr i} {
      lappend v $lst(f$i)
   }
   set lst(val) [lreplace $lst(val) $idx $idx $v]
   UpdatList $idx
}

proc lformat {list len {sep ":"}} {
   set res ""
   foreach a $list l $len {
      if {$l == ""} continue
      if {$res != ""} {
	 append res $sep
      }
      append res [format "%-${l}s" [string range $a 0 [expr $l-1]]]
   }
   return $res
}

proc UpdatList {{idx 0}} {
   global lst
   set res ""
   set s [expr [llength $lst(val)] > 0]
   foreach w $lst(stat) {
      FrameState $w $s
   }
   set len {}
   for {set i 0} {$i < $lst(nb)} {incr i} {
      set l$i 1
      if {$i < $lst(nb)-1} {
	 set max 20
      } else {
	 set max 999
      }
      foreach v $lst(val) {
	 set l$i [min $max [max [set l$i] [string length [lindex $v $i]]]]
      }
      lappend len [set l$i]
   }
   foreach v $lst(val) {
      lappend res [lformat $v $len " : "]
   }
   set pos [lindex [$lst(wdg) yview] 0]
   $lst(wdg) delete 0 end
   eval $lst(wdg) insert end $res
   $lst(wdg) selection set $idx   
   $lst(wdg) yview moveto $pos
   $lst(wdg) see $idx   
   EditList
   return $res
}

################################################################

# General font chooser
# Input: font in the format "family size style" or font name
# Output: 
#   -if "OK", returns new font value in the format "family size style"
#         and configure named font to the new value
#  - if "Cancel", returns initial font value in the same format
#         and reconfigure named font to initial value
proc ChooseFont {font} {
   global fontsel-family fontsel-size fontsel-weight fontsel-slant fontsel-nam
   
   # Analyse input font
   set fontsel-nam $font
   set init-conf [font actual $font] 
   foreach {attr val} ${init-conf} {
      set fontsel$attr $val
   }
   set initial [ChooseFontVal]

   # Create top window and frames
   set f .fontsel
   CreateModal $f "Choose font"
   set g [frame $f.top -relief raised -bd 1 -width 25c]
   pack $g -fill x -side top

   # Family menu button
   set h [frame $g.fam]
   pack $h -side top
   label $h.lab -text "Family:"
   eval tk_optionMenu $h.men fontsel-family  [lsort [font families]]
   $h.men conf -width [maxlength [font families]]
   pack $h.lab $h.men -side left -padx 3m -pady 3m

   # Size menu / entry
   set h [frame $g.siz]
   pack $h -side top
   menubutton $h.b -text "Size" -menu $h.b.menu -relief raised -bd 2 -highlightthickness 2 -anchor c
   menu $h.b.menu -tearoff 0
   foreach i {7 8 10 12 14 18 24 36} {
      $h.b.menu add radiobutton -label $i -variable fontsel-size
   }
   entry $h.ent -textvar fontsel-size -width 5
   pack $h.b $h.ent -side left -padx 3m -pady 3m

   # Bold/Italic checkboxes
   set h [frame $g.opt]
   pack $h -side top
   checkbutton $h.wgh -text "Bold" -variable fontsel-weight -onvalue "bold" -offvalue "normal" -anchor w -padx 3m
   checkbutton $h.sln -text "Italic" -variable fontsel-slant  -onvalue "italic" -offvalue "roman" -anchor w -padx 3m
   pack $h.wgh $h.sln -expand true -fill x -side left

   # Font sample
   set l [label $f.msg -relief raised -bd 1 -padx 10 -pady 10 -font $font \
       -justify left -wraplength 0 -text  "
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
!@#$%^&*()_+-=[]{};:\"'` ~,.<>/?\\|
"]
   pack $l -expand true -fill both -side top 

   # For real-time updating of sample
   foreach var {family size weight slant} {
      trace variable fontsel-$var w [list ChooseFontUpdate $l $var]
   }

   # Wait for answer and return new font or initial value
   set answer [OkCancelModal $f $f]
   set value [ChooseFontVal]
   unset fontsel-family fontsel-size fontsel-weight fontsel-slant fontsel-nam
   if {$answer != "OK"} {
      if {[lsearch [font names] $font] >= 0} {
	 eval font configure $font ${init-conf}
      }
      return $initial
   }
   return $value
}

proc ChooseFontVal {} {
   global fontsel-family fontsel-size fontsel-weight fontsel-slant

   set style ""
   if {${fontsel-weight} == "bold"} {
      lappend style "bold"
   }
   if {${fontsel-slant} == "italic"} {
      lappend style "italic"
   }
   set font [list ${fontsel-family} ${fontsel-size}]
   if {$style != ""} {
      lappend font $style
   }
   return $font
}

proc ChooseFontUpdate {w field n1 n2 op} {
   global fontsel-nam

   if {[lsearch [font names] ${fontsel-nam}] >= 0} {
      global fontsel-$field
      font configure ${fontsel-nam} -$field [set fontsel-$field]
   } else {
      $w conf -font [ChooseFontVal]
   }
}
