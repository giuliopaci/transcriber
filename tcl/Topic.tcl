# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

namespace eval topic {
   
   proc init {} {
      variable nb 1
      variable recent {}
      variable list
      catch {unset list}
   }
   
   # Register existing topics
   proc register {} {
      variable list
      variable nb
      global v

      init
      foreach topics [$v(trans,root) getChilds "element" "Topics"] {
	 foreach topic [$topics getChilds "element"] {
	    set name [$topic getAttr "desc"]
	    set id   [$topic getAttr "id"]
	    set list($name) $id
	    incr nb
	 }
      }
   }

   # Suppress ids without reference
   proc purge {} {
      variable list
      variable recent
      foreach {name id} [array get list] {
	 if {[llength [::xml::dtd::id::get_refs $id]] == 0} {
	    [::xml::dtd::id::get $id] delete
	    unset list($name)
	    lsuppress recent $id
	 }
      }
      DoModif "PURGE"
   }

   # Find id for existing topic name or returns ""
   proc search_id {name} {
      variable list
      if {[catch {
	 set id $list($name)
      }]} {
	 set id ""
      }
      return $id
   }

   # Create a new topic inside "Topics" sub-tree
   # and returns its id, or find an already existing topic
   proc create {name} {
      variable nb
      variable list

      # Avoid empty name => empty ID
      if {$name == ""} {
	 return ""
      }

      # Returns id of existing topic
      if {![catch {
	 set id $list($name)
      }]} {
	 return $id
      }

      # Search for a free id
      while {1} {
	 set id "to$nb"
	 incr nb
	 if {[catch {::xml::dtd::id::get $id}]} break
      }

      # Create new topic inside sub-tree
      global v
      set topics [lindex [$v(trans,root) getChilds "element" "Topics"] 0]
      if {$topics == ""} {
	 set topics [::xml::element "Topics" {} -begin $v(trans,root)]
      }
      ::xml::element "Topic" [list "id" $id "desc" $name] -in $topics

      # Keep list of topic names with associated id
      set list($name) $id

      return $id
   }

   # set/returns description for given topic
   proc get_atts {id} {
      return [[::xml::dtd::id::get $id] getAttr "desc"]
   }

   proc set_atts {id name} {
      variable list

      set item [::xml::dtd::id::get $id]
      # Unregister previous name
      set previous [$item getAttr "desc"]
      DoModif [list "TOPIC" $id $previous]
      if {$name != $previous} {
	 if {$name != ""} {
	    if {[info exists list($name)]} {
	       tk_messageBox -message "This name already exists" -type ok -icon error
	       error
	    }
	    set list($name) $id
	 }
	 if {$previous != ""} {
	    unset list($previous)
	 }
	 $item setAttr "desc" $name
	 # Update new name in editor and segmentation
	 foreach section [::xml::dtd::id::get_refs $id] {
	    if {[$section getType] == "Section"} {
	       ::section::update $section
	    }
	 }
      }
   }

   # Sorted list of all registred names
   proc all_names {} {
      variable list
      return [lsort -dictionary [array names list]]
   }

   # Keep 5 most recently used ids
   proc most_recent {id} {
      variable recent
      lsuppress recent $id
      set recent [lrange [concat $id $recent] 0 4]
   }

   # Find topic from list
   proc find {} {
      variable id1 ""
      variable occur ""

      set w .tpc
      catch {destroy $w}
      toplevel $w
      wm title $w [Local "Find topic"]
      #
      set w1 [frame $w.top -relief raised -bd 1]
      pack $w1 -side top -fill both -expand true
      variable lst [ListFrame $w1.lst [all_names]]
      label $w1.lab -textvariable ::topic::occur -font $::v(font,mesg)
      pack $w1.lab -side top -padx 3m -expand true
      bind $lst <ButtonRelease-1>  "::topic::find_lst"
      #
      set w2 [frame $w.bot -relief raised -bd 1]
      pack $w2 -side bottom -fill both
      button $w2.fin -text [Local "Find next"] -command {::topic::find_next} -default active
      #button $w2.imp -text [Local "Import from file"] -command {::topic::import; ::topic::find_refr}
      #button $w2.pur -text [Local "Remove unused"] -command {::topic::purge; ::topic::find_refr}
      button $w2.clo -text [Local "Close"] -command "destroy $w"
      pack $w2.fin $w2.clo -side left -padx 3m -pady 3m -fill x -expand true
      bind $w <Return> "tkButtonInvoke $w2.fin"
      bind $w <Escape> "tkButtonInvoke $w2.clo"
      # Toplevel windows do not inherit '.' bindings
      bind $w <Tab> "PlayOrPause; break"
      bind $w <Control-Down> "::topic::find_next; break"
      bind $w <Control-Up> "::topic::find_next -1; break"

      variable idx ""
      CenterWindow $w
   }

   proc find_refr {} {
      variable lst
      #purge
      $lst delete 0 end
      eval $lst insert end [all_names]
   }

   proc find_next {{dir 1}} {
      variable id1
      if {$id1 != ""} {
	 TextNextSection $dir $id1
      }
   }

   proc find_lst {} {
      variable lst
      set idx [$lst curselection]
      if {$idx == ""} return
      variable id1 [search_id [$lst get $idx]]
      if {$id1 == ""} {
	 $lst delete 0 end
	 eval $lst insert end [all_names]
      } else {
	 set nb [llength [::xml::dtd::id::get_refs $id1]]
	 variable occur "$nb reference(s)"
      }
   }

   # Import topics from another XML file
   proc import {{filename ""}} {

      # Get filename through dialog box
      if {$filename == ""} {
	 global v
	 set types {
	    {"XML format" {.xml .trs .tpc}}
	    {"All files"   {*}}
	 }
	 set filename [tk_getOpenFile -filetypes $types \
	   -initialdir $v(trans,path) -title [Local "Import topics from file"]]
	 if {$filename == ""} return
      }

      # Read topic file (with complex trick to avoid collision of ids)
      set pref "import_"
      ::xml::dtd::id::set_prefix $pref
      if {[catch {
	 set tpctree [::xml::parser::read_file $filename -keepdtd 1]
      } err]} {
	 ::xml::dtd::id::set_prefix ""
	 return -code error -errorinfo $::errorInfo "Couldn't import topics from $filename"
      }
      ::xml::dtd::id::set_prefix ""

      # Transform into list
      set tpclst {}
      foreach topic [$tpctree getElementChilds "Topic"] {
	 set name [$topic getAttr "desc"]
	 if {$name != "" && [search_id $name] == ""} {
	    lappend tpclst $name
	 }
      }
      $tpctree deltree
      set tpclst [lsort -dictionary $tpclst]
      
      # Select items from list
      set f .imp
      CreateModal $f "Import topic"
      set w1 [frame $f.top -relief raised -bd 1]
      pack $w1 -side top -fill both -expand true
      variable lst2 [ListFrame $w1.lst $tpclst]
      $lst2 selection set 0 end
      #set w2 [frame $w1.but -relief raised -bd 1]
      #pack $lst2 $w2 -side left -fill both -expand true
      button $w1.all -text [Local "Select all"] -command "$lst2 selection set 0 end"
      button $w1.no -text [Local "Deselect all"] -command "$lst2 selection clear 0 end"
      pack $w1.all $w1.no -side left -padx 3m -pady 3m -fill x -expand true
      
      $lst2 conf -selectmode multiple
      global dial
      OkCancelFrame $f.bot dial(result)
      $f.bot.ok conf -command "set dial(sel) \[$lst2 curselection]; [$f.bot.ok cget -command]"
      WaitForModal $f $f dial(result)
      if {$dial(result) == "OK"} {
	 foreach i $dial(sel) {
	    create [lindex $tpclst $i]
	 }
      }
      return 
   }
}

namespace eval section {
   variable list_atts {"type" "topic"}

   proc get_atts {item} {
      variable list_atts
      foreach attr $list_atts {
	 lappend vals [$item getAttr $attr]
      }
      return $vals
   }

   proc short_name {section} {
      foreach {type topic} [get_atts $section] {}
      if {$topic != ""} {
	 return "[::topic::get_atts $topic]"
      } else {
	 return "$type"
      }
   }

   proc long_name {section} {
      foreach {type topic} [get_atts $section] {}
      if {$topic != ""} {
	 return "$type - [::topic::get_atts $topic]"
      } else {
	 return "$type"
      }
   }

   # Set attributes as a list for the given section
   # and update display and undo infos
   proc set_atts {section vals} {
      # Register old section attributes for undo
      DoModif [list "SECTION" $section [get_atts $section]]
      # Modify transcription
      variable list_atts
      foreach attr $list_atts val $vals {
	 $section setAttr $attr $val
      }
      # Refresh display
      update $section
   }

   proc update {section} {
      global v

      # Update segmentation
      set name [short_name $section]
      set nb [SearchSegmtId seg2 $section]
      SetSegmtField seg2 $nb -text $name
      # Update editor button
      set name [long_name $section]
      set button $v(tk,edit).[namespace tail $section]
      $button config -text $name -width [max 20 [string length $name]]
   }

   # Called from menu or button : choose topic for given or current section
   proc edit {{section ""}} {
      global v
      
      if {$section == ""} {
	 if {![info exist v(segmt,curr)]} return
	 set turn [[GetSegmtId $v(segmt,curr)] getFather]
	 set section [$turn getFather]
      }
      catch {
	  set_atts $section [choose [get_atts $section] $section]
      }
   }

   # Let user choose a topic between existing ones
   # called from ::section::edit; ChangeSegType
   proc choose {atts {section ""}} {
      variable id1 ""
      variable nam
      variable typ ""
      variable state
      variable ::topic::recent

      foreach {typ id1} $atts {}
      #
      set w [CreateModal .sect "Edit section attributes"]
      #
      RadioFrame $w.type "Type" ::section::typ {"report" "filler" "nontrans"}
      #
      set w0 [frame $w.topic -relief raised -bd 1]
      pack $w0 -side top -fill both -expand true
      #
      set w1 [frame $w0.choose]
      pack $w1 -side top -fill both -expand true
      #
      set w2 [frame $w0.edit]
      pack $w2 -side bottom -fill both -expand true
      #
      set w11 [frame $w1.rec]
      pack $w11 -side left -fill both
      set w111 [frame $w11.mid]
      pack $w111 -side top -fill x
      radiobutton $w111.none -text [Local "no topic"] -variable ::section::nam -value "" -command {::section::choose_empty}
      pack $w111.none -side left -padx 3m -pady 3m
      if {[llength $recent] > 0} {
	 label $w11.lab -text [Local "Recent topics"]
	 pack $w11.lab -side top -padx 3m -anchor w
	 foreach i [lrange $recent 0 2] {
	    radiobutton $w11.$i -text [string range [::topic::get_atts $i] 0 20] -variable ::section::id1 -value $i -command "::section::choose_recent $i"
	    pack $w11.$i -side top -anchor w -padx 3m
	 }
      }
      #
      set w12 [frame $w1.lst]
      pack $w12 -side right -fill both -expand 1
      variable lst [ListFrame $w12.lst [::topic::all_names]]
      $lst conf -height 6
      bind $lst <ButtonRelease-1>  "::section::choose_lst"
      #
      set w21 [frame $w2.lst]
      pack $w21 -side top -fill both -expand 1
      button $w21.new -text [Local "New topic"] -command {::section::choose_new}
      variable edit [button $w21.edit -text [Local "Modify topic"] -command {::section::choose_edit}]
      pack $w21.new $w21.edit -side left -padx 3m -pady 3m -expand true
      variable ent [EntryFrame $w2.nam "Topic" ::section::nam]
      variable watt $w2.nam

      # Detect normal keypress when entry is disabled
      foreach key {Control-Key Alt-Key Meta-Key Return Escape Tab} {
	 bind $ent <$key> {continue}
      }
      bind $ent <KeyPress> {set k %A; if {$k != "" && $::section::state == "choose"} {::section::choose_new}}

      choose_recent $id1

      if {$section != ""} {
	 set buttons {"OK" "Destroy" "Cancel"}
      } else {
	 set buttons {"OK" "Cancel"}
      }
      set result [OkCancelModal $w $ent $buttons]
      if {$result != "OK"} {
	 if {$result == "Destroy"} {
	    JoinTransTags 2 $section
	 }
	 return -code error cancel
      }
      if {$state == "new"} {
	 set id1 [::topic::create $nam]
      } elseif {$state == "edit"} {
	 ::topic::set_atts $id1 $nam
      }
      ::topic::most_recent $id1
      return [list $typ $id1]
   }

   proc choose_new {} {
      variable id1 ""
      variable nam ""

      variable state "new"
      variable edit
      $edit conf -state disabled

      variable lst
      $lst selection clear 0 end
      variable watt
      FrameState $watt 1

      variable ent
      variable ::topic::nb
      $ent insert insert "topic\#$nb"
      $ent select range 0 end
      focus $ent
   }

   proc choose_lst {} {
      variable lst
      catch {
	 choose_id [::topic::search_id [$lst get [$lst curselection]]]
      }
   }

   proc choose_empty {} {
      choose_recent ""
   }

   proc choose_recent {id} {
      variable lst
      if {$id != ""} {
	 set index [lsearch [::topic::all_names] [::topic::get_atts $id]]
	 $lst selection clear 0 end
	 $lst selection set $index
	 $lst see $index
      } else {
	 $lst selection clear 0 end
      }
      choose_id $id
   }

   proc choose_edit {} {
      variable state "edit"
      variable watt
      FrameState $watt 1
   }

   proc choose_id {id} {
      variable id1 $id
      variable nam ""
      variable state "choose"
      variable edit

      if {$id != ""} {
	 set nam [::topic::get_atts $id]
	 $edit conf -state normal
      } else {
	 $edit conf -state disabled
      }
      variable watt
      FrameState $watt 0
   }
}

