# RCS: @(#) $Id$

# Copyright (C) 1998-2004, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

#######################################################################

proc ViewHelp {{name "Index"} {chapter ""}} {
    #
    # Job    Manage the help inside Transcriber
    #	     
    # In     A valid entries of the following array called "arr" and an optional chapter
    # Out
    # Modify If v(browser) is not set, it is set to the default browser (except on Mac)
    #
    # Author: Mathieu MANTA, Sylvain Galliano
    # Version: 1.0 July 27, 2004
    #          1.1 November 2005

    global v

    set dir [file join [pwd] $v(path,doc) "en"]  

    set arr(Index) [file join ".." "Index.html"]
    set arr(user_manual)  "userman.php.html"
    set arr(annotation_guide) "annotation_guide_$v(lang).php.html"
    
    if {$chapter == ""} {
	set file $arr($name)
    } else {
	set file [append arr($name) \# $chapter]
    }
    puts $file
    set url [file join $dir $file]
    OpenURL file:$url
}

proc OpenURL { URL } {
    #
    # Job    Open an url with the default browser
    #	     If it doesn't work, it asks the user to define the new default browser
    #        If you want to open a file, add file: prefix to URL (ex: file:c:\tmp\try.html)
    #
    # In     A valid URL
    # Out
    # Modify If v(browser) is not set, it is set to the default browser (except on Mac)
    #
    # Mathieu MANTA  - DGA
    # V 1.0
    # July 27, 2004
    #
    global v
    
    if {$::tcl_platform(os) == "Darwin"} {
        if { $v(browser) == ""} { exec open $URL &}
        else { exec $v(browser) $URL &}
    }
    
    if {$::tcl_platform(os) == "Linux"} {
        if { $v(browser) == ""} {
            if { [catch {exec mozilla $URL &}] == 0 } {
		set v(browser) mozilla
	    } elseif { [catch {exec firefox $URL &}] == 0 } {
		set v(browser) firefox
	    } elseif { [catch {exec mozilla-firefox $URL &}] == 0 } {
		set v(browser) mozilla-firefox
	    } else {
		tk_messageBox -type ok -icon warning -message [format [Local "Please define your default browser."] ]
		set v(browser) [SelectBrowser]
                catch { exec $v(browser) $URL &}
            }
        } else {
            catch { exec $v(browser) $URL &}
        }
    }
    
    if {$::tcl_platform(platform) == "windows"} {
        if { $v(browser) == ""} {
            set v(browser) [FindWinDefaultBrowser]
        }
        catch { exec $v(browser) $URL &}
    }
}

proc FindWinDefaultBrowser {} {
    #
    # Job    Find Windows default browser in the registry
    #
    # In
    # Out    Path to the default browser
    # Modify
    #
    # Mathieu MANTA  - DGA
    # V 1.0
    # July 27, 2004
    #
    set BrowserKey [registry get HKEY_CLASSES_ROOT\\http\\shell\\open\\command ""]

    if { [string equal [string index [string trim $BrowserKey " "] 0] "\""]} {
        set BrowserPath [string trimleft $BrowserKey "\""]
        set BrowserPath [string range $BrowserPath 0 [expr { [string first "\"" $BrowserPath ]-1}]]

    } else {
        set BrowserPath [string range $BrowserKey 0 [string first " " $BrowserKey ]]
    }
    return $BrowserPath
}


proc SelectBrowser {{parent "."}} {
    #
    # Job    Select default browser through selection box
    #
    # In
    # Out    Return the path to the file selected
    #
    # Mathieu MANTA  - DGA
    # V 1.0
    # July 27, 2004
    #

    global v

    set name [tk_getOpenFile -title [Local "Select your default browser"] -initialdir $v(trans,path) -parent $parent]

    return $name
}

