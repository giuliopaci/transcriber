# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# Part of the file Copyright (c) 1995 by Sun Microsystems

proc ViewFile {fileName {list {}}} {
   set w .help
   set w1 $w.top
   set t $w1.txt
   set w2 $w.bot
   set b $w2.close
   if ![winfo exists $w] {
      toplevel $w
      wm iconname $w [Local "Help"]

      set t [ScrolledText $w1]

      frame $w2 -bd 5
      set i 0
      foreach {title file} $list {
	 button $w2.$i -text [Local $title] -command [list render $t $file]
	 pack $w2.$i -side left -expand true
	 incr i
      }
      button $b -text [Local "Close"] -command [list destroy $w]
      pack $b -side left -expand true
      pack $w2 -fill x 

      # for HTML display
      HMinit_win $t

      # keyboard bindings for the text widget
      bind $w <End> "$t yview end"
      bind $w <Home> "$t yview 0.0"
      bind $w <Next> "$t yview scroll 1 page"
      bind $w <Prior> "$t yview scroll -1 page"

      catch {CenterWindow $w}
   } else {
      FrontWindow $w
   }
   render $t $fileName
}

#######################################################################

proc ViewHelp {{name "Index"}} {
   global v

   array set arr {
      "Presentation"     "present_local.html"
      "Main features"    "functions.html"
      "User guide"       "user.html"
      "Reference manual" "reference.html"
   }
   set Lg [string toupper [string index $v(lang) 0]][string range \
							 $v(lang) 1 end]
   set arr(Index) [file join [pwd] $v(path,doc) Index$Lg.html]
   set dir [file join [pwd] $v(path,doc) $v(lang)]  
   if {![file exists $arr(Index)] || ![file exists $dir]} {
      set arr(Index) [file join [pwd] $v(path,doc) Index.html]
      set dir [file join [pwd] $v(path,doc) "en"]
   }
   # First try to launch Internet Explorer or Netscape first
   set url [file join $dir $arr($name)]
   if {$::tcl_platform(os) == "Darwin"} {
     exec open $url
   } elseif {[catch {
      exec iexplore $url &
   }] && [catch {
	exec "C:\\Program Files\\Internet Explorer\\IEXPLORE.EXE" $url	
   }] && [catch {
      exec netscape -remote "openFile ($url)"
   }] && [catch {
      exec netscape $url &
   }] && [catch {
      exec mozilla $url &
   }]} {
      # Switch back to a page without frames for the Tcl HTML viewer
      set arr(Index) "about.html"
      ViewFile [file join $dir $arr($name)] [list "Index" [file join $dir $arr(Index)]]
   }
}

#######################################################################
# Derived from sample.tcl :
# Simple HTML display library version 0.3 by Stephen Uhler (stephen.uhler@sun.com)
# Copyright (c) 1995 by Sun Microsystems

# Go render a page.  We have to make sure we don't render one page while
# still rendering the previous one.  If we get here from a recursive 
# invocation of the event loop, cancel whatever we were rendering when
# we were called.
# If we have a fragment name, try to go there.

proc render {t file} {
   global Url

   set fragment ""
   regexp {([^#]*)#(.+)} $file dummy file fragment
   if {$file == "" && $fragment != ""} {
      HMgoto $t $fragment
      return
   }
   HMreset_win $t
   update idletasks
   if {$fragment != ""} {
      HMgoto $t $fragment
   }
   set Url $file
   HMparse_html [get_html $file] "HMrender $t"
   HMset_state $t -stop 1	;# stop rendering previous page if busy
}

# given a file name, return its html, or invent some html if the file can't
# be opened.

proc get_html {file} {
   if {[catch {set fd [open $file]} msg]} {
      return "
			<title>Bad file $file</title>
			<h1>Error reading $file</h1><p>
			$msg<hr>
		"
   }
   set result [read $fd]
   close $fd
   # Display text files as a single formatted field
   if {![regexp {.*\.html?$} $file]} {
      return "
        <HTML>
        <HEAD><TITLE>[file root [file tail $file]]</TITLE></HEAD>
        <BODY><PRE>$result</PRE></BODY>
        </HTML>
        "
   }
   return $result
}

# Override the library link-callback routine for the sample app.
# It only handles the simple cases.

proc HMlink_callback {win href} {
   global Url
   
   if {[string match #* $href]} {
	render $win $href
	return
     }
   if {[string match /* $href]} {
      set Url $href
   } else {
      set Url [file dirname $Url]/$href
   }
   update
   render $win $Url
}

# Supply an image callback function
# Read in an image if we don't already have one
# callback to library for display

proc HMset_image {win handle src} {
   global Url
   if {[string match /* $src]} {
      set image $src
   } else {
      set image [file dirname $Url]/$src
   }
   update
   if {[string first " $image " " [image names] "] >= 0} {
      HMgot_image $handle $image
   } else {
      set type photo
      if {[file extension $image] == ".bmp"} {set type bitmap}
      catch {image create $type $image -file $image} image
      HMgot_image $handle $image
   }
}


