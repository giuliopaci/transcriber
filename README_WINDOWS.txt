
                    T R A N S C R I B E R
    a free tool for segmenting, labeling and transcribing speech
                 Copyright (C) 1998-2004, DGA

WWW:    	http://www.etca.fr/CTA/gip/Projets/Transcriber/
		http://sourceforge.net/projects/trans
		http://www.ldc.upenn.edu/mirror/Transcriber/

Authors		Claude Barras, formerly DGA/DCE/CTA/GIP - now LIMSI-CNRS
		Mathieu Manta   - DGA/DCE/CTA/GIP
		Fabien Antoine  - DGA/DCE/CTA/GIP
		Sylvain Galiano - DGA/DCE/CTA/GIP

Coordinators:  Edouard Geoffrois, DGA/DCE/CTA/GIP
               Mark Liberman & Zhibiao Wu, LDC

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

---------------------------------------------------------------------

All online documentation viewable in HTML:
  doc/Index.html

following instructions from doc/en/installation.html:
---------------------------------------------------------------------

Binary installation for Windows

 1. download the last Transcriber binary package for Windows on SourceForge:

 http://sourceforge.net/project/showfiles.php?group_id=40021&package_id=51790

 2. double-click on it and follox the setup instructions


---------------------------------------------------------------------
Installation from the sources

The installation in a Windows environment looks like the Linux one because it
 also uses the tools configure and make. It consists in:

 I - installing the tools, MinGW and MinSYS, to enable to compile using make and
     configure on Windows.

 II - installing the libraries TcLex and Snack, used by Transcriber

 III - using a kit (TclKit) that embeds Tcl and Tk to source Transcriber

Hereunder, the different steps are detailed:

  1. Download Transcriber source package for Windows at 
     http://sourceforge.net/project/showfiles.php?group_id=40021&package_id=51790
     and extract it in c:\TransSource

  2. Download the MinGW binary at http://www.mingw.org/  and install it in c:\MinGW 
     (not in c:\Program Files because it does not handle paths with white spaces).
     MinGW ("Minimalistic GNU for Windows") refers to a set of runtime headers, used 
     in building a compiler system based on the GNU GCC and binutils projects.
     It compiles and links code to be run on Win32 platforms, providing C, C++ and 
     Fortran compilers plus other related tools.

  3. Download the MinSYS binary at http://www.mingw.org/ install it in c:\MSYS. 
     MinSYS or Minimal SYStem is a POSIX and Bourne shell environment use with MinGW. 
     It provides a hand picked set of tools to allow a typical configuration script 
     with Bourne syntax to execute. This allows most of the GNU packages to create 
     a Makefile just from executing the typical configure script which can then be
     used to build the package using the native MinGW version of GCC.

  4. Download Tcl/Tk binary library at http://www.mingw.org/  and install it in
     c:\MinGW . Those  libraries are used during the linkage step of the Transcriber 
     compilation.

  5. Launch MinGW (by cliquing on its icon) and move to c:\TransSource\src directory:
     cd c:\TransSource\src

  6. Launch the compilation/installation precising Tcl and Tk library paths and 
     Transcriber installation directory:

	./configure --with-tcl=/mingw/lib --with-tk=/mingw/lib/ --prefix=c:\TransBin
	make
	make install

  7. Download TclLex windows binary library at http://membres.lycos.fr/fbonnet/Tcl/tcLex/
     and extract it in c:\TransBin\lib\TcLex12a1

  8. Download the last Snack binary release for windows with Tcl/Tk at 
	http://www.speech.kth.se/snack/download.html 
     Extract it and copy the content of Snack\bin\windows (ie all .dll, .lib and 
     snack.tcl and pkgIndex.tcl) to c:\TransBin\lib\Snack

  9. Download Tclkit for Windows at http://www.equi4.com/tclkit.html and copy it 
     in c:\TransBin. This tool embeds in a single executable file all what you need 
     to source Tcl an Tk script files. To source Transcriber, you just have to 
     launch Tclkit and type :
	source c:\TransBin\lib\Transcriber1.4\tcl\Main.tcl

Note, that if you prefer to use Active Tcl (http://www.activestate.com/), in that case 
you don't have to install Snack because it is included in it. And if you want to launch
Transcriber, you just have to launch Wish and then type:

	source c:\TransBin\lib\Transcriber1.4\tcl\Main.tcl

The Tclkit solution is preferred to Active Tcl because it enables to create a 
single setup package for Transcriber which includes: the Transcriber binary and 
script files, the Snack library, the TcLex library, Tcl and Tk. And nothing else 
is needed to run Transcriber.

----------------------------------------------------------------------------
Distribution structure:

   * Structure of the source distribution :
        o Transcriber-1.4/
             + README_WINDOWS . .instructions to install Transcriber on Windows
	       + README_LINUX   . .instructions to install Transcriber on Unix/Linux
             + COPYING
             + contrib/       . . external archives
             + src/ . . . sources for new Tcl commands and Tk widgets
             + tcl/ . . . Tcl scripts.
             + convert/ . Tcl script modules for format conversion
             + img/ . . . bitmap images
             + doc/ . . . help files
             + etc/ . . . default files
             + demo/ . . .for sound and transcription files

   * Structure of the binary distribution (as a result of a standard
     installation):
        o lib/ =>
             + snack2.25-tcl/
             + tcLex1.2/
             + transcriber1.4/ =>
                  + libtrans.dll
                  + pkgIndex.tcl
                  + tcl/
                  + img/
                  + etc/
                  + doc/
             + license.txt .  .  . license agreement
		 + tclkit-win32.exe  . kit enabling to source Tcl and Tk scripts
	       + transwin.exe   .  . executable file used to launch Transcriber
		 + trs.ico     .  .  . icon of Transcriber and .trs files
             + unins000.dat   .  . data file used to uninstall Transcriber
		 + unins000.exe   .  . executable file used to uninstall Transcriber
		

----------------------------------------------------------------------------
Possible problems

   * Playback can fail if there is a mismatch between signal format and
     soundcard capabilities (e.g., 16 bits signal on audio cards which only
     support 8kHz 8 bits mu-law).
