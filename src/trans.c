/* 
 * RCS: @(#) $Id$
 */

#include <tk.h>
/* following line should be uncommented for compilation on the Mac */
/* #include "trans.h" */

/* 
 * This part taken from SNACK
 * Copyright (C) 1997-98 Kare Sjolander <kare@speech.kth.se>
 *
 */

#if defined(__WIN32__)
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  undef WIN32_LEAN_AND_MEAN
#  define EXPORT(a,b) __declspec(dllexport) a b
BOOL APIENTRY
DllMain(HINSTANCE hInst, DWORD reason, LPVOID reserved)
{
  return TRUE;
}
#else
#  define EXPORT(a,b) a b
#endif

EXTERN int AxisCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
EXTERN int SegmtCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
EXTERN int WavfmCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);

/*
extern Tk_ItemType axisType;
extern Tk_CustomOption axisTagsOption;
*/

int useOldObjAPI = 0;
int littleEndian = 0;

/* Called by "load trans" */
EXPORT(int,Trans_Init) _ANSI_ARGS_(( Tcl_Interp *interp))
{
   Tcl_CmdInfo infoPtr;
   char *version;
   int res;
   union {
     char c[sizeof(short)];
     short s;
   } order;

#ifdef USE_TCL_STUBS
   if (Tcl_InitStubs(interp, "8", 0) == NULL) {
     return TCL_ERROR;
   }
   if (Tk_InitStubs(interp, "8", 0) == NULL) {
     return TCL_ERROR;
   }
#endif

   version = Tcl_GetVar(interp, "tcl_version",
			(TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG));
   
   if (strcmp(version, "8.0") == 0) {
      useOldObjAPI = 1;
   }

   res = Tcl_PkgProvide( interp, "trans", "1.5");
   if (res != TCL_OK) return res;

  if (Tcl_GetCommandInfo(interp, "button", &infoPtr) != 0) {

   /* Tk canvas items */
/*
    Tk_CreateItemType(&axisType);
    axisTagsOption.parseProc = Tk_CanvasTagsParseProc;
    axisTagsOption.printProc = Tk_CanvasTagsPrintProc;
*/

     /* Tk widgets for waveform and segmentation display */
     Tcl_CreateCommand( interp, "axis", AxisCmd,
			(ClientData)Tk_MainWindow(interp),
			(Tcl_CmdDeleteProc *)NULL);
     Tcl_CreateCommand( interp, "segmt", SegmtCmd,
		      (ClientData)Tk_MainWindow(interp),
			(Tcl_CmdDeleteProc *)NULL);
     Tcl_CreateCommand( interp, "wavfm", WavfmCmd,
			(ClientData)Tk_MainWindow(interp),
			(Tcl_CmdDeleteProc *)NULL);
  }

   /* Determine computer byte order */
   order.s = 1;
   if (order.c[0] == 1) {
     littleEndian = 1;
   }

   return TCL_OK;
}

EXPORT(int,Trans_SafeInit)(Tcl_Interp *interp)
{
  return Trans_Init(interp);
}
