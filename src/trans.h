/* 
 * RCS: @(#) $Id$
 */

#pragma export on
EXTERN int AxisCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
EXTERN int SegmtCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
EXTERN int WavfmCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
EXTERN int Trans_Init(Tcl_Interp *interp);
EXTERN int Trans_SafeInit(Tcl_Interp *interp);
#pragma export reset
