# When OS is Linux and the Arabic fonts are not installed, copy the fonts to /tmp
# and set font path to /tmp/
if {$::tcl_platform(os) == "Linux"} {
    if { [catch { exec xset fp+ [file join [pwd] [file dir [info script]]]} result]} {
	file copy -force [file join $v(path,arabic) "fonts.dir"] "/tmp/"
	file copy -force [file join $v(path,arabic) "fonts.alias"] "/tmp/"
	file copy -force [file join $v(path,arabic) "unifont.bdf"] "/tmp/"
	file copy -force [file join $v(path,arabic) "yarb20_uni.bdf"] "/tmp/"
	exec xset fp+ "/tmp"
       }
}
 wm title . "[wm title .] Arabic"

# 
foreach subl {{`a à} {^a â} {`e è} {^e ê} {^i î} {^o ô} {^u û} {`u ù} {ae æ} {,c ç}} {
   foreach {s1 s2} $subl {}
   bind Entry $s1 "tkEntryBackspace %W; tkEntryInsert %W [list $s2]; break"
   }
bind Entry <diaeresis><i> "tkEntryBackspace %W; tkEntryInsert %W ï; break"
bind Entry <diaeresis><e> "tkEntryBackspace %W; tkEntryInsert %W ë; break"
bind Entry <diaeresis><u> "tkEntryBackspace %W; tkEntryInsert %W ü; break"

proc InitEpisode {} {
   global v

   $v(trans,root) setAttr "scribe" $v(scribe,name)
   $v(trans,root) setAttr "xml:lang" "ar"
   UpdateFilename
   set v(trans,version) 0
   UpdateVersion
}

proc InitArabBind {} {
   global v

   set v(event,begin)     "\[-%s]"
   set v(event,end)       "\[%s-]"
   set v(event,previous)  "\[%s]+"
   set v(event,next)      "+\[%s]"

   foreach c {"," ";" "." ".." ":"} {
      bind $v(tk,edit) $c {}
   }

   foreach codes {
      {asciitilde ~} {Key-1 !} {Key-2 \xbb} {Key-3 \xab} {Key-4 } {Key-5 %%} {Key-6 ^} {Key-7 \\} {Key-8 *} {Key-9 \)} {Key-0 \(} {degree aA} {plus iy} {mu uw}
      {twosuperior g} {ampersand 1} {eacute 2} {quotedbl 3} {apostrophe 4} {parenleft 5} {minus 6} {egrave 7} {underscore 8} {ccedilla 9} {agrave 0} {parenright -}
      {A a} {Z F} {E u} {R N} {T li<i} {Y <i} {U \{lo>u} {I \{lo<i} {O \{lo>a} {P ;} {diaeresis Q} {sterling G}
      {a D} {z S} {e v} {r q} {t f}  {y J} {u c}     {i h}     {o x}    {p H} {asciicircum j} {dollar d}
      {Q i} {S K} {D  } {F P} {G li>a} {H >} {J _} {K ,} {L  } {M :} {percent \"}
      {q $} {s s} {d y} {f b} {g l}  {h A} {j t} {k n} {l m} {m k} {ugrave T}
      {greater Aalo} {W \{lo|} {X o} {C  } {V V} {B lo|} {N |} {question \{} {period @} {slash .} {section ?}
      {less    \{lo} {w \}}   {x '} {c &} {v r} {b laA} {n Y} {comma p} {semicolon w} {colon z} {exclam Z}
   } {
      foreach {s1 s2} $codes {}
      if {[string length $s2] > 0} {
	 bind $v(tk,edit) "<$s1>" "%W insert insert [list $s2]; break"
      } else {
	 bind $v(tk,edit) "<$s1>" "break"
      }
      # other bindings unchanged
      bind $v(tk,edit) "<Control-$s1>" { continue }
      bind $v(tk,edit) "<Alt-$s1>" { continue }
   }

   # Special Alt-* codes
   foreach codes {
      {a ~a} {z ~F} {e ~u} {r ~N} {q ~i} {s ~K}
   } {
      foreach {s1 s2} $codes {}
      bind $v(tk,edit) "<Alt-$s1>" "%W insert insert [list $s2]; break"
   }

   bind $v(tk,edit) <Up>   {tkTextSetCursor %W "insert-1l"; tkTextSetCursor %W "insert linestart"; break }
   bind $v(tk,edit) <Down> {tkTextSetCursor %W "insert+1l"; tkTextSetCursor %W "insert linestart"; break }
   # Switch Home/End
   bind $v(tk,edit) <Key-End> {tkTextSetCursor %W {insert linestart}; break }
   bind $v(tk,edit) <Key-Home> {tkTextSetCursor %W {insert lineend}; break }
   bind $v(tk,edit) <Shift-End> {tkTextKeySelect %W {insert linestart}; break }
   bind $v(tk,edit) <Shift-Home> {tkTextKeySelect %W {insert lineend}; break }
   bind $v(tk,edit) <Control-Home> { continue }
   bind $v(tk,edit) <Control-End> { continue }
     
   # Switch Backspace <-> Delete
   bind $v(tk,edit) <Key-Delete> {
      if {[%W tag nextrange sel 1.0 end] != ""} {
	 %W delete sel.first sel.last
      } elseif [%W compare insert != 1.0] {
	 %W delete insert-1c
	 %W see insert
      }
      break
   }
   bind $v(tk,edit) <Key-BackSpace> {
      if {[%W tag nextrange sel 1.0 end] != ""} {
	 %W delete sel.first sel.last
      } else {
	 %W delete insert
	 %W see insert
      }
      break
   }

   # Other bindings unchanged
   bind $v(tk,edit) <Shift-BackSpace> { continue }
}

proc InitArabMap {} {
   global glyph key type

   # no default type
   for {set i 0} {$i < 256} {incr i} {
      set type([format "%c" $i]) ""
   }
   set type() ""

   # consonants/contextual chars
   # name / key / isolated / start / middle / end / context-flag
   set cons_map {
      {"alif mamdouda" "\|" "\u0622" "\u0622" "\ufe82" "\ufe82" "l"}
      {"hamza-a/u"        ">" "\u0623" "\u0623" "\ufe84" "\ufe84" "l"}
      {"u-hamza"        "&" "\u0624" "\u0624" "\ufe86" "\ufe86" "l"}
      {"hamza-i"        "<" "\u0625" "\u0625" "\ufe88" "\ufe88" "l"}
      {"i-hamza"       "\}" "\u0626" "\ufe8b" "\ufe8c" "\ufe8a"}
      {"'alif"                "A" "\u0627" "\u0627" "\ufe8e" "\ufe8e" "l"}
      {"ba'"                "b" "\u0628" "\ufe91" "\ufe92" "\ufe90"}
      {"ta' marbuta"        "p" "\u0629" "\u0629" "\ufe94" "\ufe94" "l"}
      {"ta' maftuha"        "t" "\u062a" "\ufe97" "\ufe98" "\ufe96"}
      {"tha'"                "v" "\u062b" "\ufe9b" "\ufe9c" "\ufe9a"}
      {"jim"                "j" "\u062c" "\ufe9f" "\ufea0" "\ufe9e"}
      {"hha'"                "H" "\u062d" "\ufea3" "\ufea4" "\ufea2"}
      {"kha'"                "x" "\u062e" "\ufea7" "\ufea8" "\ufea6"}
      {"dal"                "d" "\u062f" "\u062f" "\ufeaa" "\ufeaa" "l"}
      {"dhal"                "g" "\u0630" "\u0630" "\ufeac" "\ufeac" "l"}
      {"ra'"                "r" "\u0631" "\u0631" "\ufeae" "\ufeae" "l"}
      {"zay"                "z" "\u0632" "\u0632" "\ufeb0" "\ufeb0" "l"}
      {"sin"                "s" "\u0633" "\ufeb3" "\ufeb4" "\ufeb2"}
      {"shin"                "$" "\u0634" "\ufeb7" "\ufeb8" "\ufeb6"}
      {"sad"                "S" "\u0635" "\ufebb" "\ufebc" "\ufeba"}
      {"ddad"                "D" "\u0636" "\ufebf" "\ufec0" "\ufebe"}
      {"tta'"                "T" "\u0637" "\ufec3" "\ufec4" "\ufec2"}
      {"zza'"                "Z" "\u0638" "\ufec7" "\ufec8" "\ufec6"}
      {"ayn"                "c" "\u0639" "\ufecb" "\ufecc" "\ufeca"}
      {"gayn"                "J" "\u063a" "\ufecf" "\ufed0" "\ufece"}
      {"kashida"        "_" "\u0640" "\u0640" "\u0640" "\u0640"}
      {"fa'"                "f" "\u0641" "\ufed3" "\ufed4" "\ufed2"}
      {"qaf"                "q" "\u0642" "\ufed7" "\ufed8" "\ufed6"}
      {"kaf"                "k" "\u0643" "\ufedb" "\ufedc" "\ufeda"}
      {"lam"                "l" "\u0644" "\ufedf" "\ufee0" "\ufede"}
      {"mim"                "m" "\u0645" "\ufee3" "\ufee4" "\ufee2"}
      {"nun"                "n" "\u0646" "\ufee7" "\ufee8" "\ufee6"}
      {"ha'"                "h" "\u0647" "\ufeeb" "\ufeec" "\ufeea"}
      {"waw"                "w" "\u0648" "\u0648" "\ufeee" "\ufeee" "l"}
      {"alif maksoura"        "Y" "\u0649" "\u0649" "\ufef0" "\ufef0" "l"}
      {"ya'"                "y" "\u064a" "\ufef3" "\ufef4" "\ufef2"}

      {"alif wasla"        "\{" "\u0671" "\u0671" "\ufb51" "\ufb51" "l"}
      {""                "P" "\u067e" "\ufb58" "\ufb59" "\ufb57"}
      {""                "Q" "\u0686" "\ufb7c" "\ufb7d" "\ufb7b"}
      {""                "G" "\u06af" "\ufb94" "\ufb95" "\ufb93"}
      {""                "V" "\u06a4" "\ufb6c" "\ufb6d" "\ufb6b"}

      {"lam+alif"        "lA" "\ufefb" "\ufefb" "\ufefc" "\ufefc" "l"}
      {"lam+alif hamza"        "l<" "\ufef9" "\ufef9" "\ufefa" "\ufefa" "l"}
      {"lam+alif hamza"        "l>" "\ufef7" "\ufef7" "\ufef8" "\ufef8" "l"}
      {"lam+alif madda"        "l|" "\ufef5" "\ufef5" "\ufef6" "\ufef6" "l"}
   }   

   foreach c $cons_map {
      foreach {name k isol start middle end ctx} $c {}
      set glyph($k,0,0) $isol
      set glyph($k,0,1) $start
      set glyph($k,1,1) $middle
      set glyph($k,1,0) $end
      foreach g [list $isol $start $middle $end] {
	 set key($g) $k
      }
      set type($k) "C$ctx"
   }

   # vowels/diacritics/zero-length chars
   set vow_map {
      "tanwin:an"  "F" "\u064b"
      "tanwin:un"  "N" "\u064c"
      "tanwin:in"  "K" "\u064d"
      "a"          "a" "\u064e"
      "ou"         "u" "\u064f"
      "i"          "i" "\u0650"
      "tachdid"    "~" "\u0651"
      "soukoun"    "o" "\u0652"
   }

   foreach {name k g} $vow_map {
      set glyph($k) $g
      set key($g) $k
      set type($k) "V"
   }

   # spaces/isolated chars - most map to the identity
   set iso_map {
      "'" "\u0621"
      "\t" "\t"
      "\n" "\n"
      " " " " 
      "!" "!"
      \"  \"
      "%" "\u066a"
      "(" ")"
      ")" "("
      "*" "\u066d"
      "," "\u060c"
      "-" "-"
      "." "."
      "/" "\\"
      "0" "\u0660"
      "1" "\u0661"
      "2" "\u0662"
      "3" "\u0663"
      "4" "\u0664"
      "5" "\u0665"
      "6" "\u0666"
      "7" "\u0667"
      "8" "\u0668"
      "9" "\u0669"
      ":" ":"
      ";" "\u061b"
      "?" "\u061f"
      "@" "@"
      "[" "]"
      "]" "["
      "^" "^"
      \\  "/"
      "\xab" "\xab"
      "\xbb" "\xbb"
   }

   foreach {k g} $iso_map {
      set glyph($k) $g
      set key($g) $k
      set type($k) "S"
   }
}

proc ConvertFromGlyph {s} {
   global glyph key type
   set res ""
   for {set i 0} {$i < [string length $s]} {incr i} {
      set curr [string index $s $i]
      catch {
	 set res $key($curr)$res
      }
   }
   return $res
}

proc LContext {c} {
   global glyph key type
   
   if {[string match "C*" $type($c)] && $type($c)!="Cr"} {
      return 1
   } else {
      return 0
   }
}

proc RContext {c} {
   global glyph key type
   
   if {[string match "C*" $type($c)] && $type($c)!="Cl"} {
      return 1
   } else {
      return 0
   }
}

# Convert transliterated string (without \n) to glyph string.
# (context chars can be given with $before and $after, but it defaults 
# to an isolated context)
proc ConvertToGlyph {s {before ""} {after ""} {legalname ""} {novowname ""}} {
   global glyph key type

   # filtered strings (known chars with/out vowels)
   if {$legalname != ""} {
      upvar $legalname legal
   }
   set legal ""
   if {$novowname != ""} {
      upvar $novowname novow
   }
   set novow ""

   set res ""
   for {set i 0} {$i < [string length $s]} {incr i} {
      set curr [string index $s $i]
      set next [string index $s [expr $i+1]]
      # fold ligatures
      if {$next != "" && [info exists type($curr$next)]} {
	 append curr $next
	 incr i
	 set next [string index $s [expr $i+1]]
      }
      # get next char (skip diacritics)
      for {set j 2} {$type($next) == "V"} {incr j} {
	 set next [string index $s [expr $i+$j]]
      }
      if {$next == ""} {
	 set next $after
      }
      if {$type($curr) == ""} continue
      switch -glob -- $type($curr) {
	 "C*" {
	    set res $glyph($curr,[RContext $before],[LContext $next])$res
	    set before $curr
	    append novow $curr
	 }
	 "S" {
	    set res $glyph($curr)$res
	    set before $curr
	    append novow $curr
	 }
	 "V" {
	    set res $glyph($curr)$res
	 }
      }
      append legal $curr
   }
   return $res
}

proc InsertString {e s} {
   $e insert insert [ConvertToGlyph $s] "arabic"
}

# look for chars around starting index $start in $e text widget,
# ignoring vowels or diacritics.
# return transliterated keycodes in kname array
# and index positions in idxname array
# (used in InsertChars / DeleteChars)
proc GetContext {e start kname idxname} {
   global glyph key type
   upvar $kname k $idxname idx

   # Get context
   foreach {dir i} {- 1 + 0} {
      for {set j 1} {$j < 3} {incr i} {
	 set l " "
	 set pos [$e index "$start $dir $i c"]
	 if {($dir == "+" && [$e compare $pos < "$start lineend"])
	     || ($dir == "-" && [$e compare $pos >= "$start linestart"] 
	     && [$e compare $pos != "$start-[expr $i-1]c"])} {
	    catch {
	       set l $key([$e get $pos])
	       # non-arabic chars are not contextual
	       if {[lsearch -exact [$e tag names $pos] "arabic"] < 0} {
		  set l " "
	       }
	    }
	 }
	 if {$type($l) != "V"} {
	    set k($dir$j) $l
	    set idx($dir$j) $pos
	    incr j
	 }
      }
   }
}

# change glyph at given position (without moving insert mark)
proc ChangeChar {e pos char before after} {
   global glyph key type

   if {[string match "C*" $type($char)]} {
      set ins [$e index "insert"]
      set oldtags [$e tag names $pos]
      $e delete $pos
      $e insert $pos \
	  $glyph($char,[RContext $before],[LContext $after]) $oldtags
      $e mark set "insert" $ins
   }
}

# Insert a transliterated string as arabic glyphs into text widget
# - insert only at insert mark
# - upon newline, chars to the left of insert mark loose their original
#   tagging and get the new one ("arabic" + specified ones)
proc InsertArabChars {e s {tags ""}} {
   global glyph key type

   lappend tags "arabic"

   # Detect ligatures (best handled in 'ConvertGlyph')
   catch {
      set a $key([$e get insert])
      set b [string index $s 0]
      if {$a != "" && $b != "" && [info exists type($a$b)]} {
	 $e delete insert
	 set s "$a$s"
      }
   }
   catch {
      set c [string index $s [expr [string length $s]-1]]
      set d $key([$e get "insert-1c"])
      if {$c != "" && $d != "" && [info exists type($c$d)]} {
	 $e delete "insert-1c"
	 set s "$s$d"
      }
   }
   
   # Get context
   GetContext $e "insert" k idx
   #puts "'$k(+2)$k(+1)*$k(-1)$k(-2)'"

   # Convert chars to glyphs; leave if all chars unknown
   set glf [ConvertToGlyph $s $k(+1) $k(-1) s novow]
   if {$glf == ""} return

   # Don't change context for vowels
   if {$novow != ""} {
      # Check if context changed for left char
      set c1 [string index $novow [expr [string length $novow]-1]]
      if {$type($k(+1)) != $type($c1)} {
	 ChangeChar $e $idx(-1) $k(-1) $c1 $k(-2)
      }
      # Check if context changed for right char
      set c0 [string index $novow 0]
      if {$type($k(-1)) != $type($c0)} {
	 ChangeChar $e $idx(+1) $k(+1) $k(+2) $c0
      }
   }

   $e mark gravity "insert" left

   # insert glyph string with special behaviour for Return
   set glf [split $glf "\n"]
   for {set i [expr [llength $glf]-1]} {$i>=0} {incr i -1} {
      # insert chars
      $e insert "insert" [lindex $glf $i] $tags
      # insert \n except for last line
      if {$i > 0} {
	 #puts "Passe par ici"
	 set new [$e get "insert" "insert lineend"]
	 $e delete "insert" "insert lineend"
	 $e mark gravity insert right
	 $e insert "insert linestart" "$new\n" $tags
	 $e mark gravity insert left
      }
   }
   $e mark gravity "insert" right

}
 
proc DeleteArabChars {e start {end ""}} {
   global glyph key type

   # keep real index for the sel.* case
   set start [$e index $start]
   eval $e delete $start $end

   # Get context
   GetContext $e $start k idx

   # update left and right chars
   ChangeChar $e $idx(-1) $k(-1) $k(+1) $k(-2)
   ChangeChar $e $idx(+1) $k(+1) $k(+2) $k(-1)
}

InitArabBind
InitArabMap
