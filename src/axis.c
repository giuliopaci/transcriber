/* 
 * RCS: @(#) $Id$
 *
 * Copyright (C) 1998-2000, DGA - part of the Transcriber program
 * distributed under the GNU General Public License (see COPYING file)
 */

/* Tk Widget in C for axis */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <tcl.h>
#include <tk.h>

#define PACKAGE_NAME    "Axis"
#define PACKAGE_VERSION "1.0"

/* automatic update of named fonts using private or public API */
#if TCL_MAJOR_VERSION == 8 && TCL_MINOR_VERSION <= 3
/* from tkInt.h for automatic update of named fonts */
typedef Window (TkClassCreateProc) _ANSI_ARGS_((Tk_Window tkwin,
	Window parent, ClientData instanceData));
typedef void (TkClassGeometryProc) _ANSI_ARGS_((ClientData instanceData));
typedef void (TkClassModalProc) _ANSI_ARGS_((Tk_Window tkwin,
	XEvent *eventPtr));
typedef struct TkClassProcs {
    TkClassCreateProc *createProc;
    TkClassGeometryProc *geometryProc;
    TkClassModalProc *modalProc;
} TkClassProcs;
EXTERN void		TkSetClassProcs _ANSI_ARGS_((Tk_Window tkwin,
			    TkClassProcs *procs, ClientData instanceData));
#else
#define TkSetClassProcs Tk_SetClassProcs
#define TkClassProcs Tk_ClassProcs
#endif


/* --------------------------------------------------------------------- */

/* Widget data structure */
typedef struct {
   Tk_Window tkwin;
   Display *display;
   Tcl_Interp *interp;
   Tcl_Command tclCmd;

   /* Widget attributes */
   Tk_3DBorder background;
   XColor *foreground;
   XColor *highlight;
   int borderwidth;
   int padX;
   int padY;
   Tk_Font font;
   double begin;
   double length;
   char *side;
   char *units;

   /* Graphic contexts, internals */
   int flags;
   Pixmap pixmap;
   int pixwidth;
   int pixheight;
   GC gc;

   double end;
   double step;
   int periodUnits;
   int digit;
   int widthTxt;
   int heightTxt;
   int down;
   int seconds;
} Axis;

/* Flags definition */
#define REDRAW 0x1
#define REALLY 0x2
#define FOCUS  0x4

/* Widget attributes descriptions */
static Tk_ConfigSpec configSpecs[] = {
    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "light blue", Tk_Offset(Axis, background),
        TK_CONFIG_COLOR_ONLY},
    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "white", Tk_Offset(Axis, background),
        TK_CONFIG_MONO_ONLY},
    {TK_CONFIG_SYNONYM, "-bg", "background", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_PIXELS, "-borderwidth", "borderWidth", "BorderWidth",
        "2", Tk_Offset(Axis, borderwidth), 0},
    {TK_CONFIG_SYNONYM, "-bd", "borderWidth", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_COLOR, "-foreground", "foreground", "Foreground",
        "black", Tk_Offset(Axis, foreground), 0},
    {TK_CONFIG_SYNONYM, "-fg", "foreground", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_COLOR, "-highlightcolor", "highlightColor", "HighlightColor",
        "red", Tk_Offset(Axis, highlight), 0},

    {TK_CONFIG_FONT, "-font", "font", "Font",
        "Courier 12", Tk_Offset(Axis, font), 0},

    {TK_CONFIG_PIXELS, "-padx", "padX", "Pad",
        "10", Tk_Offset(Axis, padX), 0},
    {TK_CONFIG_PIXELS, "-pady", "padY", "Pad",
        "3", Tk_Offset(Axis, padY), 0},

    {TK_CONFIG_STRING, "-side", "side", "Side",
        "down", Tk_Offset(Axis, side), 0},
    {TK_CONFIG_STRING, "-units", "units", "Units",
        "seconds", Tk_Offset(Axis, units), 0},

    {TK_CONFIG_DOUBLE, "-begin", "begin", "Begin",
        "0", Tk_Offset(Axis, begin), 0},
    {TK_CONFIG_DOUBLE, "-length", "length", "Length",
        "10", Tk_Offset(Axis, length), 0},

    {TK_CONFIG_END, (char *) NULL, (char *) NULL, (char *) NULL,
        (char *) NULL, 0, 0}
};

/* Prototypes (C ANSI pour l'instant) */
int AxisCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
static int AxisInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[]);
static int AxisConfigure( Tcl_Interp *interp, Axis *axisPtr,
		      int argc, char *argv[], int flags);
static void AxisDisplay(ClientData clientData);
static void AxisEventProc(ClientData clientData, XEvent *eventPtr);
static void AxisDestroy(char *blockPtr);
static void AxisWorldChanged(ClientData instanceData);


/* --------------------------------------------------------------------- */

/* Package initialisation */
int Axis_Init( Tcl_Interp *interp)
{
   if (Tcl_PkgProvide( interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
      return TCL_ERROR;
   }

   Tcl_CreateCommand( interp, "axis", AxisCmd,
		      (ClientData)Tk_MainWindow(interp),
		      (Tcl_CmdDeleteProc *)NULL);
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

/* Widget class command */
int AxisCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[])
{
   Tk_Window main = (Tk_Window) clientData;
   Axis *axisPtr;
   Tk_Window tkwin;
   static TkClassProcs AxisProcs = { NULL, AxisWorldChanged, NULL};

   /* Cree une fenetre */
   if (argc < 2) {
      Tcl_AppendResult(interp, "Wrong # args: should be '",
		       argv[0], " pathname ?options?'", (char *)NULL);
      return TCL_ERROR;
   }
   tkwin = Tk_CreateWindowFromPath( interp, main, argv[1], (char *)NULL);
   if (tkwin == NULL) {
      return TCL_ERROR;
   }
   Tk_SetClass( tkwin, "Axis");

   /* Initialise les donnees */
   axisPtr = (Axis *) Tcl_Alloc(sizeof(Axis));
   TkSetClassProcs(tkwin, &AxisProcs, (ClientData) axisPtr);
   axisPtr->tkwin = tkwin;
   axisPtr->display = Tk_Display(tkwin);
   axisPtr->interp = interp;
   axisPtr->background = NULL;
   axisPtr->foreground = NULL;
   axisPtr->highlight = NULL;
   axisPtr->borderwidth = 0;
   axisPtr->font = NULL;
   axisPtr->pixmap = 0;
   axisPtr->pixwidth = 0;
   axisPtr->pixheight = 0;
   axisPtr->gc = None;
   axisPtr->flags = 0;
   axisPtr->begin = 0;
   axisPtr->length = 0;
   axisPtr->padX = 0;
   axisPtr->padY = 0;
   axisPtr->side = NULL;
   axisPtr->units = NULL;

   /* Traitement des evenements */
   Tk_CreateEventHandler(axisPtr->tkwin,
	ExposureMask|StructureNotifyMask|FocusChangeMask,
	AxisEventProc, (ClientData) axisPtr);

   /* Cree la commande qui agit sur l'objet */
   axisPtr->tclCmd = Tcl_CreateCommand(interp,
	Tk_PathName(axisPtr->tkwin), AxisInstanceCmd,
	(ClientData) axisPtr, (Tcl_CmdDeleteProc *)NULL);

   /* Analyse les options */
   if (AxisConfigure(interp, axisPtr, argc-2, argv+2, 0) != TCL_OK) {
      Tk_DestroyWindow(axisPtr->tkwin);
      return TCL_ERROR;
   }

   /* Retourne le nom de la fenetre */
   interp->result = Tk_PathName(axisPtr->tkwin);
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

/* Widget instance command */
int AxisInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[])
{
   Axis *axisPtr = (Axis *)clientData;
   int len;

   if (argc < 2) {
      Tcl_AppendResult(interp, "wrong # args: should be '",
		       argv[0], " option ?arg ...?'", (char *)NULL);
      return TCL_ERROR;
   }
   len = strlen(argv[1]);
   if ((strncmp(argv[1],"cget",len)==0) && (len>=2)) {
      if (argc==3) {
	 return Tk_ConfigureValue( interp, axisPtr->tkwin, configSpecs,
				  (char *) axisPtr, argv[2], 0);
      } else {
	 Tcl_AppendResult(interp, "wrong # args: should be '", argv[0],
			  " cget option'", (char *)NULL);
	 return TCL_ERROR;
      }
   } else if ((strncmp(argv[1],"configure",len)==0) && (len>=2)) {
      if (argc==2) {
	 return Tk_ConfigureInfo( interp, axisPtr->tkwin, configSpecs,
				  (char *) axisPtr, (char *)NULL, 0);
      } else if (argc==3) {
	 return Tk_ConfigureInfo( interp, axisPtr->tkwin, configSpecs,
				  (char *) axisPtr, argv[2], 0);
      } else {
	 return AxisConfigure( interp, axisPtr, argc-2, argv+2,
				 TK_CONFIG_ARGV_ONLY);
      }
   } else if ((strncmp(argv[1],"xview",len)==0) && (len>=2)) {
      if (argc==2) {
	 return TCL_ERROR;
      } else if (argc==3) {
	 return TCL_ERROR;
      }
   } else {
      Tcl_AppendResult(interp, "bad option '", argv[1],
		       "': must be cget, configure or xview", (char *)NULL);
      return TCL_ERROR;
   }
   return TCL_ERROR;
}

/* --------------------------------------------------------------------- */

/* Layout for time indice */
static  Tk_TextLayout AxisLayout( Axis *a, double t, int *wTxt, int *hTxt)
{
   static char txt[30];
   Tk_TextLayout layout;
   int hh,mm;

   /* Conversion time (s) -> hh:mm:ss.sss */
   if ((a->seconds) && (t>=3600)) {
      hh = floor(t/3600); t=t-hh*3600;
      mm = floor(t/60);   t=t-mm*60;
      sprintf(txt,"%d:%.2d:%0*.*f", hh, mm, a->digit+2, a->digit, t);
   } else if ((a->seconds) && (t>=60)) {
      mm = floor(t/60);   t=t-mm*60;
      sprintf(txt,"%d:%0*.*f", mm, a->digit+2, a->digit, t);
   } else {
      sprintf(txt,"%.*f", a->digit, t);
   }
   layout = Tk_ComputeTextLayout( a->font, txt, strlen(txt),
				  0, TK_JUSTIFY_CENTER, 0, wTxt, hTxt);
   return layout;
}


/* Widget (re)configuration */
int AxisConfigure( Tcl_Interp *interp, Axis *a,
		      int argc, char *argv[], int flags)
{
   double stepUnits, nbUnits;
   Tk_TextLayout layout;
   int height;

   if (Tk_ConfigureWidget( interp, a->tkwin, configSpecs,
         argc, argv, (char *) a, flags) != TCL_OK) {
      return TCL_ERROR;
   }

   /* Initial background */
   /* Tk_SetWindowBackground(a->tkwin,
      Tk_3DBorderColor(a->background)->pixel); */

   /* Compute some characteristics of scale and indices */
   a->seconds = !strcmp(a->units,"seconds");
   /* Nb of units in interval */
   if (a->length <= 0) a->length = 1.0;
   a->end = a->begin + a->length;
   if ((a->seconds) && (a->length >= 3600)) {
      stepUnits = 3600*pow(10.0, floor(log10(a->length/3600)+0.01));
   } else if ((a->seconds) && (a->length >= 60)) {
      stepUnits = 60*pow(10.0, floor(log10(a->length/60)+0.01));
   } else {
      stepUnits = pow(10.0, floor(log10(a->length)+0.01));
   }
   nbUnits = a->length / stepUnits + 0.01;
   /* Choose a given number of sub-units between 2 units */
   if ((a->seconds) && ((stepUnits==3600)||(stepUnits==60)) && (nbUnits<2))
      a->periodUnits = 6;
   else
      a->periodUnits = (nbUnits < 2) ? 5 : (nbUnits < 5) ? 2 : 1;
   /* Step between sub-units */
   a->step = stepUnits / a->periodUnits;
   /* Significant digits to print */
   a->digit = (a->step>=1) ? 0 : -floor(log10(a->step));
   /* Max size of text indice */
   layout = AxisLayout( a, a->end, &(a->widthTxt), &(a->heightTxt));
   Tk_FreeTextLayout( layout);
   /* Position of the text relative to the axis */
   a->down = !strcmp(a->side,"down");

   /* default geometry */
   height = a->heightTxt + 2*(a->borderwidth + a->padY) + 8;
   Tk_GeometryRequest( a->tkwin, 300, height);

   AxisWorldChanged((ClientData) a);
   return TCL_OK;
}

void
AxisWorldChanged(ClientData clientData)
{
   XGCValues gcValues;
   GC newGC;
   Axis *a = (Axis *)clientData;

   /* Set graphic context */
   gcValues.background = Tk_3DBorderColor(a->background)->pixel;
   gcValues.foreground = a->foreground->pixel;
   gcValues.font = Tk_FontId(a->font);
   gcValues.graphics_exposures = False;
   newGC = Tk_GetGC(a->tkwin,
         GCBackground|GCForeground|GCFont|GCGraphicsExposures, &gcValues);
   if (a->gc != None) {
      Tk_FreeGC(a->display, a->gc);
   }
   a->gc = newGC;

   /* request display */
   if ((a->tkwin != NULL)
         && Tk_IsMapped( a->tkwin)
         && !(a->flags & REDRAW)) {
      Tk_DoWhenIdle( AxisDisplay, (ClientData) a);
      a->flags |= REDRAW;      
   }
   a->flags |= REALLY;      
}    

/* --------------------------------------------------------------------- */

static void AxisReallyDraw(Axis *a)
{
   int bd = a->borderwidth;
   int bdX = bd + a->padX;
   int bdY = bd + a->padY;
   int x1, y1, x2, y2, hStr, wStr, periodTxt, vMove;
   double t, indice, hRatio;
   Tk_TextLayout layout;

   /* Horizontal axis on background */
   Tk_Fill3DRectangle( a->tkwin, a->pixmap, a->background,
         0, 0, a->pixwidth, a->pixheight, a->borderwidth, TK_RELIEF_RIDGE);
   x1 = bdX; x2 = a->pixwidth-bdX-1;
   y1 = y2 = a->down ? bd : a->pixheight-bd-1;
   XDrawLine(a->display, a->pixmap, a->gc, x1, y1, x2, y2);

   /* Draw scale on axis */
   hRatio = (a->pixwidth-2*bdX-1)/a->length;
   vMove = (a->pixheight-2*bdY-a->heightTxt)/2;
   if (vMove < 1) vMove=1; if (!a->down) vMove *= -1;
   periodTxt = (a->widthTxt*1.25)/(a->step*hRatio) + 1;
   indice = ceil(a->begin / a->step);
   t = indice * a->step;
   /* y1 = y2 = a->down ? bdY : a->pixheight-bdY-1; */
   while (t <= a->end) {
      x1 = x2 = bdX + (t - a->begin)*hRatio + 0.5;
      if (fmod( indice, a->periodUnits) == 0) {
	 y2 = y1+2*vMove;
      } else {
	 y2 = y1+vMove;
      }
      XDrawLine(a->display, a->pixmap, a->gc, x1,y1,x2,y2);

      if (fmod( indice, periodTxt) == 0) {
	 layout = AxisLayout( a, t, &wStr, &hStr);
	 x1 = x1-wStr/2; x2 = x1+wStr;
	 y2 = a->down ? (a->pixheight-bdY-a->heightTxt) : bdY;
	 if ((x1 > a->borderwidth)&&(x2<a->pixwidth-a->borderwidth)) {
	    Tk_DrawTextLayout( a->display, a->pixmap, a->gc,
			       layout, x1, y2, 0, -1);
	 }
	 Tk_FreeTextLayout( layout);
      }

      indice ++;
      t = indice * a->step;
   }
}

/* Display */
static void AxisDisplay(ClientData clientData)
{
   Axis *axisPtr = (Axis *)clientData;
   Tk_Window tkwin = axisPtr->tkwin;
   int width, height;
   /* static int i=0; */

   axisPtr->flags &= ~REDRAW;
   if ((tkwin == NULL) || !Tk_IsMapped(tkwin))
      return;
   
   /* Create new pixmap only if resize */
   width =  Tk_Width(tkwin);
   height = Tk_Height(tkwin);
   if ((axisPtr->pixwidth !=width) || (axisPtr->pixheight != height)) {
      axisPtr->flags |= REALLY;      
      /* fprintf(stderr,"New pixmap %dx%d\n",width,height); */
      axisPtr->pixwidth = width;
      axisPtr->pixheight = height;
      /* free old pixmap */
      if (axisPtr->pixmap != 0)
	 Tk_FreePixmap(axisPtr->display, axisPtr->pixmap);
      axisPtr->pixmap = Tk_GetPixmap(axisPtr->display, Tk_WindowId(tkwin),
            width, height, Tk_Depth(tkwin));
   }
   
   if (axisPtr->flags & REALLY) {
      /* fprintf(stderr,"Display %d\n", i++);*/
      AxisReallyDraw( axisPtr);
      axisPtr->flags &= ~REALLY;      
   }

   XCopyArea( axisPtr->display, axisPtr->pixmap,
	      Tk_WindowId(tkwin), axisPtr->gc,
	      0, 0, width, height, 0, 0);

   return;
}

/* Window Event Procedure */
static void AxisEventProc(ClientData clientData, XEvent *eventPtr)
{
   Axis *axisPtr = (Axis *)clientData;

   switch (eventPtr->type) {
   case Expose:
      if (eventPtr->xexpose.count == 0) goto redraw;
      break;
   case ConfigureNotify:
      goto redraw;
      break;
   case DestroyNotify:
      Tcl_DeleteCommandFromToken( axisPtr->interp, axisPtr->tclCmd);
      axisPtr->tkwin = NULL;
      if (axisPtr->flags & REDRAW) {
	 Tk_CancelIdleCall( AxisDisplay, (ClientData) axisPtr);
	 axisPtr->flags &= ~REDRAW;
      }
      Tcl_EventuallyFree( (ClientData) axisPtr, AxisDestroy);
      break;
   case FocusIn:
      /* fprintf(stderr,"FocusIn\n"); */
      axisPtr->flags |= FOCUS;
      break;
   case FocusOut:
      axisPtr->flags &= ~FOCUS;
      break;
   }
   return;

redraw:
   if ((axisPtr->tkwin != NULL) && !(axisPtr->flags & REDRAW)) {
      Tk_DoWhenIdle( AxisDisplay, (ClientData) axisPtr);
      axisPtr->flags |= REDRAW;
   }
}

/* Destroy */
static void AxisDestroy(char *blockPtr)
{
   Axis *axisPtr = (Axis *)blockPtr;

   if (axisPtr->gc != None) {
      Tk_FreeGC(axisPtr->display, axisPtr->gc);
   }
   if (axisPtr->flags & REDRAW) {
      Tk_CancelIdleCall( AxisDisplay, (ClientData) axisPtr);
   }
   Tk_FreeOptions( configSpecs, (char *) axisPtr, axisPtr->display, 0);
   Tcl_Free( (char *) axisPtr);
}


