# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

################################################################

proc CreateBrowserFrame {f}  {
    # JOB: create the Browser interface in the text widget for esay creation of entities events
    #
    # IN: f, path of the created frame
    # OUT: nothing
    # MODIFY: nothing
    #
    # Author: Fabien Antoine
    # Version: 0.1
    # Date: May 9, 2005
    global v
   
    if {[catch {package require treectrl 2.1}]} {
	if $v(frame_view,database) {
	    tk_messageBox -message "[Local "Warning, you need treectrl2.1 or newer to display the explorer pane"]" -type ok -icon error;
	}
	set v(frame_view,database) 0
	HideFrame database
	return ""
    } 

    set types {
	"All files"  
	"Transcriptions"
	"Audio files"
    }

    if {[info exists v(trans,path)]} {
	if {$v(trans,path) != ""} {
	    set path $v(trans,path)
	} else {
	    set path [file join [file dir [info script]] "../demo" ]
	    set v(trans,path) $path
	}
    } else {
	set path [file join [file dir [info script]] "../demo" ]
    }
    while {[regsub {/([^/]*)/../} $path {/} path]} {
    }
    
    set upperSndExt [string toupper $v(ext,snd)]
    set allSndExt [concat $v(ext,snd) $upperSndExt]
    set upperTrsExt [concat [string toupper $v(ext,trs)] [string toupper $v(ext,lbl)]]
    set allTrsExt [concat $v(ext,trs) $v(ext,lbl) $upperTrsExt]
    
    set listtypes [list {*} $allTrsExt $allSndExt]
    set v(explorer,filter) $allTrsExt
    
    set wf $v(frame,$f)
    if [winfo exists $wf] {
	DestroyFrame $f 
    } 
    frame $wf -bd 1 -relief raised 
    
    set entry $wf.entry
    set b_close $wf.b_close
    set b_updir $wf.b_updir
    set filter $wf.filter
    entry $entry -textvariable v(explorer,path)
    MenuButton $filter v(explorer,filter) $types $listtypes
    set lst $wf.lst
    set lvsb $wf.lvsb
    set lhsb $wf.lhsb
    
    treectrl $lst -selectmode browse -showheader yes  -background $v(color,bg-explorer) -font $v(font,explorer)
    scrollbar $lvsb -orient vertical -width 8  -command "$lst yview" -elementborderwidth 1
    scrollbar $lhsb -orient horizontal -width 8 -command "$lst xview" -elementborderwidth 1
    $lst notify bind $lvsb <Scroll-y> {%W set %l %u}
    $lst notify bind $lhsb <Scroll-x> {%W set %l %u}

    set tbl $wf.t
    set vsb $wf.vsb
    set hsb $wf.hsb
    set w_files [treectrl $tbl -selectmode browse -showheader no -showroot yes -showrootbutton no -background $v(color,bg-explorer) -font $v(font,explorer)]
    scrollbar $vsb -orient vertical -width 8  -command "$w_files yview" -elementborderwidth 1
    scrollbar $hsb -orient horizontal -width 8 -command "$w_files xview" -elementborderwidth 1
    $w_files notify bind $vsb <Scroll-y> {%W set %l %u}
    $w_files notify bind $hsb <Scroll-x> {%W set %l %u}

    # Charge le contenu de l'explorateur
    InitFilesTree $w_files
    InitDbFrame $lst

    # SelectFile $w_files $path
    set v(explorer,path) $path
    displayPath $w_files $v(explorer,path) $v(explorer,filter)

    # create the interface 
    grid $entry -row 0 -column 0 -sticky news
    grid $filter -row 0 -column 1 -sticky news  -columnspan 3
    grid $tbl -row 2 -column 0 -sticky nsew -columnspan 3
    grid $vsb -row 2 -column 3 -sticky nsew
    grid $hsb -row 3 -column 0 -sticky nsew -columnspan 3
    
    grid columnconfigure $wf 0 -weight 1
    grid rowconfigure $wf 2 -weight 1
    
    bind $tbl <Enter> {focus %W}
    bind $entry <Enter> {focus %W}
    bind $entry <Return> {displayPath $v(frame,explorer).t $v(explorer,path) $v(explorer,filter)}
    trace variable v(explorer,filter) w {UpdateExplorer 0}
    trace variable v(trans,path) w {UpdatePath}
}

proc UpdatePath {n1 n2 op} {
    global v
    set v(explorer,path) $v(trans,path)
    set tree $v(frame,explorer).t
    catch {
	displayPath $tree $v(explorer,path) $v(explorer,filter)
	UpdateExplorer 0 $n1 $n2 $op 
    }
}

proc UpdateExplorer {item n1 n2 op} {
    global v
    set tree $v(frame,explorer).t
    catch {
	$tree configure -font $v(font,explorer)
	foreach d [$tree item children $item] {
	    set path  [PathOfItem $tree $d]
	    if [$tree item isopen $d] {	
		AddFoldersAndFiles $tree $d $path $v(explorer,filter)
		UpdateExplorer $d $n1 $n2 $op
	    }
	}
    }
}

proc displayPath {tree path {filter "*" }} {
    set item [ItemOfPath $tree $path yes]
    if [file isdirectory $path] {
	AddFoldersAndFiles $tree $item $path $filter
    } 
    $tree activate $item
    $tree selection clear all
    $tree selection add $item
    $tree see $item
    focus $tree
}



proc displayDir {path {filter "Transcriptions"}} {
    global v 
    # display the content of current directory in the browser
    set tbl $v(frame,explorer).t
    $tbl resetsortinfo
    $tbl delete 0 end
    set upperSndExt [string toupper $v(ext,snd)]
    set allSndExt [concat $v(ext,snd) $upperSndExt]
    set upperTrsExt [concat [string toupper $v(ext,trs)] [string toupper $v(ext,lbl)]]
    set allTrsExt [concat $v(ext,trs) $v(ext,lbl) $upperTrsExt]
    if [catch {set files [glob  -directory $path "*"]} oops] {} else {
	foreach file $files {
	    set item {}
	    lappend item "" [file tail $file]  ""
	    if {[file isdirectory $file]} {
		$tbl insert 0 $item
		$tbl cellconfigure 0,0 -image $v(img,folder)
	    } else {
		$tbl insert end $item
		if  {[lsearch -exact $allTrsExt [file extension $file]] >=0 } {
		    $tbl cellconfigure end,0 -image $v(img,transfile)
		} elseif  {[lsearch -exact $allSndExt [file extension $file]] >=0 } {
		    $tbl cellconfigure end,0 -image $v(img,wavfile)
		}
	    }
	}
    }
}

proc dateTime t {
    clock format $t \
	-format %y-%m-%d,%H:%M:%S
}


#############################
#database
proc InitDbFrame {db} {
    global v
    
    foreach col {filename date author status path} {
	$db column create -expand yes -tag $col -text $col
	$db configure -treecolumn $col
	$db element create $col text -fill [list $v(color,bg-explorer) {selected focus} gray {selected !focus}] 
    }
    set S [$db style create s1]
    $db style elements $S  {filename date author status path}
    $db style layout $S filename -expand ns
    foreach column {date author status path} {
	$db style layout $S $column -padx {4 0} -expand ns -squeeze x
    }
    $db item style set root filename s1
    if {![info exists v(trans,list)]} {
	set v(trans,list) [list $v(trans,name)]
    }

    foreach file $v(trans,list)  {
	set item [$db item create -button no]
	$db item style set $item filename s1
	set content [list [list filename -text [file tail $file]] [list date -text "30:09:00"] [list author -text "myself"] [list status -text "on"]  [list path -text [file dirname $file]]]
	$db item complex root $content
    }
}


#############################################
#from vincent privat - explorer frame
proc InitFilesTree {tree} {
    global v
    
    # Bindings
    BindEvents $tree
    
    $tree column create -expand yes -tag c0 -text filename
    $tree configure -treecolumn c0
    
    $tree element create e1 image
    $tree element create e2 text -fill [list {slate gray} {selected focus}] -lines 1 
    $tree element create e3 rect -fill [list $v(color,bg-explorer) {selected focus} gray {selected !focus}] -showfocus yes
    
    set S [$tree style create s1]
    $tree style elements $S {e3 e1 e2}
    $tree style layout $S e1 -expand ns
    $tree style layout $S e2 -padx {4 0} -expand ns -squeeze x
    $tree style layout $S e3 -union [list e2] -iexpand ns -ipadx 2
    
    $tree item style set root c0 s1
    
    # add of the root (specific to the platform)
    switch $::tcl_platform(platform) {
	windows {
	    $tree item complex root [list [list e1 -image i_computer] [list e2 -text "Poste de travail"]]
	    set volumes [file volumes]
	}
	default {
	    $tree item complex root [list [list e1 -image $v(img,folder)] [list e2 -text "/"]]
	    set volumes [lsort -dictionary -uniq [glob -nocomplain -directory / -type d *]]
	}
    }
    
    # add of file system
    foreach vol $volumes {
	# on windows, peripheric icons are displayed
	if {$::tcl_platform(platform) == "windows"} {
	    if {[llength [set filesystem [file system $vol]]] > 1} {
		switch [string toupper [lindex $filesystem 1]] {
		    FAT {
			set img_volume i_floppy_disk
		    }
		    FAT32 -
		    NTFS {
			set img_volume i_hard_drive
		    }
		    UDF {
			set img_volume i_cd_drive
		    }
		    default {
			set img_volume i_hard_drive
			if {$debug} {tk_messageBox -message "[Local {File system not accepted}] : [lindex $filesystem 1]"}
		    }
		}
	    } elseif {![string compare -nocase $vol "A:/"]} {
		set img_volume i_floppy_disk
	    } else {
		set img_volume i_cd_drive
	    }
	    # on the others systems, the directory icon is displayed
	} else {
	    set img_volume $v(img,folder)
	}
	
	# add of the file system in the tree
	set item [$tree item create]
	$tree item style set $item c0 s1
	$tree item complex $item [list [list e1 -image $img_volume] [list e2 -text [string trim $vol /]]]
	$tree item lastchild root $item
	$tree item collapse $item
	
	# add of the content of the file system, except for floppy disk on windows (too slow)
	if {[string compare -nocase $vol "A:/"]} {
	    AddFoldersAndFiles $tree $item $vol $v(explorer,filter)
	}
    }
}

#
# AddFoldersAndFiles : 
#
proc AddFoldersAndFiles {tree parent dir {filter "*"}} {
    global v
    set childsPaths {}
    set parent [ItemOfPath $tree $dir]
    set childs [$tree item children $parent]
    foreach child $childs {
	set tmp  [PathOfItem $tree $child]
	lappend childsPaths $tmp
	set itemof($tmp) $child
    }
    # add of directories
    
    set tmp {}
    foreach f $filter {
	set f [regsub -all {\"} $f {}]
	if {![regexp {\*} $filter]} {
	    lappend tmp "*$f"
	} else {
	    lappend tmp $f
	}
    }
    
    set filter $tmp
    
    set dossiers [glob -nocomplain -directory $dir -type d *]
    set fichiers [eval glob -nocomplain -directory $dir -type f $filter]
    set n [expr [llength $dossiers] + [llength $fichiers]]
    
    set tmp $dossiers
    set dossiers [NotInList $dossiers $childsPaths]
    set tmp [concat $tmp $fichiers]
    set fichiers [NotInList $fichiers $childsPaths]
    AddChilds $tree $parent $dossiers $v(img,folder)
    AddTypedChilds $tree $parent $fichiers yes

    set toremove [NotInList $childsPaths $tmp]
    foreach r $toremove {
	$tree item delete $itemof($r)
    }
    
    # Put the "+" button depending on the number of element in the file system
    set m [llength $fichiers]
    $tree item configure $parent -button [expr $n > 0]
    
    # return the number of created element
    return [list $n $m]
}

#
# AddChilds : 
#
proc AddChilds {tree parent childs image {check_xml no}} {
    foreach child [lsort -dictionary -uniq $childs] {
	set item [$tree item create -button no]
	$tree item style set $item c0 s1
	$tree item complex $item [list [list e1 -image $image] [list e2 -text [file tail $child]]]
	# If an XML file with the name elready exists, display the name of the image in green
	if {$check_xml && [file exists [file rootname $child].xml]} {
	    $tree item element configure $item 0 e2 -fill #1bb215
	}
	$tree item lastchild $parent $item
	$tree item collapse $item
    }
}

proc NotInList {list1 list2} {
    set tmpstring "^("
    append tmpstring [join $list2 "|"]
    append tmpstring ")\$"
    set tmpstring [regsub -all {([-+\.\{\}\[\]])} $tmpstring {\\\1}]
    return [lsearch -not -inline -all -regexp $list1 $tmpstring ]
}


#
# PathOfItem : 
#
proc PathOfItem {tree item} {
    set path [$tree item text $item c0]
    foreach a [$tree item ancestors $item] {
	if {$a >  0} {set path [$tree item text $a c0]/$path}
    }
    if {$::tcl_platform(platform) != "windows"} {
	set path /$path
    }
    return $path
}

#
# ItemOfPath : 
#
proc ItemOfPath {tree path {expand no}} {
    set item 0
    while {[regsub {/([^/]*)/../} $path {/} path]} {
    }
    set localpath ""
    foreach component [file split $path] {
	if {$component != "/"} {
	    set localpath "$localpath/$component"
	    foreach d [$tree item children $item] {
		if {[PathOfItem $tree $d] == $localpath} {
		    set item $d
		    if {$expand} {
			$tree item expand $item
		    }
		    break
		}
	    }
	}
    }
    return $item
}

# FileType
proc FileType {file} {
    global v
    if {[file isfile $file]} {
	set pattern "(?i)("
	append pattern [join $v(ext,trs) "|"]
	append pattern ")\$"
	if {[lsearch -regexp $file $pattern] >= 0} {
	    if [trs::guess $file] {
		return "trans"
	    } else {
		return "text"
	    }
	}
	set pattern "(?i)("
	append pattern [join $v(ext,snd) "|"]
	append pattern ")\$"
	if {[lsearch -regexp $file $pattern] >= 0} {
	    return "sound"
	}
	return "file_other"
    } elseif {[file isdirectory $file]} {
	return "dir"
    } else {
	return "other"
    }
}

#
# AddTypedChilds
#

proc AddTypedChilds {tree parent childs {check_xml no}} {
    global v
	foreach child [lsort -dictionary -uniq $childs] {
	    set type [FileType $child]
	    switch $type {
		trans {set image $v(img,transfile)}
		sound {set image $v(img,wavfile)}
		text {set image $v(img,textfile)}
	        default {set image $v(img,empty)}
	    }
	    set item [$tree item create -button no]
	    $tree item style set $item c0 s1
	    $tree item complex $item [list [list e1 -image $image] [list e2 -text [file tail $child]]]
	    # If an XML file with the name elready exists, display the name of the image in green
	    if {$check_xml && [file exists [file rootname $child].xml]} {
		$tree item element configure $item 0 e2 -fill #1bb215
	    }
	    $tree item lastchild $parent $item
	    $tree item collapse $item
	}
}

#
# BindEvents : 
#
proc BindEvents {tree} {
    global var
    
    bind $tree <KeyPress-Left> { namespace eval ::paradi {
	if {[set item [%W item id active]] > 0} {
	    if {[%W item isopen $item]} {
		%W item collapse $item
	    } else {
		%W activate [%W item parent $item]
	    }
	}
    }}
    
    bind $tree <KeyPress-Right> { namespace eval ::paradi {
	
	if {[set child [%W item firstchild active]] != ""} {
	    if {[%W item isopen active]} {
		%W activate $child
	    } else {
		%W item expand active
	    }
	} elseif {[lindex [AddFoldersAndFiles %W active [PathOfItem %W active] $v(explorer,filter)] 0] > 0  } {
	    %W item expand active
	}
    }}
    
    $tree notify bind $tree <Expand-before> { namespace eval ::paradi {
	# generate the absolute path of the directory
	set dirpath [PathOfItem %T %I]
	# create childs files and directories of childs directories of the current item
	
	AddFoldersAndFiles %T %I $dirpath $v(explorer,filter)
	foreach d [%T item children %I] {
	    set path $dirpath/[%T item text $d c0]
	    AddFoldersAndFiles %T $d $path $v(explorer,filter)
	}
	UpdateExplorer %I "" "" ""
    }}
    
    $tree notify bind $tree <ActiveItem> { 
	namespace eval ::paradi {
	    # generate the absolute path of item
	    set dirpath [PathOfItem %T %c]
	    if {[file isdirectory $dirpath]} {
		set var(status) "[llength [%T item children %c]] objet(s)"
		set v(explorer,path) $dirpath
		
	    } elseif {![catch {set filesize [file size $dirpath]}]} {
		set v(explorer,path) [file dirname $dirpath]
		set units {octets Ko Mo Go To Po Eo Zo Yo}
		for {set i 0} {$i < [llength $units] && $filesize >= 1024} {incr i} {
		    set filesize [expr $filesize/1024.0]
		}
		set unit [lindex $units $i]
		set var(status) "Type : Image [string toupper [string trimleft [file extension $dirpath] .]] \
			Taille : [format "%%.1f" $filesize] $unit"
	    } else {
		set var(status) ""
	    }
	}}
    
    bind $tree <Double-Button-1> { namespace eval ::paradi {
	# don't touch to the root
	if {[set item [%W item id active]] > 0} {
	    set path [PathOfItem %W $item]
	    switch [FileType $path] {
		trans { ReadTrans $path }
		text  { ReadTrans $path }
		sound { NewTrans $path }
		dir {
		    if {[%W item numchildren active] == 0} {
			AddFoldersAndFiles %W active [PathOfItem %W active] $v(explorer,filter)
		    }
		    %W item toggle $item
		}
		default { 
		}
	    }
	    displayPath %W $v(trans,name) $v(explorer,filter)
	} } }
    
    bind $tree <KeyPress-Return> { namespace eval ::paradi {
	global v
	# don't touch to the root
	if {[set item [%W item id active]] > 0} {
	    set path [PathOfItem %W $item]
	    switch [FileType $path] {
		trans { ReadTrans $path }
		text  { ReadTrans $path }
		sound { NewTrans $path }
		dir {
		    if {[%W item numchildren active] == 0} {
			AddFoldersAndFiles %W active [PathOfItem %W active] $v(explorer,filter)
		    }
		    %W item toggle $item
		}
		default { 
		}
	    }
	    displayPath %W $v(trans,name) $v(explorer,filter)
	    
	} 
	
    } }
    
    bind $tree <KeyPress> { namespace eval ::paradi {
	# is keypressed an alphanumeric caracter?
	if {[string length %K] == 1 && [string is alnum %K]} {
	    set item [set active [%W item id "active"]]
	    while {1} {
		# browse of all viewable items
		set item [%W item id "$item next visible"]
		if {$item == ""} {
		    set item [%W item id "first visible"]
		}
		# stop search if all has been browsed
		if {$item == $active} {
		    break
		}
		# look at the first item letter
		set letter [string index [%W item text $item 0] 0]
		# Linux is case sensitive, Windows is not
		if { ($letter == "%K") || ($::tcl_platform(platform) == "windows" && ![string compare -nocase $letter %K]) } {
		    # if it match, change the selection and quit
		    %W activate $item
		    %W selection modify $item all
		    %W see $item
		    break
		}
	    }
	}
    }}
}