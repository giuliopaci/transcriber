/*
 * tkMacOSA.r --
 *
 *	This file creates resources used by the AppleScript package.
 *
 * Copyright (c) 1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * SCCS: @(#) tclMacOSA.r 1.3 97/01/22 19:55:05
 */

#include <Types.r>
#include <SysTypes.r>

/*
 * The folowing include and defines help construct
 * the version string for Tcl.
 */

#define SCRIPT_MAJOR_VERSION 1		/* Major number */
#define SCRIPT_MINOR_VERSION  4		/* Minor number */
#define SCRIPT_RELEASE_SERIAL  3	/* Really minor number! */
#define RELEASE_LEVEL alpha		/* alpha, beta, or final */
#define SCRIPT_VERSION "1.4"
#define SCRIPT_PATCH_LEVEL "1.4.3"
#define FINAL 0				/* Change to 1 if final version. */

#if FINAL
#   define MINOR_VERSION (SCRIPT_MINOR_VERSION * 16) + SCRIPT_RELEASE_SERIAL
#else
#   define MINOR_VERSION SCRIPT_MINOR_VERSION * 16
#endif

#define RELEASE_CODE 0x00

resource 'vers' (1) {
	SCRIPT_MAJOR_VERSION, MINOR_VERSION,
	RELEASE_LEVEL, 0x00, verUS,
	SCRIPT_PATCH_LEVEL,
	SCRIPT_PATCH_LEVEL ", Claude Barras, DGA"
};

resource 'vers' (2) {
	SCRIPT_MAJOR_VERSION, MINOR_VERSION,
	RELEASE_LEVEL, 0x00, verUS,
	SCRIPT_PATCH_LEVEL,
	"Transcriber " SCRIPT_PATCH_LEVEL " © 1998-2000"
};

/*
 * The -16397 string will be displayed by Finder when a user
 * tries to open the shared library. The string should
 * give the user a little detail about the library's capabilities
 * and enough information to install the library in the correct location.  
 * A similar string should be placed in all shared libraries.
 */
resource 'STR ' (-16397, purgeable) {
	"Transcriber\n\n"
	"This library is a trans extension "
	"commands for Tcl/Tk programs.  To work properly, it "
	"should be placed in the 'Tool Command Language' folder "
	"within the Extensions folder."
};


/* 
 * Set up the pkgIndex in the resource fork of the library.
 */

#if defined(__POWERPC__)
  #define TARGET 
#else
  #define TARGET "CFM68K"
#endif

data 'TEXT' (4000,"pkgIndex",purgeable,preload) {
	"# Tcl package index file, version 1.5\n"
	"package ifneeded trans 1.5 [list load [file join $dir trans.shlb]]\n"
};
