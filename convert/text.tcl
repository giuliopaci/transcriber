# Copyright (C) 2003, LIMSI-CNRS - extension for the Transcriber program
# distributed under the GNU General Public License

################################################################

# filter for simple text export in the format:
#   spk1: transcript1...
#   spk2: transcript2...
#   ...
#
# default settings may be overriden on command line, e.g.:
# trans -set exportSpkFmt "\n%s:\n" -export text *.trs

namespace eval text {

   variable msg "Text"
   variable ext ".txt"

   proc export {name} {
     global v
     
     # export topic (empty=no export, could be e.g. "\n\[%s\]")
     setdef v(exportTopicFmt) ""
     # export 'nontrans' sections?
     setdef v(exportNontrans) false
     # export 'comment'?
     setdef v(exportComment) false
     # export 'event'?
     setdef v(exportEvent) true
     # speaker format
     setdef v(exportSpkFmt) "%s:"
     # sync char
     setdef v(exportSyncFmt) ""
     # tags around overlapping segments
     setdef v(exportOverStart) "\#%s"
     setdef v(exportOverEnd) "\#"

     set channel [open $name w]
     set episode [$v(trans,root) getChilds "element" "Episode"]
     foreach sec [$episode getChilds "element" "Section"] {
       if {[$sec getAttr "type"] == "nontrans" && !$v(exportNontrans)} continue
       if {$v(exportTopicFmt) != ""} {
	 puts $channel [format $v(exportTopicFmt) [section::short_name $sec]]
       }
       set turns [$sec getChilds "element" "Turn"]
       set spk ""
       set txt ""
       foreach tur $turns {
	 set sta [format %.3f [$tur getAttr "startTime"]]
	 set syn $sta
	 set spkLst [$tur getAttr "speaker"]
	 set nbSpk [llength $spkLst]
	 # new current speaker
	 if {$spk == "" || [lindex $spkLst 0] != $spk} {
	   print
	   if {$nbSpk == 0} continue
	   set spk [lindex $spkLst 0]
	   set txt ""
	 }
	 foreach chn [$tur getChilds] {
	   if {[$chn class] == "element"} {
	     switch [$chn getType] {
	       "Sync" {
		 set syn [format %.3f [$chn getAttr "time"]]
		 if {$syn > $sta && $nbSpk == 1} {
		   append txt $v(exportSyncFmt)
		 }
	       }
	       "Who" {
		 set nb [$chn getAttr "nb"]
		 if {$nb > 1 || $syn != $sta} {
		   append txt " " $v(exportOverEnd)
		   print
		 }
		 set spk [lindex $spkLst [expr $nb-1]]
		 append txt " " [format $v(exportOverStart) $nb]
	       }
	       "Event" {
		 if {$v(exportEvent)} {
		   append txt " " [StringOfEvent $chn]
		 }
	       }
	       "Comment" {
		 if {$v(exportComment)} {
		   append txt " " [StringOfEvent $chn]
		 }
	       }
	     }
	   } elseif {[$chn class] == "data"} {
	     set str [string trim [$chn getData]]
	     if {$str != ""} {
	       append txt " " $str
	     }
	   }
	 }
	 if {$nbSpk > 1} {
	   append txt " " $v(exportOverEnd)
	 }
       }
       print
     }
     close $channel
   }

   proc print {} {
     uplevel {
       if {[string trim $txt] != ""} {
	 puts $channel "[format $v(exportSpkFmt) [::speaker::name $spk]] $txt"
	 set txt ""
       }
     }
   }
}
