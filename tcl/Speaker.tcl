# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
# speakers management

namespace eval speaker {
   variable list_atts {"name" "check" "type" "dialect" "accent" "scope"}
   variable list_chat {"name" "check" "type" "dialect" "accent" "scope" "role" "age" "birth" "education" "group" "language" "ses" "sex"}

   proc init {} {
      variable nb 1
      variable recent {}
      variable list
      catch {unset list}
   }
   
   # Register speakers from all already existing "Speakers" sub-trees
   proc register {} {
      variable list
      variable nb
      global v

      init
      foreach speakers [$v(trans,root) getChilds "element" "Speakers"] {
	 foreach speaker [$speakers getChilds "element"] {
	    set name [$speaker getAttr "name"]
	    set id   [$speaker getAttr "id"]
	    set list($name) $id
	    incr nb
	 }
      }
   }

   # Replace all references to one speaker with another
   proc replace {id1 id2} {
      foreach turn [::xml::dtd::id::get_refs $id1] {
	 $turn setAttr "speaker" $id2
	 ::turn::update $turn
      }      
   }

   # Suppress speaker ids without reference
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

   # Find id for existing speaker name or returns ""
   proc search_id {name} {
      variable list
      if {[catch {
	 set id $list($name)
      }]} {
	 set id ""
      }
      return $id
   }

   # Create a new speaker with the given name inside "Speakers" sub-tree
   # and returns its id, or find an already existing speaker with this name
   proc create {name {check ""} {type ""} {dialect ""} {accent ""} {scope ""} 
   {role ""} {age ""} {birth ""} {education ""} {group ""} {language ""} {ses ""} {sex ""} } {
      variable nb
      variable list

      # Avoid empty name => empty ID
      if {$name == "" || $name == ([Local "no speaker"])} {
	 return ""
      }

      # If a speaker with the same name already exists, returns its id
      if {![catch {
	 set id $list($name)
      }]} {
	 return $id
      }

      # Search for a free speaker id
      while {1} {
	 set id "spk$nb"
	 incr nb
	 if {[catch {::xml::dtd::id::get $id}]} break
      }

      # Create new speaker inside speakers sub-tree
      global v
      set speakers [lindex [$v(trans,root) getChilds "element" "Speakers"] 0]
      if {$speakers == ""} {
	 set speakers [::xml::element "Speakers" {} -begin $v(trans,root)]
      }
      if {$::v(chatMode)} {
	::xml::element "Speaker" [list "id" $id "name" $name "check" $check "type" $type "dialect" $dialect "accent" $accent "scope" $scope "role" $role "age" $age "birth" $birth "education" $education "group" $group "language" $language "ses" $ses "sex" $sex] -in $speakers
      } else {
	::xml::element "Speaker" [list "id" $id "name" $name "check" $check "type" $type "dialect" $dialect "accent" $accent "scope" $scope] -in $speakers
      }

      # Keep list of speaker names with associated id
      set list($name) $id

      return $id
   }

   # Returns name string for a list of speaker ids
   proc name {ids {join " + "}} {
      set speaker ""
      if {$ids == ""} {
	 lappend speaker ([Local "no speaker"])
      } else {
	 foreach id $ids {
	    lappend speaker [[::xml::dtd::id::get $id] getAttr "name"]
	 }
      }
      if {$join != ""} {
	 set speaker [join $speaker $join]
      }
      return $speaker
   }

   # set/returns attributes for given speaker as a list
   proc get_atts {id} {
      set item [::xml::dtd::id::get $id]
      if {$::v(chatMode)} {
	variable list_chat
	set lst $list_chat
      } else {
	variable list_atts
	set lst $list_atts
      }
      foreach attr $lst {
	lappend vals [$item getAttr $attr]
      }
      return $vals
   }

   proc set_atts {id vals} {
      set item [::xml::dtd::id::get $id]
      # Register old turn attributes for undo before setting new values
      DoModif [list "SPEAKER" $id [get_atts $id]]
      # Unregister previous speaker name
      variable list
      set previous [$item getAttr "name"]
      set new [lindex $vals 0]
      if {$new != $previous} {
	 if {$new != ""} {
	    if {[info exists list($new)]} {
	       tk_messageBox -message "This name already exists" -type ok -icon error
	       error
	    }
	    set list($new) $id
	 }
	 if {$previous != ""} {
	    unset list($previous)
	 }
	 set upd 1
      } else {
	 set upd 0
      }
      # Really change attributes
      if {$::v(chatMode)} {
	variable list_chat
	set lst $list_chat
      } else {
	variable list_atts
	set lst $list_atts
      }
      foreach attr $lst val $vals {
	 $item setAttr $attr $val
      }
      # Update new name in editor and segmentation after changes
      if {$upd} {
	 foreach turn [::xml::dtd::id::get_refs $id] {
	    if {[$turn getType] == "Turn"} {
	       ::turn::update $turn
	    }
	 }
      }
   }

   # Sorted list of all registred names
   proc all_names {} {
      variable list
      return [lsort -dictionary [array names list]]
   }

   # Keep 5 most recently used speaker ids
   proc most_recent {ids} {
      variable recent
      foreach id $ids {
	 lsuppress recent $id
	 set recent [lrange [concat $id $recent] 0 4]
      }
   }

   # Lastly used speaker (after the most recent one) - best guess ?
   # and try to avoid the given speaker id
   proc second_one {{excl ""}} {
      variable recent
      set spk [lindex $recent 1]
      if {$spk == $excl} {
	 set spk [lindex $recent 0]
      }
      return $spk
   }

   # Find speaker from list
   proc find {} {
      variable id1 ""
      variable occur ""

      set w .spk
      catch {destroy $w}
      toplevel $w
      wm title $w [Local "Find speaker"]
      #
      set w1 [frame $w.top -relief raised -bd 1]
      pack $w1 -side top -fill both -expand true
      variable lst [ListFrame $w1.lst [find_names]]
      label $w1.lab -textvariable ::speaker::occur -font $::v(font,mesg)
      pack $w1.lab -side top -padx 3m -fill x
      bind $lst <ButtonRelease-1>  "::speaker::find_lst"
      $lst conf -font list
      #
      set w2 [frame $w.bot -relief raised -bd 1]
      pack $w2 -side bottom -fill both
      button $w2.fin -text [Local "Find next"] -command {::speaker::find_next} -default active
      #button $w2.pur -text [Local "Remove unused"] -command {::speaker::purge; ::speaker::find_refr}
      button $w2.clo -text [Local "Close"] -command "destroy $w"
      pack $w2.fin $w2.clo -side left -padx 3m -pady 3m -fill x -expand true
      bind $w <Return> "tkButtonInvoke $w2.fin"
      bind $w <Escape> "tkButtonInvoke $w2.clo"
      # Toplevel windows do not inherit '.' bindings
      bind $w <Tab> "PlayOrPause; break"
      bind $w <Control-Down> "::speaker::find_next; break"
      bind $w <Control-Up> "::speaker::find_next -1; break"

      variable idx ""
      CenterWindow $w
   }

   # Sorted list of all registred names
   proc find_names {} {
      variable list
      set spklst {}
      foreach {name id} [array get list] {
	 set l [concat $id [get_atts $id]]
	 lappend spklst $l
      }
      set spklst [lsort -dictionary -index 1 $spklst]
      set n {}
      variable ids {}
      foreach l $spklst {
	 lappend n [lformat [lrange $l 1 end] {30 1 1 3 10 3}]
	 lappend ids [lindex $l 0]
      }
      return $n
   }

   proc find_refr {} {
      variable lst
      #purge
      $lst delete 0 end
      eval $lst insert end [find_names]
   }

   proc find_next {{dir 1}} {
      variable id1
      if {$id1 != ""} {
	 TextNextTurn $dir $id1
      }
   }

   proc find_lst {} {
      variable lst
      set idx [$lst curselection]
      if {$idx == ""} return
      variable ids
      #variable id1 [search_id [$lst get $idx]]
      variable id1 [lindex $ids $idx]
      if {$id1 == ""} {
	 $lst delete 0 end
	 eval $lst insert end [find_names]
      } else {
	 set nb [llength [::xml::dtd::id::get_refs $id1]]
	 variable occur "$nb reference(s)"
      }
   }

   # Import speakers from another XML file
   proc import {{filename ""}} {

      # Get filename through dialog box
      if {$filename == ""} {
	 global v
	 set types {
	    {"XML format" {.xml .trs .spk}}
	    {"All files"   {*}}
	 }
	 set filename [tk_getOpenFile -filetypes $types \
			   -initialdir $v(trans,path) \
			   -title [Local "Import speakers from file"]]
	 if {$filename == ""} return
      }

      # Read speakers file (with complex trick to avoid collision of ids)
      set pref "import_"
      ::xml::dtd::id::set_prefix $pref
      if {[catch {
	 set spktree [::xml::parser::read_file $filename -keepdtd 1]
      } err]} {
	 ::xml::dtd::id::set_prefix ""
	 return -code error -errorinfo $::errorInfo "Couldn't import speakers from $filename"
      }
      ::xml::dtd::id::set_prefix ""

      # Transform into list
      set spklst {}
      foreach speaker [$spktree getElementChilds "Speaker"] {
	 if {[search_id [$speaker getAttr "name"]] == ""} {
	    set id [$speaker getAttr "id"]
	    lappend spklst [get_atts $pref$id]
	 }
      }
      $spktree deltree
      set spklst [lsort -dictionary -index 0 $spklst]
      set spknam ""
      set glblst {}
      set nb 0
      foreach l $spklst {
	 lappend spknam [lformat $l {30 1 1 3 10 3}]
	 if {[lindex $l 5] == "global"} {
	    lappend glblst $nb
	 }
	 incr nb
      }
      
      # Select items from list
      set f .imp
      CreateModal $f "Import speakers"
      set w1 [frame $f.top -relief raised -bd 1]
      pack $w1 -side top -fill both -expand true
      variable lst [ListFrame $w1.lst $spknam]
      $lst selection set 0 end
      #set w2 [frame $w1.but -relief raised -bd 1]
      #pack $lst $w2 -side left -fill both -expand true
      button $w1.glb -text [Local "Select global speakers"] -command "$lst selection clear 0 end; foreach i {$glblst} {$lst selection set \$i}"
      button $w1.all -text [Local "Select all"] -command "$lst selection set 0 end"
      button $w1.no -text [Local "Deselect all"] -command "$lst selection clear 0 end"
      pack $w1.glb $w1.all $w1.no -side left -padx 3m -pady 3m -fill x -expand true
      
      $lst conf -selectmode multiple -font list -width 40
      global dial
      OkCancelFrame $f.bot dial(result)
      $f.bot.ok conf -command "set dial(sel) \[$lst curselection]; [$f.bot.ok cget -command]"
      WaitForModal $f $f dial(result)
      if {$dial(result) == "OK"} {
	 foreach i $dial(sel) {
	    eval create [lindex $spklst $i]
	 }
      }
      return 
   }
}

namespace eval turn {
   variable list_atts {"speaker" "mode" "fidelity" "channel"}

   # returns speaker ids and other attributes for given turn as a list
   # {speaker_ids mode fidelity}
   proc get_atts {item} {
      variable list_atts
      foreach attr $list_atts {
	 lappend vals [$item getAttr $attr]
      }
      return $vals
   }

   # We could append gender to speaker name ?
   proc get_name {turn} {
      return [::speaker::name [lindex [get_atts $turn] 0]]
   }

   # Set attributes as a list {speaker_ids mode fidelity} for the given turn
   # and update display and undo infos
   proc set_atts {turn vals} {
      global v

      # Register old turn attributes for undo
      DoModif [list "TURN" $turn [get_atts $turn]]
      # Update transcription
      variable list_atts
      foreach attr $list_atts val $vals {
	 $turn setAttr $attr $val
      }
      # Refresh display
      update $turn
   }

   proc update {turn} {
      global v

      set name [get_name $turn]
      # Update segmentation
      set nb [SearchSegmtId seg1 $turn]
      SetSegmtField seg1 $nb -text $name
      # Update editor button
      set button $v(tk,edit).[namespace tail $turn]
      $button config -text $name
   }

   # Called from menu or button : choose speaker for given or current turn
   proc edit {{turn ""}} {
      global v
      
      if {$turn == ""} {
	 if {![info exist v(segmt,curr)]} return
	 set turn [[GetSegmtId $v(segmt,curr)] getFather]
      }
      catch {
	 set_atts $turn [choose [get_atts $turn] 0 $turn]
      }
   }

   # Let user choose a speaker between existing ones
   variable mod ""
   variable fid ""
   variable cha ""

   proc choose {atts {start 0} {turn ""}} {
      variable ids
      variable pos $start
      variable newpos $start
      variable id1
      variable ovl
      variable mod
      variable fid
      variable cha
      variable nam
      variable chk
      variable exp
      variable typ
      variable dia
      variable acc
      variable ::speaker::recent

# added by Zhibiao
      variable role
      variable age 
      variable birth
      variable education
      variable group
      variable language
      variable ses 
      variable sex 
      
      # get speaker list and overlap state
      set ids [lindex $atts 0]
      set id1 [lindex $ids $pos]
      if {[llength $ids] > 1} {
	 set ovl 1
      } else {
	 set ovl 0
      }
      set ini_ovl $ovl
      # If not given, keep previous mode and fidelity
      if {[llength $atts] > 1} {
	 set mod [lindex $atts 1]
      }
      if {[llength $atts] > 2} {
	 set fid [lindex $atts 2]
      }
      set cha [lindex $atts 3]
      #
      set pad 1m
      set w [CreateModal .turn "Edit turn attributes"]
      #
      set w3 [frame $w.top -relief raised -bd 1]
      pack $w3 -side top -fill both
      checkbutton $w3.0 -text [Local "Overlapping speech"] -variable ::turn::ovl -command "::turn::choose_overlap"
      radiobutton $w3.1 -text [Local "Choose first speaker"] -variable ::turn::newpos -value 0 -command "::turn::choose_register; ::turn::choose_switch"
      radiobutton $w3.2 -text [Local "Choose second speaker"] -variable ::turn::newpos -value 1 -command "::turn::choose_register; ::turn::choose_switch"
      pack $w3.0 $w3.1 $w3.2 -side left -anchor w -padx $pad -pady $pad -expand true
      #
      set w0 [frame $w.mid]
      pack $w0 -side top -fill both -expand true
      #
      set w1 [frame $w0.left -relief raised -bd 1]
      pack $w1 -side left -fill both -expand true
      #
      set w2 [frame $w0.right -relief raised -bd 1]
      pack $w2 -side right -fill both -expand true
      #
      set w11 [frame $w1.up]
      pack $w11 -side top -fill both -expand 1
      button $w11.new -text [Local "Create speaker"] -command {::turn::choose_new}
      pack $w11.new -side left -padx $pad -pady $pad -expand true
      variable edit [button $w11.edit -text [Local "Modify speaker"] -command {::turn::choose_edit}]
      pack $w11.edit -side left -padx $pad -pady $pad -expand true
      #
      set w12 [frame $w1.spkatt]
      variable watt $w12
      pack $w12 -side top -fill both -expand 1
      variable ent [EntryFrame $w12.nam "Name" ::turn::nam]
      frame $w12.bts
      pack $w12.bts -side top -expand true -anchor w
      checkbutton $w12.bts.chk -text [Local "spelling checked"] -var ::turn::chk -onvalue "yes" -offvalue "no" -state disabled
      checkbutton $w12.bts.exp -text [Local "global name"] -var ::turn::exp -onvalue "global" -offvalue "local" -state disabled
      pack $w12.bts.chk $w12.bts.exp -side left -padx $pad -pady $pad -expand true -anchor w
      MenuFrame $w12.typ "Type" ::turn::typ {"male" "female" "unknown"}
      MenuFrame $w12.dia "Dialect" ::turn::dia {"native" "nonnative"}

     if {$::v(chatMode)} {
#### added by Zhibiao
      EntryFrame $w12.role "CH_Role" ::turn::role
      EntryFrame $w12.age  "CH_Age" ::turn::age 
      EntryFrame $w12.birth "CH_Birth" ::turn::birth
      EntryFrame $w12.education "CH_Education" ::turn::education
      EntryFrame $w12.group "CH_Group" ::turn::group
      EntryFrame $w12.langauge "CH_Language" ::turn::language
      EntryFrame $w12.ses "CH_Ses" ::turn::ses
      EntryFrame $w12.sex "CH_Sex" ::turn::sex
# added end
    }

      entry $w12.dia.acc -text ::turn::acc -width 15
      pack $w12.dia.acc -expand true -side left -padx $pad -pady $pad
      #EntryFrame $w12.acc "Accent" ::turn::acc
      #
      set w21 [frame $w2.up]
      pack $w21 -side top -fill both
      #label $w2.lab -text [Local "Choose speaker"]
      #pack $w2.lab -side top -padx $pad -pady $pad -expand true
      set w211 [frame $w21.mid]
      pack $w211 -side top -fill x
      #if {[llength $ids] <= 1} 
      radiobutton $w211.none -text [Local "no speaker"] -variable ::turn::nam -value "" -command {::turn::choose_empty}
      pack $w211.none -side left -padx $pad -pady $pad
      if {[llength $recent] > 0} {
	 label $w21.lab -text [Local "Recently used speakers"]:
	 pack $w21.lab -side top -padx $pad -anchor w
	 foreach i [lrange $recent 0 2] {
	    radiobutton $w21.$i -text [string range [::speaker::name $i] 0 20] -variable ::turn::id1 -value $i -command "::turn::choose_recent $i"
	    pack $w21.$i -side top -anchor w -padx $pad
	 }
      }
      #
      set w22 [frame $w2.down]
      pack $w22 -side top -fill both -expand 1
      variable lst [ListFrame $w22.lst [::speaker::all_names]]
      $lst conf -height 6
      bind $lst <ButtonRelease-1>  "::turn::choose_lst"
      # Detect normal keypress when entry is disabled
      foreach key {Control-Key Alt-Key Meta-Key Return Escape Tab} {
	 bind $ent <$key> {continue}
      }
      bind $ent <KeyPress> {set k %A; if {$k != "" && $::turn::state == "choose"} {::turn::choose_new}}
      #
      set w4 [frame $w.comp -relief raised -bd 1]
      pack $w4 -after $w0 -fill x -expand 0      
      MenuFrame $w4.mod "Mode" ::turn::mod {"spontaneous" "planned"}
      MenuFrame $w4.fid "Fidelity" ::turn::fid {"high" "medium" "low"}
      MenuFrame $w4.cha "Channel" ::turn::cha {"studio" "telephone"}
      pack $w4.mod $w4.fid $w4.cha -side left

      choose_overlap
      choose_recent $id1

      #OkCancelFrame $w.bot dial(result) {"OK" "Cancel"}; return
      if {$turn != ""} {
	 set buttons {"OK" "Destroy" "Cancel"}
      } else {
	 set buttons {"OK" "Cancel"}
      }
      set result [OkCancelModal $w $ent $buttons]
      if {$result != "OK"} {
	 if {$result == "Destroy"} {
	    JoinTransTags 1 $turn
	 }
	 return -code error cancel
      }
      choose_register
      ::speaker::most_recent $ids
      # Check if overlapping state changed
      if {$turn != "" && $ovl != $ini_ovl} {
	 if {$ovl} {
	    DoWho $turn
	 } else {
	    NoWho $turn
	 }
      }
      return [list $ids $mod $fid $cha]
   }

   proc choose_register {} {
      variable id1
      variable nam
      variable chk
      variable exp
      variable typ
      variable dia
      variable acc
      variable pos
      variable ids
      variable ovl
      variable state

# added by Zhibiao
      variable role
      variable age 
      variable birth
      variable education
      variable group
      variable language
      variable ses 
      variable sex 

      if {$state == "new"} {
	if {$::v(chatMode)} {
	  set id1 [::speaker::create $nam $chk $typ $dia $acc $exp $role $age $birth $education $group $language $ses $sex]
	} else {
	  set id1 [::speaker::create $nam $chk $typ $dia $acc $exp]
	}
      } elseif {$state == "edit"} {
	 set id [::speaker::search_id $nam]
	 if {$id != "" && $id != $id1} {
	    set answer [tk_messageBox -message "Speaker $nam already exists. Replace [::speaker::name $id1] with $nam everywhere?" -type yesno -icon question]
	    if {$answer == "yes"} {
	       ::speaker::replace $id1 $id
	    }
	    set id1 $id
	 } else {
	   if {$::v(chatMode)} {
	     ::speaker::set_atts $id1 [list $nam $chk $typ $dia $acc $exp $role $age $birth $education $group $language $ses $sex]
	   } else {
	     ::speaker::set_atts $id1 [list $nam $chk $typ $dia $acc $exp]
	   }
	 }
      }
      if {$id1 == ""} {
	 if {$ovl} {
	    set pos [expr 1-$pos]
	    set ovl 0
	    catch {choose_overlap}
	 } else {
	    set ids [lreplace $ids $pos $pos]
	 }
      } else {
	 set ids [lreplace $ids $pos $pos $id1]
      }
   }

   proc choose_overlap {} {
      variable ovl
      variable pos
      variable newpos
      variable ids
      variable id1

      if {$ovl} {
	 pack .turn.top.1 .turn.top.2 -side left -anchor w -padx 3m -pady 3m -expand true
	 if {$ids == ""} {
	    lappend ids ""
	 }
	 if {[llength $ids] <= 1} {
	    choose_register
	    lappend ids [::speaker::second_one $ids]
	    set newpos 1
	    choose_switch
	 }	 
      } else {
	 pack forget .turn.top.1 .turn.top.2
	 if {[llength $ids] > 1} {
	    set ids [lindex $ids $pos]
	    set newpos 0
	    choose_switch
	 }
      }
   }

   proc choose_switch {} {
      variable id1
      variable pos
      variable newpos
      variable ids

      set pos $newpos
      set id1 [lindex $ids $pos]
      choose_recent $id1
   }

   proc choose_new {} {
      variable id1 ""
      variable nam ""
      variable chk "no"
      variable exp "local"
      variable typ ""
      variable dia "native"
      variable acc ""

      variable state "new"
      variable edit

# added by Zhibiao
      variable role
      variable age 
      variable birth
      variable education
      variable group
      variable language
      variable ses 
      variable sex 

      $edit conf -state disabled

      variable lst
      $lst selection clear 0 end
      variable watt
      FrameState $watt 1
      #foreach w {nam.ent typ.men chk dia.men} {
      #  FrameState $watt.$w 1
      #}
      variable ent
      variable ::speaker::nb
      $ent insert insert "speaker\#$nb"
      $ent select range 0 end
      focus $ent
   }

   proc choose_lst {} {
      variable lst
      set id [::speaker::search_id [$lst get [$lst curselection]]]
      choose_id $id
   }

   proc choose_empty {} {
      choose_recent ""
   }

   proc choose_recent {id} {
      variable lst
      if {$id != ""} {
	 set index [lsearch [::speaker::all_names] [::speaker::name $id]]
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
      variable chk ""
      variable exp
      variable typ ""
      variable dia ""
      variable acc ""
      variable state "choose"
      variable edit

# added by zhibiao
      variable role ""
      variable age 
      variable birth
      variable education
      variable group
      variable language
      variable ses 
      variable sex 
# added end

      if {$id != ""} {
	if {$::v(chatMode)} {
	  foreach {nam chk typ dia acc exp role age birth education group language ses sex} [::speaker::get_atts $id] {}
	} else {
	  foreach {nam chk typ dia acc exp} [::speaker::get_atts $id] {}
	}
	 $edit conf -state normal
      } else {
	 $edit conf -state disabled
      }
      variable watt
      FrameState $watt 0
      #foreach w {nam.ent typ.men chk dia.men} {
      #  FrameState $watt.$w 0
      #}
   }
}
