# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################
# Check spelling

proc SpellChecking {} {
   global v

   OpenIspell

   if ![info exists v(tk,edit)] return
   set t $v(tk,edit)
   if {[${t}-bis tag ranges sel] != ""} {
      $t mark set insert "sel.first wordstart"
      set v(spell,end) [$t index "sel.last"]
   } else {
      $t mark set insert "insert wordstart"
      set v(spell,end) "end"
   }
   set v(spell,count) 0
   SpellWindow
   SpellLoop
}

# main spelling loop
# stops when : 
#   - end of document or selection reached (closes things)
#   - badly spelled word detected (waits for user action before proceeding)

proc SpellLoop {} {
   global v

   # for default behaviour of Return keypress
   SpellNoDefault
   catch {unset v(spell,new)}

   set t $v(tk,edit)
   set skip 0
   while {1} {
      set pos [${t}-bis search -regexp -count cnt -- "\[-'()0-9A-Za-z\xc0-\xd6\xd8-\xf6\xf8-\xff]+" insert $v(spell,end)]
      ${t}-bis tag remove spell 0.0 end
      if {$pos == ""} {
	 $t mark set insert "insert"
	 SpellClose
	 tk_messageBox -type ok -icon info -message [format [Local "%s word(s) checked"] $v(spell,count)]
	 return
      }
      ${t}-bis mark set insert "$pos + $cnt chars"

      # skip foreign words
      set wrd [$t-bis get $pos insert]
      set tags [$t tag names $pos]
      set elem [lindex $tags [lsearch -glob $tags "*element*"]]
      if {$elem != ""} {
	 if {[$elem getType] == "Event" 
	     && [$elem getAttr "type"] == "language"} {
	    switch [$elem getAttr "extent"] {
	       "begin" {set skip -1}
	       "end"   {set skip 0}
	       "next"  {set skip 1}
	    }
	 }
	 ${t}-bis mark set insert "$elem.last"
	 continue
      }
      set tags [$t tag names insert+3c]
      set elem [lindex $tags [lsearch -glob $tags "*element*"]]
      if {$elem != "" && [$elem getType] == "Event" 
	  && [$elem getAttr "type"] == "language"
	  && [$elem getAttr "extent"] == "previous"} {
	 set skip 1
      }
      if {$skip} {
	 incr skip -1
	 continue
      }
      
      # skip numbers-only (but acronyms containing numbers are verified)
      if {[string trim $wrd "0123456789-"] == ""} continue

      # skip words containing parenthesis
      if {[regexp {\(|\)} $wrd]} continue

      # skip frequent French or Italian words with apostrophe
      set FrenchApostr "c|d|j|l|m|n|qu|s|t|ç|jusqu|lorsqu|puisqu"
      set ItalianApostr "l|dell|all|d|un|c|nell|dall|sull|s|quest|quell|com|anch|tutt|n|vent|mezz|trent|sant|dov|cos|senz|dev|m|cinquant|quarant|tant|bell|quand|gliel|nient|cent|quant|ventiquattr|sessant|del|sott|settant|t|ch|qualcos|v|nel|gl|ottant|nessun|quattr|prim|terz|quart|novant|null|foss|buon|fors|degl|grand|al|quarantott|il|diciott|ultim|second|coll|pover|pier|quint|neanch|brav|altr"

      if {($v(spell,lang) == "french" && [regexp "^($FrenchApostr)'(.*)" $wrd all art wrd]) || ($v(spell,lang) == "italian" && [regexp "^($ItalianApostr)'(.*)" $wrd all art wrd])} {
         set l [expr [string length $art]+1]
         set pos [${t}-bis index "$pos + $l chars"]
         if {$wrd == ""} continue
      }

      # highlight current word
      ${t}-bis tag add spell $pos insert
      ${t}-bis tag conf spell -background $v(color,bg-turn)

      # skip proper names if asked
      if {!$v(spell,names) && [regexp "^\[A-Z]" $wrd]} continue

      if {$wrd != ""} {
	 incr v(spell,count)
	 # just to see from time to time where we are
	 if {[expr $v(spell,count) % 50] == 0} {
	    ${t}-bis see insert
	    update idle
	 }
	 # let user choose to keep/modify unknown word
	 if {![SpellOneWrd $wrd]} {

	    # Accept any concatenation of existing words.
	    set lst [split $wrd "-"]
	    if {[llength $lst] > 1} {
	       set ok 1
	       foreach subwrd $lst {
		  if {![SpellOneWrd $subwrd]} {
		     set ok 0
		  }
	       }
	       if {$ok} continue
	    }

	    $t mark set insert "insert"
	    set v(spell,wrd) $wrd
	    set v(spell,new) $wrd
	    SpellUpdate
	    return
	 }
      }
   }
}

proc SpellUpdate {} {
   global v

   $v(spell,lst) delete 0 end
   eval $v(spell,lst) insert end $v(spell,miss)

   # select entry
   $v(spell,ent) selection range 0 end
   $v(spell,ent) icursor end
   focus $v(spell,ent)
   
   # default behaviour for Return
   SpellNoDefault
   trace variable v(spell,new) w {SpellDefaultReplace}
}

proc SpellWindow {} {
   global v

   set w .spell
   if ![winfo exists $w] {
      toplevel $w
      wm title $w [Local "Spell checking"]
      wm protocol $w WM_DELETE_WINDOW { SpellClose }

      frame $w.left -relief raised -bd 1

      set v(spell,ent) [EntryFrame $w.left.wrd "Word" v(spell,new)]
      #$w....lab conf -width 10 -anchor w

      set v(spell,lst) [ListFrame $w.left.lst ""]
      $v(spell,lst) conf -height 6
      bind $v(spell,lst) <ButtonRelease-1> SpellChooseGuess

      frame $w.but -relief raised -bd 1
      button $w.but.add -text [Local "Add to dictionnary"] -command SpellAccept
      button $w.but.ignore -text [Local "Ignore"] -command SpellIgnore
      button $w.but.replace -text [Local "Replace"] -command SpellReplace
      button $w.but.close -text [Local "Close"] -command SpellClose
      pack $w.but.add $w.but.ignore $w.but.replace $w.but.close -side top \
	  -fill x -expand 1 -padx 2m -pady 1m

      #button $w.but.close -text "Close" -command [list wm withdraw $w]
      #pack $w.but.next $w.but.repl $w.but.repa $w.but.close -side left \
	\#  -expand 1 -padx 2m -pady 1m

      pack $w.left $w.but -side left -fill both -expand true
      focus $v(spell,ent)
      bind $w <Escape> "tkButtonInvoke $w.but.close"
   } else {
      wm withdraw $w
      wm deiconify $w
   }
}

# Management of default behaviour for Return keypress
proc SpellNoDefault {args} {
   global v

   set w .spell
   catch {
      $w.but.replace conf -default normal
      bind $w <Return> {break}
   }
}

proc SpellDefaultReplace {args} {
   global v

   set w .spell
   $w.but.replace conf -default active
   bind $w <Return> "tkButtonInvoke $w.but.replace"
}

# Click in list of misses
proc SpellChooseGuess {} {
   global v

   set idx [$v(spell,lst) curselection]
   if {$idx == ""} return
   set v(spell,new) [$v(spell,lst) get $idx]
   # select entry
   $v(spell,ent) selection range 0 end
   $v(spell,ent) icursor end
}

# Click on one button: Add to dictionary / Ignore /  Replace
proc SpellAccept {} {
   global v

   puts $v(spell) "*$v(spell,wrd)"
   SpellLoop
}

proc SpellIgnore {} {
   global v

   #puts $v(spell) "@$v(spell,wrd)"
   SpellLoop
}

proc SpellReplace {} {
   global v

   if {$v(spell,new) != $v(spell,wrd)} {
      set t $v(tk,edit)
      if {[$t-bis tag ranges spell] != ""} {
	 set str [$t-bis get spell.first spell.last]
	 if {$str == $v(spell,wrd)} {
	    $t mark set insert "spell.last"
	    $t insert insert $v(spell,new)
	    # move cursor so that we re-test word after modification
	    $t mark set insert "spell.last"
	    $t delete "spell.first" "spell.last"
	 }
      }
   }
   SpellLoop
}

# Close ispell and withdraw spell-checking window
proc SpellClose {} {
   global v

   CloseIspell
   $v(tk,edit)-bis tag remove spell 0.0 end
   catch {wm withdraw .spell}
}

# Check one word via ispell
# Output: 1 if OK, 0 if wrong => word lists in v(spell,miss) / v(spell,guess)
# called by SpellLoop
proc SpellOneWrd {wrd} {
   global v

   set wrd [string trim $wrd -']
   if {$wrd == ""} {
      return 1
   }

   # get ispell answer
   puts $v(spell) $wrd
   set ans [gets $v(spell)]
   gets $v(spell)

   # analyze ispell answer
   set ok 1
   set count 0
   set v(spell,miss) {}
   set v(spell,guess) {}
   switch [string range $ans 0 0] {
      "*" - "+" - "-" {
      }
      "&" - "?" {
	 set ok 0
	 set count [lindex $ans 2]
	 set lst [split [lindex [split $ans ":"] 1] ","]
	 foreach w [lrange $lst 0 [expr $count-1]] {
	    lappend v(spell,miss) [string trim $w]
	 }
	 foreach w [lrange $lst $count end] {
	    lappend v(spell,guess) [string trim $w]
	 }
      }
      "\#" {
	 set ok 0
      }
      default {
	 error "Unrecognized ispell answer '$ans'"
      }
   }
   # always accept guesses ?
   if {[llength $v(spell,guess)] > 0} {
      #puts "$wrd guessed by $v(spell,guess)"
      set ok 1
   }
   return $ok
}

# Open ispell as a subprocess
# Choice of dictionary name not very robust; should be at user option ?
# Called by SpellOne
proc OpenIspell {} {
   global v

   if {![info exists v(spell)]} {

      # Choose document language, else interface language.
      set lang [$v(trans,root) getAttr xml:lang]
      if {$lang == ""} {
	 set lang $v(lang)
      }
      catch {set lang $::iso639($lang)}
      set lang [string tolower $lang]
      # special test for english
      # a table [iso639] -> [ispell dictionary names] would be useful here
      if {$lang == "english"} {
	 set lang "american"
      } elseif {$lang == ""} {
	 set lang "default"
      }

      if {[catch {
	 set chan [open "| ispell -a -d $lang" w+]
      }]} {
	 tk_messageBox -type ok -icon error -message [Local "Sorry, couldn't launch spell checker"]\n($err)
	 return -code return
      }
      fconfigure $chan -buffering line
      if {[gets $chan res] < 0} {
	 catch {close $chan} err
	 tk_messageBox -type ok -icon error -message [format [Local "Sorry, couldn't find %s dictionary"] $lang]\n($err)
	 return -code return
      }
      set v(spell) $chan
      set v(spell,lang) $lang
   }
}

proc CloseIspell {} {
   global v

   # save dictionnary before leaving
   if {[info exists v(spell)]} {
      puts $v(spell) "\#"
      close $v(spell)
      unset v(spell)
   }
}
