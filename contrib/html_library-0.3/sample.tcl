#!/bin/sh
# here is a sample html viewer to demonstrate the library usage
# Copyright (c) 1995 by Sun Microsystems
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# This REQUIRES Tk4.0 -- make sure "wish" on the next line is a 4.0 version
# The next line is a TK comment, but a shell command \
  exec wish4.0 -f "$0" "$@" & exit 0

if {$tk_version < 4.0 || [regexp {b[123]} $tk_patchLevel] } {
	puts stderr "This library requires TK4.0, this is only $tk_version, \
			patchlevel $tk_patchLevel"
	exit 1
}
if {[catch {array get env *}]} {
	puts stderr "This library requires tcl7.4, this version is too old!"
	exit 1
}
puts stderr "Starting sample HTML viewer..."
source html_library.tcl

# construct a simple user interface

proc setup {} {
	frame .frame
	menubutton .menu -relief raised -bd 2 -text options... -menu .menu.m
	button .quit  -command exit  -text quit
	entry .entry  -textvariable Url -width 35
	label .file  -text file:
	label .status -textvariable Running -width 6 -relief ridge \
			-bd 2 -padx 9 -pady 3
	label .msg -textvariable message
	scrollbar .scrollbar  -command ".text yview"  -orient v
	option add *Text.height 40 startup
	option add *Text.width 80 startup
	text .text  -yscrollcommand ".scrollbar set" -padx 3 -pady 3 -takefocus 0

	pack .frame .msg -side top
	pack .scrollbar -side left -expand 0 -fill y
	pack .text -side left -fill both -expand 1
	pack .file .entry .status .menu .quit -in .frame -side left

	# set up some sample keyboard bindings for the text widget
	bind .entry <Return> {render $Url}
	bind all <End> {.text yview end}
	bind all <Home> {.text yview 0.0}
	bind all <Next> {.text yview scroll 1 page}
	bind all <Prior> {.text yview scroll -1 page}

	# I'm constantly being criticized for never using menus.
	# so here's a menu.  So there.
	menu .menu.m
	.menu.m add command -label "option menu"
	.menu.m add separator
	.menu.m add command -label "font size" -foreground red 
	.menu.m add radiobutton -label small -value 0   -variable Size \
		-command {HMset_state .text -size $Size; render $Url}
	.menu.m add radiobutton -label medium -value 4  -variable Size \
		-command {HMset_state .text -size $Size; render $Url}
	.menu.m add radiobutton -label large -value 12  -variable Size \
		-command {HMset_state .text -size $Size; render $Url}
	.menu.m add separator
	.menu.m add command -label "indent level" -foreground red
	.menu.m add radiobutton -label small -value 0.6 -variable Indent \
		-command {HMset_indent .text $Indent}
	.menu.m add radiobutton -label medium -value 1.2 -variable Indent \
		-command {HMset_indent .text $Indent}
	.menu.m add radiobutton -label large -value 2.4 -variable Indent \
		-command {HMset_indent .text $Indent}
}

# Go render a page.  We have to make sure we don't render one page while
# still rendering the previous one.  If we get here from a recursive 
# invocation of the event loop, cancel whatever we were rendering when
# we were called.
# If we have a fragment name, try to go there.

proc render {file} {
	global HM.text Url
	global Running message

	set fragment ""
	regexp {([^#]*)#(.+)} $file dummy file fragment
	if {$file == "" && $fragment != ""} {
		HMgoto .text $fragment
		return
	}
	HMreset_win .text
	set Running busy
	set message "Displaying $file"
	update idletasks
	if {$fragment != ""} {
		HMgoto .text $fragment
	}
	set Url $file
	HMparse_html [get_html $file] {HMrender .text}
	set Running ready
	HMset_state .text -stop 1	;# stop rendering previous page if busy
	set message ""
}

# given a file name, return its html, or invent some html if the file can't
# be opened.

proc get_html {file} {
	global Home
	if {[catch {set fd [open $file]} msg]} {
		return "
			<title>Bad file $file</title>
			<h1>Error reading $file</h1><p>
			$msg<hr>
			<a href=$Home>Go home</a>
		"
	}
	set result [read $fd]
	close $fd
	return $result
}

# Override the library link-callback routine for the sample app.
# It only handles the simple cases.

proc HMlink_callback {win href} {
	global Url

	if {[string match #* $href]} {
		render $href
		return
	}
	if {[string match /* $href]} {
		set Url $href
	} else {
		set Url [file dirname $Url]/$href
	}
	update
	render $Url
}

# Supply an image callback function
# Read in an image if we don't already have one
# callback to library for display

proc HMset_image {win handle src} {
	global Url message
	if {[string match /* $src]} {
		set image $src
	} else {
		set image [file dirname $Url]/$src
	}
	set message "fetching image $image"
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

# Handle base tags.  This breaks if more than 1 base tag is in the document

proc HMtag_base {win param text} {
	global Url
	upvar #0 HM$win var
	HMextract_param $param href Url
}

# downloading fonts can take a long time.  We'll override the default
# font-setting routine to permit better user feedback on fonts.  We'll
# keep our own list of installed fonts on the side, to guess when delays
# are likely

proc HMset_font {win tag font} {
	global message Fonts
	if {![info exists Fonts($font)]} {
		set Fonts($font) 1
		.msg configure -fg blue
		set message "downloading font $font"
		update
	}
	.msg configure -fg black
	set message ""
	catch {$win tag configure $tag -font $font} message
}

# Lets invent a new HTML tag, just for fun.
# Change the color of the text. Use html tags of the form:
# <color value=blue> ... </color>
# We can invent a new tag for the display stack.  If it starts with "T"
# it will automatically get mapped directly to a text widget tag.

proc HMtag_color {win param text} {
	upvar #0 HM$win var
	set value bad_color
	HMextract_param $param value
	$win tag configure $value -foreground $value
	HMstack $win "" "Tcolor $value"
}

proc HMtag_/color {win param text} {
	upvar #0 HM$win var
	HMstack $win / "Tcolor {}"
}

# Add a font size manipulation primitive, so we can use this sample program
# for on-line presentations.  sizes prefixed with + or - are relative.
#  <font size=[+-]3>  ..... </font>.  Note that this is not the same as
# Netscape's <font> tag.

proc HMtag_font {win param text} {
	upvar #0 HM$win var
	set size 0; set sign ""
	HMextract_param $param size
	regexp {([+-])? *([0-9]+)} $size dummy sign size
	if {$sign != ""} {
		set size [expr [lindex $var(size) end] $sign $size]
	}
	HMstack $win {} "size $size"
}

# This version is closer to what Netscape does

proc HMtag_font {win param text} {
	upvar #0 HM$win var
	set size 0; set sign ""
	HMextract_param $param size
	regexp {([+-])? *([0-9]+)} $size dummy sign size
	if {$sign != ""} {
		set size [expr [lindex $var(size) end] $sign  $size*2]
		HMstack $win {} "size $size"
	} else {
		HMstack $win {} "size [expr 10 + 2 * $size]"
	}
}

proc HMtag_/font {win param text} {
	upvar #0 HM$win var
	HMstack $win / "size {}"
}

# set initial values
set Size 4					;# font size adjustment
set Indent 1.2				;# tab spacing (cm)
set Home [pwd]/html/help.html		;# home document
set Url $Home				;# current file
set Running busy			;# page status
set message ""				;# message line

# make the interface and render the home page
catch setup		;# the catch lets us re-source this file
HMinit_win .text
HMset_state .text -size $Size
HMset_indent .text $Indent
render $Home
