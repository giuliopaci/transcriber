# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

proc Refresh {} {
   DestroyTextFrame
   DestroySegmentWidgets
   LoadModules
   BuildGUI
   DisplayTrans
   ConfigAllWavfm
}

proc Restart {} {
   SaveIfNeeded
   DestroyTextFrame
   DestroySegmentWidgets
   InitSegmt seg0 seg1 seg2 bg
   namespace delete xml
   LoadModules
   BuildGUI
   StartWith {}
}

# CreateDebug :
#
# Create an interactive window for debug and access to internals of program.
# (as if launched in interactive mode).
# CR to execute; ^D to cancel command
# Drawbacks: 
#  not very efficient for copy/paste; one can type in anywhere...
# Just for emergency

proc CreateDebug {} {
   set f .dbg
   if [winfo exists $f] return
   toplevel $f
   set t [text $f.txt -wrap word -width 80 -height 25 \
      -yscrollcommand [list $f.ysc set]]
   scrollbar $f.ysc -orient vertical -command [list $f.txt yview]
   pack $f.txt -side left -fill both -expand true
   pack $f.ysc -side right -fill y
   ClearTclCmd $t
   $t mark gravity cmd left
   #update idletasks

   # redirect stdout to file
   #close stdout
   #set out [open /var/tmp/trans-out_[pid] w]
   #set in [open /var/tmp/trans-out_[pid] r]
   #fconfigure $in -blocking 0 -buffering none -eofchar {} -translation lf
   #flush $out; read $in

   bind $t <Enter> {focus %W}
   bind $t <Return> "ExecTclCmd %W; break "
   bind $t <Control-d> {ClearTclCmd %W; break }

}

# If cmd is complete, exec it at global level in interactive mode
# and keep in history, get stdout from temporary file, print output and
# result and reset cmd.
proc ExecTclCmd {t} {
   $t mark set insert end
   $t insert insert "\n"
   set c [$t get cmd end]
   if [info complete $c] {
      global tcl_interactive
      set i $tcl_interactive; set tcl_interactive 1
      catch {uplevel \#0 $c} result
      set tcl_interactive $i
      history add $c
      #flush stdout; set out [read $in]
      $t insert insert "$result"
      ClearTclCmd $t
   }
}

proc ClearTclCmd {t} {
   $t mark set insert end
   $t insert insert "\n% "
   $t mark set cmd insert
   $t see insert
}
