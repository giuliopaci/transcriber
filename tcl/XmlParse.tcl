#!/bin/sh
#\
exec tclsh "$0" "$@"

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)
# WWW:          http://www.etca.fr/CTA/gip/Projets/Transcriber/Index.html
# Author:       Claude Barras

################################################################

# Lexical parser for XML

namespace eval ::xml::parser {

   ####### Variables for parsing (regexps, rules)

   # Values shared with other parts of parser

   # Detect Unicode support (Tcl/Tk 8.1 or higher)
   variable i18n [expr ![catch {encoding system}]]

   # Initialize rules and conditions for lexers
   set rules {}
   set conds {} 

   #=======================================================================
   # Regular expressions for XML parsing with tcLex
   # Reference: http://www.w3.org/TR/1998/REC-xml-19980210
   
   #-----------------------------------------------------------------------
   # B - Character Classes
   # Restricted to ISO-Latin-1 for Tcl8.0;
   # Support of Unicode (UTF-8) for Tcl8.1 or higher

   if {$i18n} {
      variable BaseChar "\u0041-\u005A\u0061-\u007A\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u00FF\u0100-\u0131\u0134-\u013E\u0141-\u0148\u014A-\u017E\u0180-\u01C3\u01CD-\u01F0\u01F4-\u01F5\u01FA-\u0217\u0250-\u02A8\u02BB-\u02C1\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03CE\u03D0-\u03D6\u03DA\u03DC\u03DE\u03E0\u03E2-\u03F3\u0401-\u040C\u040E-\u044F\u0451-\u045C\u045E-\u0481\u0490-\u04C4\u04C7-\u04C8\u04CB-\u04CC\u04D0-\u04EB\u04EE-\u04F5\u04F8-\u04F9\u0531-\u0556\u0559\u0561-\u0586\u05D0-\u05EA\u05F0-\u05F2\u0621-\u063A\u0641-\u064A\u0671-\u06B7\u06BA-\u06BE\u06C0-\u06CE\u06D0-\u06D3\u06D5\u06E5-\u06E6\u0905-\u0939\u093D\u0958-\u0961\u0985-\u098C\u098F-\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\\u09B6-\u09B9\u09DC-\u09DD\u09DF-\u09E1\u09F0-\u09F1\u0A05-\u0A0A\u0A0F-\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32-\u0A33\u0A35-\u0A36\u0A38-\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8B\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2-\u0AB3\u0AB5-\u0AB9\u0ABD\u0AE0\u0B05-\u0B0C\u0B0F-\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32-\u0B33\u0B36-\u0B39\u0B3D\u0B5C-\u0B5D\u0B5F-\u0B61\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99-\u0B9A\u0B9C\u0B9E-\u0B9F\u0BA3-\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB5\u0BB7-\u0BB9\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C33\u0C35-\u0C39\u0C60-\u0C61\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CDE\u0CE0-\u0CE1\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D28\u0D2A-\u0D39\u0D60-\u0D61\u0E01-\u0E2E\u0E30\u0E32-\u0E33\u0E40-\u0E45\u0E81-\u0E82\u0E84\u0E87-\u0E88\u0E8A\u0E8D\u0E94-\u0E97\u0E99-\u0E9F\u0EA1-\u0EA3\u0EA5\u0EA7\u0EAA-\u0EAB\u0EAD-\u0EAE\u0EB0\u0EB2-\u0EB3\u0EBD\u0EC0-\u0EC4\u0F40-\u0F47\u0F49-\u0F69\u10A0-\u10C5\u10D0-\u10F6\u1100\u1102-\u1103\u1105-\u1107\u1109\u110B-\u110C\u110E-\u1112\u113C\u113E\u1140\u114C\u114E\u1150\u1154-\u1155\u1159\u115F-\u1161\u1163\u1165\u1167\u1169\u116D-\u116E\u1172-\u1173\u1175\u119E\u11A8\u11AB\u11AE-\u11AF\u11B7-\u11B8\u11BA\u11BC-\u11C2\u11EB\u11F0\u11F9\u1E00-\u1E9B\u1EA0-\u1EF9\u1F00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2126\u212A-\u212B\u212E\u2180-\u2182\u3041-\u3094\u30A1-\u30FA\u3105-\u312C\uAC00-\uD7A3"; # [85]

      variable Ideographic "\u4E00-\u9FA5\u3007\u3021-\u3029"; # [86]

      variable CombiningChar "\u0300-\u0345\u0360-\u0361\u0483-\u0486\u0591-\u05A1\u05A3-\u05B9\u05BB-\u05BD\u05BF\u05C1-\u05C2\u05C4\u064B-\u0652\u0670\u06D6-\u06DC\u06DD-\u06DF\u06E0-\u06E4\u06E7-\u06E8\u06EA-\u06ED\u0901-\u0903\u093C\u093E-\u094C\u094D\u0951-\u0954\u0962-\u0963\u0981-\u0983\u09BC\u09BE\u09BF\u09C0-\u09C4\u09C7-\u09C8\u09CB-\u09CD\u09D7\u09E2-\u09E3\u0A02\u0A3C\u0A3E\u0A3F\u0A40-\u0A42\u0A47-\u0A48\u0A4B-\u0A4D\u0A70-\u0A71\u0A81-\u0A83\u0ABC\u0ABE-\u0AC5\u0AC7-\u0AC9\u0ACB-\u0ACD\u0B01-\u0B03\u0B3C\u0B3E-\u0B43\u0B47-\u0B48\u0B4B-\u0B4D\u0B56-\u0B57\u0B82-\u0B83\u0BBE-\u0BC2\u0BC6-\u0BC8\u0BCA-\u0BCD\u0BD7\u0C01-\u0C03\u0C3E-\u0C44\u0C46-\u0C48\u0C4A-\u0C4D\u0C55-\u0C56\u0C82-\u0C83\u0CBE-\u0CC4\u0CC6-\u0CC8\u0CCA-\u0CCD\u0CD5-\u0CD6\u0D02-\u0D03\u0D3E-\u0D43\u0D46-\u0D48\u0D4A-\u0D4D\u0D57\u0E31\u0E34-\u0E3A\u0E47-\u0E4E\u0EB1\u0EB4-\u0EB9\u0EBB-\u0EBC\u0EC8-\u0ECD\u0F18-\u0F19\u0F35\u0F37\u0F39\u0F3E\u0F3F\u0F71-\u0F84\u0F86-\u0F8B\u0F90-\u0F95\u0F97\u0F99-\u0FAD\u0FB1-\u0FB7\u0FB9\u20D0-\u20DC\u20E1\u302A-\u302F\u3099\u309A"; # [87]

      variable Digit "\u0030-\u0039\u0660-\u0669\u06F0-\u06F9\u0966-\u096F\u09E6-\u09EF\u0A66-\u0A6F\u0AE6-\u0AEF\u0B66-\u0B6F\u0BE7-\u0BEF\u0C66-\u0C6F\u0CE6-\u0CEF\u0D66-\u0D6F\u0E50-\u0E59\u0ED0-\u0ED9\u0F20-\u0F29"; # [88]

      variable Extender "\u00B7\u02D0\u02D1\u0387\u0640\u0E46\u0EC6\u3005\u3031-\u3035\u309D-\u309E\u30FC-\u30FE"; # [89]

      variable Letter $BaseChar$Ideographic; # [84]
   } else {
      variable CombiningChar ""
      variable Digit "0-9"; # [88]
      variable Extender ""
      variable Letter "A-Za-z\xc0-\xd6\xd8-\xf6\xf8-\xff"; # [84]
   }

   #-----------------------------------------------------------------------
   # 2.2 - Characters - restricted to ISO-Latin-1 for Tcl/Tk8.0
   # The whole document must match this character set

   if {$i18n} {
      variable Char "\n\t\r\x20-\ud7ff\ue000-\ufffd"; # [2]
   } else {
      variable Char "\n\t\r -\xff"; # [2]
   }

   # as a side-effect, initialize "document" local var to the whole text
   lappend rules {initial} "\[$Char]*(\[^$Char])?" {document char} {
      if {$char != ""} {
	 parse_error "Forbidden char \\x[scan $char %c val; format %x $val]" "" [expr [string length $document]-1]
      }
      [lexer current] reject
      [lexer current] begin $initial
   }

   #-----------------------------------------------------------------------
   # 2.3 - Common Syntactic Constructs

   variable rgS " \n\t\r"
   variable S "\[$rgS]+"; # [3]
   variable S? "\[$rgS]*"; # replacement for "($S)?"
   variable NameChar "\[-._:$Letter$Digit$CombiningChar$Extender]"; # [4]
   variable Name "\[_:$Letter]$NameChar*"; # [5]

   variable Names "$Name\($S$Name)*"; # [6], 1(
   variable Nmtoken "$NameChar+"; # [7]
   variable Nmtokens "$Nmtoken\($S$Nmtoken)*"; # [8], 1(

   # 4.1 - Character and Entity References

   variable CharRef "&\#(\[0-9]+);|&\#x(\[0-9a-fA-F]+);"; # [66], 2(
   variable EntityRef "&($Name);"; # [68], 1(
   variable Reference "$EntityRef|$CharRef"; # [67], 3(
   variable PEReference "%($Name);"; # [69], 1(

   # 2.3 (cont.)

   variable EntityValue "\"(\[^%&\"]|$PEReference|$Reference)*\"|'(\[^%&']|$PEReference|$Reference)*'"; # [9], 10(
   variable AttValue "\"(\[^<&\"]|$Reference)*\"|'(\[^<&']|$Reference)*'"; # [10], 8(
   variable SystemLiteral "(\"\[^\"]*\"|'\[^']*')"; # [11], 1(
   set rgPubid "- \n\ra-zA-Z0-9()+,./:=?;!*\#@\$_%"
   variable PubidChar "\[$rgPubid']"; # [13]
   variable PubidLiteral "(\"$PubidChar*\"|'\[$rgPubid]*')"; # [12], 1(

   #-----------------------------------------------------------------------
   # 2.8 - Prolog

   variable Eq "${S?}=${S?}"; # [25]
   variable VersionNum "\[-a-zA-Z0-9_.:]+"; # [26]
   variable VersionInfo "${S}version${Eq}(\"$VersionNum\"|'$VersionNum\')"; # [24], 1(
   variable SDDecl "${S}standalone${Eq}('yes'|\"yes\"|'no'|\"no\")"; # [32], 1(
   variable EncName "\[A-Za-z]\[-A-Za-z0-9._]*"; # [81]
   variable EncodingDecl "${S}encoding${Eq}(\"$EncName\"|'$EncName\')"; # [80], 1(
   variable XMLDecl "<\\?xml${VersionInfo}($EncodingDecl)?($SDDecl)?${S?}\\?>"; # [23], 5(
   lappend conds prolog-xml

   # XML declaration
   lappend rules {prolog-xml} $XMLDecl {all num has_enco enco has_sd sd} {
      # Only version 1.0 supported
      if {[unquote $num] != "1.0"} {
	 parse_error "xml version $num not supported"
      }
      # Standalone declaration
      if {$has_sd != ""} {
	 set standalone [unquote $sd]
      } else {
	 set standalone ""
      }
      # Encoding should have been handled before
      if {$conf(-debug)} {
	 puts "Xml decl: <?xml version=$num encoding=$enco standalone=$sd?>"
      }
      # Switch to dtd prolog
      [lexer current] end
      [lexer current] begin prolog-dtd
   }

   # detect some wrong XML declarations (spaces, capitalization, missing chars...)
   lappend rules {prolog-xml} "${S?}(<${S?})?(\\?${S?})?(x|X)(m|M)(l|L)\[^\n]*" {all} {
      parse_error "Wrong format for xml declaration $all"
   }

   # Switch to dtd prolog without xml decl
   lappend rules {prolog-xml} . {} {
      [lexer current] reject
      [lexer current] end
      [lexer current] begin prolog-dtd
   }

   #-----------------------------------------------------------------------
   # 2.8 (cont.) - Document Type Declaration

   variable ExternalID "(SYSTEM|PUBLIC$S$PubidLiteral)$S$SystemLiteral"; # [75], 3(
   lappend conds prolog-dtd dtd-decl dtd-int dtd-ext

   # start of DTD declaration
   lappend rules {prolog-dtd} "<!DOCTYPE${S}($Name)($S$ExternalID)?${S?}" {all root has_ext bid publ syst} {
      if {$conf(-debug)} {
	 puts "DTD root $root public $publ system $syst"
      }
      set rootType $root
      set publ [normPubId [unquote $publ]]
      set syst [unquote $syst]
      if {$publ != ""} {
      } elseif {$syst != ""} {
	  # if the dtd used in the trs file is under trans-14.dtd change it for compatibility with transcriber 1.5.0
	  variable olddtd $syst
	  regexp {trans\-([0-9]+).*} $syst all dtdnum
	  if { $dtdnum < 14 } {
	      regsub {[0-9]+} $syst {14} syst
	      variable modifdtd 1
	  }
	  set syst [file join [file dirname $conf(-filename)] $syst]
      }
      # If asked to keep current DTD, verify external DTD filename matches
      # the current one, else the given subset will be read
      if {$conf(-keepdtd)} {
	 set dtdname [::xml::dtd::name]
	 if {$conf(-keepdtd) != 3 && [file tail $dtdname] != [file tail $syst]} {
	    if {$conf(-keepdtd) == 2} {
	      parse_error "External DTD '$syst' doesn't match requested '$dtdname'"
	    } else {
	      if {$conf(-debug)} {
		puts "switching DTD to $syst"
	      }
	      set dtdname $syst
	    }
	 } else {
	    set dtdname ""
	 }
      } else {
	 set dtdname $syst
      }

      [lexer current] end
      [lexer current] begin dtd-decl
   }

   # start of internal subset
   lappend rules {dtd-decl} "\\\[" {} {
      if {$conf(-keepdtd)} {
	 parse_error "Sorry, the current application forbids internal subset"
      }
      [lexer current] begin dtd-int
   }

   # meet parameter reference in DTD
   lappend rules {dtd-int dtd-ext dtd-inc} "$PEReference" {all} {
      if {$conf(-debug)} {
	 puts "DTD ref $ref"
      }
      # We have to expand parameter reference in a new lexer
   }

   # skip spaces
   lappend rules {dtd-int dtd-ext dtd-inc} "$S" {} {
   }

   # end of internal subset
   lappend rules {dtd-int} "]${S?}" {} {
      [lexer current] end
   }

   # end of DTD declaration
   lappend rules {dtd-decl} ">" {} {
      [lexer current] end
      [lexer current] begin prolog-end

      # Read and parse external DTD if needed
      if {$dtdname != ""} {
	if {$conf(-keepdtd)} {
	  ::xml::dtd::init
	  ::xml::dtd::active $conf(-valid)
	}
	if {[catch {
	  eval read_file [list $dtdname] [array get conf] -type dtd
	} msg]} {
	  parse_error $msg $::errorInfo
	}
      }
   }

   #-----------------------------------------------------------------------
   # External Subset
   variable TextDecl "<\\?xml($VersionInfo)?$EncodingDecl${S?}\\?>"; # [77], 3(

   lappend conds prolog-subset

   lappend rules {prolog-subset} $TextDecl {all has_num num enco} {
      [lexer current] end
      [lexer current] begin dtd-ext
   }

   lappend rules {prolog-subset} . {} {
      [lexer current] reject
      [lexer current] end
      [lexer current] begin dtd-ext
   }
   
   #-----------------------------------------------------------------------
   # 3.2 - Element Type Declarations

   variable children "\\(($Name|\\(${S?}|${S?}\\)|${S?},${S?}|${S?}\\|${S?}|\[?*+])*\\)\[?*+]?"; # [47], 1( Simplified regexp - has to be parsed more precisely
   variable Mixed "(\\(${S?}\#PCDATA(${S?}\\|${S?}$Name)*\\)\\*|\\(${S?}\#PCDATA${S?}\\))"; # [51], 1(
   variable contentspec "(EMPTY|ANY|$Mixed|$children)"; # [46], 3(
   variable elementdecl "<!ELEMENT${S}($Name)$S$contentspec${S?}>"; # [45], 4(

   lappend rules {dtd-int dtd-ext dtd-inc} $elementdecl {all type content} {
      if {$conf(-debug)} {
	 puts "DTD Element: <!ELEMENT $type $content>"
      }
      ::xml::dtd::element::declare $type $content
   }

   #-----------------------------------------------------------------------
   # 3.3 - Attribute-List Declarations

   variable StringType "CDATA"; # [55]
   variable TokenizedType "ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS"; # [56]
   variable NotationType "NOTATION$S\\(${S?}$Name\(${S?}\\|${S?}$Name)*${S?}\\)"; # [58], 1(
   variable Enumeration "\\(${S?}$Nmtoken\(${S?}\\|${S?}$Nmtoken)*${S?}\\)"; # [59], 1(
   variable EnumeratedType "$NotationType|$Enumeration"; # [57], 2(
   variable AttType "($StringType|$TokenizedType|$EnumeratedType)"; # [54], 3(
   variable DefaultDecl "(\#REQUIRED|\#IMPLIED|((\#FIXED$S)?($AttValue)))"; # [60], 12(
   variable AttDef "$S\($Name)$S$AttType$S$DefaultDecl"; # [53], 16(
   variable AttlistDecl "<!ATTLIST${S}($Name)(($AttDef)*)${S?}>"; # [52], 19(

   lappend rules {dtd-int dtd-ext dtd-inc} $AttlistDecl {all type content} {
      if {$conf(-debug)} {
	 puts "DTD Attribute: <!ATTLIST $type $content>"
      }
      ::xml::dtd::attribute::declare $type $content
   }

   #-----------------------------------------------------------------------
   # 3.4 - Conditional Sections (DTD external subset only)

   lappend conds dtd-ignore dtd-inc

   lappend rules {dtd-ext dtd-inc} "<!\\\[${S?}INCLUDE${S?}\\\[" {} {
      [lexer current] begin dtd-inc
   }

   lappend rules {dtd-inc} "]]>" {} {
      [lexer current] end
   }

   lappend rules {dtd-ext dtd-inc} "<!\\\[${S?}IGNORE${S?}\\\[" {} {
      [lexer current] begin dtd-ignore
   }

   lappend rules {dtd-ignore} "<!\\\[" {} {
      [lexer current] begin dtd-ignore
   }

   lappend rules {dtd-ignore} "]]>" {} {
      [lexer current] end
   }
   
   #-----------------------------------------------------------------------
   # 4.2 - Entity Declarations

   variable NDataDecl "${S}NDATA$S\($Name)"; # [76], 1(
   variable EntityDef "(($EntityValue)|$ExternalID\($NDataDecl)?)"; # [73], 17(
   variable GEDecl "<!ENTITY$S\($Name)$S$EntityDef${S?}>"; # [71], 18(
   variable PEDef  "(($EntityValue)|$ExternalID)"; # [74], 15(
   variable PEDecl "<!ENTITY$S\%$S\($Name)$S$PEDef${S?}>"; # [72], 16(
   variable EntityDecl "$GEDecl|$PEDecl"; # [70], >> 20 ( -- bad for tcl8.0 defs.

   lappend rules \
       {dtd-int dtd-ext dtd-inc} $GEDecl {all name v0 val v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 has_sys pub sys has_dat dat} {dtd_entity $name "&" $val $pub $sys $dat} \
       {dtd-int dtd-ext dtd-inc} $PEDecl {all name v0 val v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 has_sys pub sys has_dat dat} {dtd_entity $name "%" $val $pub $sys $dat}

   proc dtd_entity {name type value pub sys ndata} {
      upvar conf conf

      if {$conf(-debug)} {
	 puts "DTD Entity $name = $value PUBLIC $pub SYSTEM $sys NDATA $ndata"
      }
      if {$value != ""} {
	 # Declare internal entity
	 ::xml::dtd::entity::declare $type $name [unquote $value]
      } else {
	 # Normalize public id
	 if {$pub != ""} {
	    set pub [string trim [unquote $pub]]
	    regsub -all $S $pub " " pub
	 }
	 # Should normalize system id by escaping non-ascii chars
	 # Declare external entity
	 ::xml::dtd::entity::external $type $name $pub $sys $ndata
      }
   }

   #-----------------------------------------------------------------------
   # 4.7 - Notation Declaration

   variable PublicID "PUBLIC$S\$PubidLiteral"; # [83], 1(
   variable NotationDecl "<!NOTATION$S\($Name)${S}($ExternalID|$PublicID)${S?}>"; # [82], 5(

   lappend rules {dtd-int dtd-ext dtd-inc} $NotationDecl {all name val has_pub1 pub1 sys pub2} {
      set pub "$pub1$pub2"
      if {$conf(-debug)} {
	 puts "DTD Notation $name PUBLIC $pub SYSTEM $sys"
      }
      ::xml::dtd::notation::declare $name $pub $sys
   }

   #-----------------------------------------------------------------------
   # 2.5 - Comments "<!-- ... -->"

   variable Comment "<!--((\[^-]|(-\[^-]))*)-->"; # [15], 3(

   lappend rules {prolog-dtd dtd-int dtd-ext dtd-inc prolog-end content doc-end} $Comment {all comment} {
      if {$conf(-debug)} {
	 puts "Comment: <!--$comment-->"
      }
      # Can be given to the application (but this is not mandatory)
      if {$conf(-comment) && $currentItem != ""} {
	 ::xml::comment $comment -in $currentItem
      }
   }

   #-----------------------------------------------------------------------
   # 2.6 - Processing Instructions "<?PITarget ... ?>"

   lappend conds in-pi1 in-pi2

   lappend rules {prolog-dtd dtd-int dtd-ext dtd-inc prolog-end content doc-end} "<\\?($Name)" {all target} {
      set pi ""
      [lexer current] begin in-pi1
   }

   lappend rules {in-pi1} $S {} {
      [lexer current] end
      [lexer current] begin in-pi2
   }

   lappend rules {in-pi1 in-pi2} "\\?>" {} {
      [lexer current] end
      if {[string tolower $target] == "xml"} {
	 parse_error "processing instruction $target reserved"
      }
      if {$conf(-debug)} {
	 puts "PI $target $pi"
      }
      # Keep only PIs matching given target pattern 
      if {$conf(-pitarget) != "" && $currentItem 
	  && [string match $conf(-pitarget) $target]} {
	 ::xml::pi $target $pi -in $currentItem
      }
   }

   lappend rules {in-pi2} . {char} {
      append pi $char
   }

   #-----------------------------------------------------------------------
   # Skip spaces, switch to content if nothing matches in the prolog

   lappend conds prolog-end doc-end

   lappend rules {prolog-dtd prolog-end doc-end} $S {} {}

   lappend rules {prolog-dtd prolog-end} . {} {
      [lexer current] reject
      [lexer current] end
      [lexer current] begin root
   }

   #-----------------------------------------------------------------------
   # 3.1 - Start-Tags, End-Tags and Empty-Element Tags

   variable Attribute "($Name)${Eq}($AttValue)"; # [40], 10(
   variable ETag "</($Name)${S?}>"; # [42], 1(

   lappend conds root content in-tag

   # begin of Start-Tag
   lappend rules {root content} "<($Name)" {all type} {
      set attribs ""
      [lexer current] begin in-tag
   }

   # attribute inside Start-Tag
   lappend rules {in-tag} "$S$Attribute" {all name val} {
      lappend attribs $name [::xml::dtd::entity::replace [unquote $val]]
   }

   # end of Start-Tag
   lappend rules {in-tag} "${S?}(/)?>" {all empty} {
      # Leave in-tag condition, then switch to doc-end after root element
      [lexer current] end
      set is_root 0
      if {[[lexer current] conditions -current] == "root"} {
	 set is_root 1
	 [lexer current] end
	 [lexer current] begin doc-end
      }
      if {$empty != "/"} {
	 [lexer current] begin content
	 set types($level) $type
	 incr level
      }
      # Registration of start-tag
      if {$conf(-debug)} {
	 puts "Tag: <$type $attribs $empty>"
      }
      # Validity: Root Element Type
      if {$conf(-valid) && $is_root} {
	 if {$rootType == ""} {
	    parse_error "Validation impossible - no DTD found in document"
	 }
	 if {$type != $rootType} {
	    parse_error "Root element type should be $rootType, not $type"
	 }
      }
      # Creation of tag with validation of type/attributes
      if [catch {
	 set tag [::xml::element $type $attribs -in $currentItem]
	 # Validity: required attributes must have been defined
	 if {[::xml::dtd::active]} {
	    $tag valid-attr
	    #${xml}::dtd::attribute::required $tag
	 }
      } msg] {
	 parse_error $msg $::errorInfo
      }
      # Keep root element
      variable rootItem
      if {$rootItem == ""} {
	 set rootItem $tag
      }
      # New element becomes a father
      if {$empty != "/"} {
	 set currentItem $tag
      }
   }

   # End-Tag
   lappend rules {content} $ETag {all type} {
      # For lexical analysis purpose
      [lexer current] end
      incr level -1
      if {$type != $types($level)} {
	 parse_error "Wrong end-tag </$type> - should be </$types($level)>"
      }
      # Registration of end-tag
      if {$conf(-debug)} {
	 puts "End-tag: </$type>"
      }
      # Validate element content (order only)
      if {$conf(-valid)} {
	 if [catch {
	    #::xml::dtd::element::rightOrder $currentItem
	    $currentItem valid-elem
	 } msg] {
	    parse_error $msg $::errorInfo
	 }
      }
      # Go back to father
      set currentItem [$currentItem getFather]
   }

   # References inside content are handled as data (for the moment)
#    lappend rules {content} $Reference {ref} {
#       if {$conf(-debug)} {
# 	 puts "Reference to $ref"
#       }
#       # We should parse it with a sub-lexer !!!
#    }

   #-----------------------------------------------------------------------
   # 2.4 - Character Data

   lappend rules {content} "(\[^<&]|$Reference)+" {data} {
      if {[regexp "]]>" $data]} {
	 parse_error "CDATA-section-close delimiter ']]>' found in character data"
      }
      # Skip white space at user option (should look at xml:space instead)
      if {$conf(-skipspace)} {
	 #set data [string trim $data]
	 #if {[string length $data] <= 0} break
	 regsub "^\[ \t]*\n" $data "" data
	 regsub "\n\[ \t]*$" $data "" data
	 regsub -all "\[ \t]+" $data " " data
	 #set data [string trim $data "\n"]
	 #regsub -all "\[ \n\t]+" $data " " data
	 if {$data == " " || $data == ""} { break ; error "stop!" }
      }

      # Expand entity references (they should be handled otherwise, because
      # entities can contain other markup)
      if {[catch {
	 set data [::xml::dtd::entity::replace $data]
      } msg]} {
	 parse_error $msg $::errorInfo
      }

      if {$conf(-debug)} {
	 puts "Data: \"$data\""
      }
      append_data $data
   }

   # Create a new data item or append to the last one if it exists
   proc append_data {data} {
      upvar conf conf currentItem currentItem

      if {$conf(-valid)} {
	 if {[catch {
	    ::xml::dtd::element::authorized [$currentItem getType] "\#PCDATA"
	 } msg]} {
	    # Only white spaces can be discarded without error
	    # but it should perhaps be registred somewhere else ?
	    variable S
	    if {[regexp "^$S\$" $data]} return
	    uplevel [list parse_error $msg $::errorInfo]
	 }
      }
      set last [lindex [$currentItem getChilds] end]
      if {$last != "" && [$last class] == "data"} {
	 set oldata [$last getData]
	 append oldata $data
	 $last setData $oldata
      } else {
	 ::xml::data $data -in $currentItem
      }
   }
   
   #-----------------------------------------------------------------------
   # 2.7 - CDATA Sections "<![CDATA[ ...]]>"

   variable CDStart "<!\\\[CDATA\\\["; # [19]
   variable CDEnd "]]>"; # [21]

   lappend conds in-cdata

   # start of CDATA section
   lappend rules {content} $CDStart {} {
      set cdata ""
      [lexer current] begin in-cdata
   }

   # end of CDATA section
   lappend rules {in-cdata} $CDEnd {} {
      if {$conf(-debug)} {
	 puts "CData: <!\[CDATA\[$cdata]]>"
      }
      # CDATA are just data
      append_data $cdata
      [lexer current] end
   }

   # inside CDATA section
   lappend rules {in-cdata} . {char} {
      append cdata $char
   }

   #-----------------------------------------------------------------------
   # Final default rule : raise an error on syntax error

   lappend conds error

   lappend rules {*} "<!--\[^\n]*" {line} {
      parse_error "Syntax error in comment \"$line\""
   }

   lappend rules {content} "&\[^\n;]*;?" {line} {
      parse_error "Syntax error in entity reference \"$line\""
   }

   lappend rules {root content} "<\[^\n>]*>?" {line} {
      parse_error "Syntax error in tag \"$line\""
   }

   lappend rules {doc-end} "<\[^\n>]*>?" {line} {
      parse_error "Forbidden tag after root element: \"$line\""
   }

   lappend rules {*} "." {} {
      [lexer current] reject
      [lexer current] begin error
   }

   lappend rules {error} "${S?}(\[^\n]*)" {all line} {
      [lexer current] end
      switch [[lexer current] conditions -current] {
	 "content" {
	    parse_error "Waiting for element content, got \"$line\" "
	 }
	 "in-tag" { 
	    parse_error "Waiting for attribute specification, got \"$line\""
	 }
	 "doc-end" {
	    parse_error "Waiting for comment or PI instructions, got \"$line\""
	 }
	 default {
	    parse_error "...$line "
	 }
      }
   }

   #=======================================================================
   # Raise an error with a message giving file name and error line
   # (to be called exclusively from a rule within the parser)

   proc parse_error {explain {info ""} {pos ""}} {
      upvar conf conf document document

      # Get error character index inside document
      if {$pos == ""} {
	 set pos [[lexer current] index]
      }

      # Find in which line the error occured by counting newlines before
      set before [string range $document 0 $pos]
      set line [expr [regsub -all \n $before {} ignore]+1]

      set msg "XML parse error"
      if {$conf(-filename) != ""} {
	 append msg " on file '$conf(-filename)'"
      }
      error "$msg line $line:\n$explain" $info
   }

   #=======================================================================
   # Create the XML lexer

   package require tcLex

   # Lexer internal variables :
   #   conf(-*) : array of user configurable values
   #   document : string containing the whole document beeing parsed
   #   level :    nb of currently embedded elements
   #   types() :  list of type for each level
   #   dtdname :  name of dtd external subset to read
   #   rootType:  type of root element found in DTD (or empty if no DTD)
   #   currentItem: ID of current element (to be father of element content) 
   # Variables shared by all lexers (i.e. variables in current namespace)
   #   rootItem : element to be returned by the parser

   lexer create xmlex -args {options} -ec $conds -prescript {

      # Default options for parsing (no debug, current file unknown, 
      # don't keep comments or processing instructions, 
      # CDATA sections become data)
      array set conf {
	 -type      "document"
	 -debug     0
	 -filename  ""
	 -valid     1
	 -keepdtd   0
	 -alldoc    0
	 -comment   0
	 -pitarget  ""
	 -cdata     0
	 -skipspace 1
      }
      # Parse args and set authorized options
      foreach {name value} $options {
	 if {[lsearch -exact [array names conf] $name] >= 0} {
	    set conf($name) $value
	 } else {
	    error "XML parser: unknown option '$name'"
	 }
      }
      # Choose the lexer : root document, dtd external subset, ...
      variable rootItem ""
      switch -exact -- $conf(-type) {	 
	 "document" {       
	    set initial "prolog-xml"

	    # Init dtd
	    if {!$conf(-keepdtd)} {
	       ::xml::dtd::init
	    }
	    set rootType ""
	    
	    # Dynamic validating mode for XML elements
	    ::xml::dtd::active $conf(-valid)
	    
	    # Start on an empty node
	    if {$conf(-alldoc)} {
	       set rootItem [::xml::node]
	    }
	    set currentItem $rootItem
	 }
	 "dtd" {
	    set initial "prolog-subset"

	    ::xml::dtd::name $conf(-filename)
	 }
	 default {
	    error "XML parser: unknown document type '$conf(-type)'"
	 }
      }
      set level 0
   } -postscript {
      set cur [[lexer current] conditions -current]
      if {$cur != "doc-end" && $cur != "dtd-ext"} {
	 parse_error "Ended in $cur state"
      }
      # Validate id refs for document
      if {$conf(-valid) && $conf(-type) == "document"} {
	 ::xml::dtd::id::validate
      }
      return $rootItem
   } $rules
      
   #=======================================================================
   # General parsing procedures

   proc parse_doc {txt args} {
      variable rootItem
      
      # All the stuff
      if {[catch {
	 xmlex eval $txt $args
      } err]} {
	 set inf $::errorInfo
	 # Free memory before leaving when an error occurs
	 catch {$rootItem deltree}
	 return -code error -errorinfo $inf $err
      }

      # Return root item of tree
      return $rootItem
   }

   proc read_file {name args} {
      set f [open $name]

      # Automatic detection of encoding for Tcl/Tk 8.1.1
      if {![catch {encoding system}]} {
	 global v
	 set txt [detect_encoding $f [EncodingFromName $v(encoding)]]
      }

      # By default, end-of-lines are handled conforming to 2.11
      append txt [read $f]
      close $f
      return [eval parse_doc [list $txt] $args -filename [list $name]]
   }

   proc write_file {name root} {
      if {[$root class] != "element"} {
	 set root [lindex [$root getChilds "element"] 0]
	 if {$root == ""} {error "Empty XML document - not written"}
      }
      set f [open $name w]

      # Header with optional encoding information
      set encString ""
      if {![catch {encoding system}]} {
	 global v
	 set enc [EncodingFromName $v(encoding)]
	 if {$enc != ""} {
	    set encString " encoding=\"$v(encoding)\""
	    fconfigure $f -encoding $enc
	 }
      }
      puts $f "<?xml version=\"1.0\"$encString?>"

      set dtd [::xml::dtd::name]
      if {$dtd != ""} {
	 puts $f "<!DOCTYPE [$root getType] SYSTEM \"[file tail $dtd]\">"
      }
      puts $f [$root dump]
      close $f
   }

   # F - Detect encoding of an XML file coming from a channel and configure it.
   # As a result, returns the characters already read at the beginning of the file
   # (which avoids seeking back to the start of file or channel)
   proc detect_encoding {channel {default "uft-8"}} {

      # Read 2 or 4 bytes first for UCS-4 / UTF-16 / UTF-8 autodectection
      fconfigure $channel -encoding binary
      set txt [read $channel 2]
      if {$txt != "\xfe\xff" && $txt != "\xff\xfe"} {
	 append txt [read $channel 2]
      }

      # First configure to default encoding (should be UTF-8, but it will
      # probably not be the correct guess with transcriptions produced with
      # Transcriber under Tcl/Tk8.0)
      switch -exact -- $txt {
	 "\x4c\x6f\xa7\x94" {
	    error "XML parser: EBCDIC format not supported"
	 }
	 "\x00\x00\x00\x3c" -
	 "\x00\x00\x00\x3c" -
	 "\x00\x00\x00\x3c" -
	 "\x00\x00\x00\x3c" {
	    error "XML parser: UCS-4 format not supported"
	 }
	 "\xfe\xff" -
	 "\xff\xfe" -
	 "\x00\x3c\x00\x3f" -
	 "\x3c\x00\x3f\x00" {
	    set c [encoding convertfrom ascii [string index $txt 0]]
	    if {$c == "\xfe" || $c == "\x00"} {
	       set order "bigEndian"
	    } else {
	       set order "littleEndian"
	    }
	    if {$::tcl_platform(byteOrder) != $order} {
	       error "XML parser: Can't handle swapped UTF-16 Unicode file"
	    }
	    if {$c == "\xfe" || $c == "\xff"} {
	       set txt ""
	    } else {
	       set txt "<?"
	    }
	    fconfigure $channel -encoding "unicode"
	 }
	 "\x3c\x3f\x78\x6d" {
	    # read up to the end of the tag - limited to 1024 chars anyway
	    # (can't do a 'gets' since newline is a legal space within xml decl.)
	    for {set i 0} {$i < 1024} {incr i} {
	       set c [read $channel 1]
	       append txt $c
	       if {$c == ">"} break
	    }
	    # detect UTF-8 or any 7-bit or 8-bit encoding
	    variable VersionInfo
	    variable EncodingDecl
	    if {[regexp "<\\?xml($VersionInfo)?$EncodingDecl" $txt all v1 v2 v3]} {
	       # Look for a Tcl encoding matching the given name
	       set enc [EncodingFromName [string trim $v3 '\"]]
	       if {$enc != ""} {
		  fconfigure $channel -encoding $enc
	       } else {
		  error "XML parser: encoding $v3 not supported"
	       }
	    } else {
	       fconfigure $channel -encoding $default
	    }
	 }
      }
      #puts "Encoding = [fconfigure $channel -encoding]"
      return $txt
   }

   #=======================================================================
   # General procedures

   # Check for well-formedness: value must match regexp of given name
   proc check {reg_name value} {
      variable $reg_name
      if {![regexp "^[set $reg_name]\$" $value]} {
	 parse_error "Value '$value' is not a well-formed $reg_name"
      }
   }

   # Strip quotes around value
   proc unquote {val} {
      if {$val == ""} return
      if {![regexp "^(\[\"'])(.*)(\[\"'])$" $val all sep1 val sep2]
       || $sep1 != $sep2} {
         parse_error "Wrongly quoted string $val"
      }
      return $val
   }

   # Normalize public identifier
   proc normPubId {public} {
      variable S
      regsub -all $S $public " " public
      return [string trim $public]
   }

}

################################################################
