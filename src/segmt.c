/* 
 * RCS: @(#) $Id$
 *
 * Copyright (C) 1998-2000, DGA - part of the Transcriber program
 * distributed under the GNU General Public License (see COPYING file)
 */

/* Tk Widget in C for segmentation */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <tcl.h>
#include <tk.h>

#define PACKAGE_NAME    "Segmt"
#define PACKAGE_VERSION "1.0"

#ifndef MIN
# define MIN(a,b) ((a)<(b)?(a):(b))
#endif

#ifndef MAX
# define MAX(a,b) ((a)>(b)?(a):(b))
#endif

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

/* --------------------------------------------------------------------- */

/* Internal segments structure */
typedef struct {
   double beg;
   double end;
   char *txt;
   int len;
   Tk_3DBorder col;
} OneSeg;

/* Widget data structure */
typedef struct {
   Tk_Window tkwin;
   Display *display;
   Tcl_Interp *interp;
   Tcl_Command tclCmd;

   /* Widget attributes */
   Tk_3DBorder background;
   Tk_3DBorder emptySegmt;
   Tk_3DBorder fullSegmt;
   Tk_3DBorder highSegmt;
   XColor *foreground;
   int borderwidth;
   int relief;
   int padX;
   int padY;
   int hiSegmtNb;
   int height;
   Tk_Font font;
   Tk_Font tiny;
   double begin;
   double length;
   char *timeArrayName;
   char *segVarName;

   /* Graphic contexts, internals */
   int flags;
   Pixmap pixmap;
   int pixwidth;
   int pixheight;
   GC gc;
   GC gc2;

   /* Tcl_Obj *list; */
   OneSeg *listSeg;
   char *indice;
   int nbSeg;
   double end;
   double step;
   int digit;
   Tk_FontMetrics fm;
   int widthTxt;
   int heightTxt;
   Tcl_HashTable borderTable;
} Segmt;

/* Flags definition */
#define REDRAW 0x1
#define REALLY 0x2
#define SEGVAR 0x4
#define TIMVAR 0x8
#define FOCUS  0x10

typedef enum {
  OPTION_SEGNAME,
  OPTION_TIMENAME
} ConfigSpec;

/* Widget attributes descriptions */
static Tk_ConfigSpec configSpecs[] = {
    {TK_CONFIG_STRING, "-segmentvariable", "segmentVariable", "Variable",
        "", Tk_Offset(Segmt, segVarName), 0},
    {TK_CONFIG_STRING, "-timearray", "timeArray", "Array",
        "", Tk_Offset(Segmt, timeArrayName), 0},

    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "light blue", Tk_Offset(Segmt, background),
        TK_CONFIG_COLOR_ONLY},
    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "white", Tk_Offset(Segmt, background),
        TK_CONFIG_MONO_ONLY},
    {TK_CONFIG_SYNONYM, "-bg", "background", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_BORDER, "-emptybackground", "emptyBackground", "Background",
     NULL, Tk_Offset(Segmt, emptySegmt), TK_CONFIG_NULL_OK},
    {TK_CONFIG_BORDER, "-fullbackground", "fullBackground", "Background",
     NULL, Tk_Offset(Segmt, fullSegmt), TK_CONFIG_NULL_OK},
    {TK_CONFIG_BORDER, "-highbackground", "highBackground", "Background",
     NULL, Tk_Offset(Segmt, highSegmt), TK_CONFIG_NULL_OK},
    {TK_CONFIG_INT, "-currentsegment", "currentSegment", "Segment",
     "-1", Tk_Offset(Segmt, hiSegmtNb), 0},

    {TK_CONFIG_COLOR, "-foreground", "foreground", "Foreground",
        "black", Tk_Offset(Segmt, foreground), 0},
    {TK_CONFIG_SYNONYM, "-fg", "foreground", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_PIXELS, "-borderwidth", "borderWidth", "BorderWidth",
        "2", Tk_Offset(Segmt, borderwidth), 0},
    {TK_CONFIG_SYNONYM, "-bd", "borderWidth", (char *) NULL,
        (char *) NULL, 0, 0},
    {TK_CONFIG_RELIEF, "-relief", "relief", "Relief",
        "raised", Tk_Offset(Segmt, relief), 0},


    {TK_CONFIG_FONT, "-font", "font", "Font",
        "Courier 12", Tk_Offset(Segmt, font), 0},
    {TK_CONFIG_FONT, "-tiny", "tiny", "Font",
        NULL, Tk_Offset(Segmt, tiny), TK_CONFIG_NULL_OK},

    {TK_CONFIG_PIXELS, "-padx", "padX", "Pad",
        "3m", Tk_Offset(Segmt, padX), 0},
    {TK_CONFIG_PIXELS, "-pady", "padY", "Pad",
        "1m", Tk_Offset(Segmt, padY), 0},
    {TK_CONFIG_INT, "-height", "height", "Height",
        "1", Tk_Offset(Segmt, height), 0},

    {TK_CONFIG_DOUBLE, "-begin", "begin", "Begin",
        "0", Tk_Offset(Segmt, begin), 0},
    {TK_CONFIG_DOUBLE, "-length", "length", "Length",
        "10", Tk_Offset(Segmt, length), 0},

    {TK_CONFIG_END, (char *) NULL, (char *) NULL, (char *) NULL,
        (char *) NULL, 0, 0}
};

/* Prototypes (C ANSI pour l'instant) */
int SegmtCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
static int SegmtInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[]);
static int SegmtConfigure( Tcl_Interp *interp, Segmt *segmtPtr,
		      int argc, char *argv[], int flags);
static void SegmtWorldChanged(ClientData instanceData);
static void SegmtDisplay(ClientData clientData);
static void AskRedraw(Segmt *a, int flag);
static void SegmtEventProc(ClientData clientData, XEvent *eventPtr);
static void SegmtDestroy(char *blockPtr);
static char *SegmtVarProc(ClientData clientData, Tcl_Interp *interp,
                        char *name1, char *name2, int flags);
static char *TimeVarProc(ClientData clientData, Tcl_Interp *interp,
                        char *name1, char *name2, int flags);
static int ParseSegmentVar (Segmt *a);
Tk_3DBorder GetBorder(Segmt *a, char *colorName);

/* --------------------------------------------------------------------- */

static char *StringDup( char *s) 
{
   int l = strlen(s);
   char *t = Tcl_Alloc(l+1);
   strncpy( t, s, l);
   t[l] = '\0';
   return t;
}

/* --------------------------------------------------------------------- */

/* Package initialisation */
int Segmt_Init( Tcl_Interp *interp)
{
   if (Tcl_PkgProvide( interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
      return TCL_ERROR;
   }

   Tcl_CreateCommand( interp, "segmt", SegmtCmd,
		      (ClientData)Tk_MainWindow(interp),
		      (Tcl_CmdDeleteProc *)NULL);
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

/* Widget class command */
int SegmtCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[])
{
   Tk_Window main = (Tk_Window) clientData;
   Segmt *segmtPtr;
   Tk_Window tkwin;
   static TkClassProcs SegmtProcs = { NULL, SegmtWorldChanged, NULL};

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
   Tk_SetClass( tkwin, "Segmt");

   /* Initialise les donnees */
   segmtPtr = (Segmt *) Tcl_Alloc(sizeof(Segmt));
   TkSetClassProcs(tkwin, &SegmtProcs, (ClientData) segmtPtr);
   segmtPtr->tkwin = tkwin;
   segmtPtr->display = Tk_Display(tkwin);
   segmtPtr->interp = interp;
   segmtPtr->background = NULL;
   segmtPtr->foreground = NULL;
   segmtPtr->borderwidth = 0;
   segmtPtr->relief = TK_RELIEF_FLAT;
   segmtPtr->emptySegmt = NULL;
   segmtPtr->fullSegmt = NULL;
   segmtPtr->highSegmt = NULL;
   segmtPtr->hiSegmtNb = 0;
   segmtPtr->font = NULL;
   segmtPtr->tiny = NULL;
   segmtPtr->pixmap = 0;
   segmtPtr->pixwidth = 0;
   segmtPtr->pixheight = 0;
   segmtPtr->gc = None;
   segmtPtr->gc2 = None;
   segmtPtr->flags = 0;
   segmtPtr->begin = 0;
   segmtPtr->end = 0;
   segmtPtr->padX = 0;
   segmtPtr->padY = 0;
   segmtPtr->height = 0;
   /* segmtPtr->list = NULL; */
   segmtPtr->nbSeg = 0;
   segmtPtr->listSeg = NULL;
   segmtPtr->timeArrayName = NULL;
   segmtPtr->segVarName = NULL;
   segmtPtr->indice = NULL;
   Tcl_InitHashTable( &segmtPtr->borderTable, TCL_ONE_WORD_KEYS);

   /* Traitement des evenements */
   Tk_CreateEventHandler(segmtPtr->tkwin,
	ExposureMask|StructureNotifyMask|FocusChangeMask,
	SegmtEventProc, (ClientData) segmtPtr);

   /* Cree la commande qui agit sur l'objet */
   segmtPtr->tclCmd = Tcl_CreateCommand(interp,
	Tk_PathName(segmtPtr->tkwin), SegmtInstanceCmd,
	(ClientData) segmtPtr, (Tcl_CmdDeleteProc *)NULL);

   /* Analyse les options */
   if (SegmtConfigure(interp, segmtPtr, argc-2, argv+2, 0) != TCL_OK) {
      Tk_DestroyWindow(segmtPtr->tkwin);
      return TCL_ERROR;
   }

   /* Retourne le nom de la fenetre */
   interp->result = Tk_PathName(segmtPtr->tkwin);
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

/* Widget instance command */
int SegmtInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[])
{
   Segmt *segmtPtr = (Segmt *)clientData;
   int len;

   if (argc < 2) {
      Tcl_AppendResult(interp, "wrong # args: should be '",
		       argv[0], " option ?arg ...?'", (char *)NULL);
      return TCL_ERROR;
   }
   len = strlen(argv[1]);
   if ((strncmp(argv[1],"cget",len)==0) && (len>=2)) {
      if (argc==3) {
	 return Tk_ConfigureValue( interp, segmtPtr->tkwin, configSpecs,
				  (char *) segmtPtr, argv[2], 0);
      } else {
	 Tcl_AppendResult(interp, "wrong # args: should be '", argv[0],
			  " cget option'", (char *)NULL);
	 return TCL_ERROR;
      }
   } else if ((strncmp(argv[1],"configure",len)==0) && (len>=2)) {
      if (argc==2) {
	 return Tk_ConfigureInfo( interp, segmtPtr->tkwin, configSpecs,
				  (char *) segmtPtr, (char *)NULL, 0);
      } else if (argc==3) {
	 return Tk_ConfigureInfo( interp, segmtPtr->tkwin, configSpecs,
				  (char *) segmtPtr, argv[2], 0);
      } else {
	 return SegmtConfigure( interp, segmtPtr, argc-2, argv+2,
				 TK_CONFIG_ARGV_ONLY);
      }
   } else if ((strncmp(argv[1],"update",len)==0) && (len>=2)) {
      if (argc==2) {
	 AskRedraw(segmtPtr, REALLY);
	 return TCL_OK;
      } else {
	 return TCL_ERROR;
      }
   } else if ((strncmp(argv[1],"xview",len)==0) && (len>=2)) {
      if (argc==2) {
	 return TCL_ERROR;
      } else if (argc==3) {
	 return TCL_ERROR;
      }
   }
   Tcl_AppendResult(interp, "bad option '", argv[1],
		    "': must be cget, configure or xview", (char *)NULL);
   return TCL_ERROR;
}

/* --------------------------------------------------------------------- */

/* Widget (re)configuration */
int SegmtConfigure( Tcl_Interp *interp, Segmt *a,
		      int argc, char *argv[], int flags)
{
   /* Unregister traces */
   if (a->segVarName != NULL) {
      Tcl_UntraceVar(interp, a->segVarName,
		TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
		SegmtVarProc, (ClientData) a);
   }
   if (a->timeArrayName != NULL) {
      Tcl_UntraceVar(interp, a->timeArrayName,
		TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
		TimeVarProc, (ClientData) a);
   }

   if (Tk_ConfigureWidget( interp, a->tkwin, configSpecs,
         argc, argv, (char *) a, flags) != TCL_OK) {
      return TCL_ERROR;
   }

   /* Initial background */
   /* Tk_SetWindowBackground(a->tkwin,
      Tk_3DBorderColor(a->background)->pixel); */

   a->end = a->begin + a->length;

   /* Register new traces and parse segments if something changed */
   if (a->segVarName != NULL) {
      Tcl_TraceVar(interp, a->segVarName,
                   TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
                   SegmtVarProc, (ClientData) a);
   }
   if (a->timeArrayName != NULL) {
      Tcl_TraceVar(interp, a->timeArrayName,
                   TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
                   TimeVarProc, (ClientData) a);
   }
   if ((configSpecs[OPTION_SEGNAME].specFlags & TK_CONFIG_OPTION_SPECIFIED)
   || (configSpecs[OPTION_TIMENAME].specFlags & TK_CONFIG_OPTION_SPECIFIED)) {
      AskRedraw(a, REALLY|SEGVAR);
   }

   SegmtWorldChanged((ClientData) a);
   return TCL_OK;
}

void
SegmtWorldChanged(ClientData clientData)
{
   XGCValues gcValues;
   GC newGC;
   int height;
   Segmt *a = (Segmt *)clientData;

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

   if (a->tiny != NULL) {
      gcValues.font = Tk_FontId(a->tiny);
      newGC = Tk_GetGC(a->tkwin,
	 GCBackground|GCForeground|GCFont|GCGraphicsExposures, &gcValues);
      if (a->gc2 != None) {
	 Tk_FreeGC(a->display, a->gc2);
      }
      a->gc2 = newGC;
   }

   /* default geometry */
   Tk_GetFontMetrics(a->font, &(a->fm));
   height = a->height*a->fm.linespace + 2*(a->borderwidth + a->padY);
   Tk_GeometryRequest( a->tkwin, 300, height);

   /* request display */
   AskRedraw(a, REALLY);
}

/* --------------------------------------------------------------------- */

/* try to read segment variable given by name */
static Tcl_Obj *GetSegObj (Segmt *a) {
   Tcl_Obj *namePtr, *segObj;

   if (a->segVarName == NULL || strlen(a->segVarName) == 0) {
      return NULL;
   }
   namePtr = Tcl_NewStringObj(a->segVarName, -1);
   segObj = Tcl_ObjGetVar2(a->interp, namePtr, (Tcl_Obj *) NULL,
			   TCL_PARSE_PART1 | TCL_GLOBAL_ONLY);
   Tcl_DecrRefCount(namePtr);
   return segObj;
}

/* free previous internal representation */
static void FreeList (Segmt *a) {
   if (a->listSeg != NULL) {
      Tcl_Free((char *)a->listSeg);
      a->nbSeg = 0;
      a->listSeg = NULL;
   }
}

static int ParseSegmentVar (Segmt *a)   {
   Tcl_Obj *timeArr=NULL, *segObj, **listObj, **oneObj, *timeObj;
   int i, j, nb=0, nbfield=0, nbchar, nberror=0;
   double x[2];
   char *txt;
   Tk_3DBorder border;

   /*fprintf(stderr,"Parsing segments for %s\n", Tcl_GetCommandName(a->interp, a->tclCmd));*/

   /* free previous internal representation */
   FreeList(a);

   /* Get segment variable into array */
   if ((segObj = GetSegObj(a)) == NULL) return TCL_OK;
   if (Tcl_ListObjGetElements(a->interp, segObj, &nb, &listObj) != TCL_OK) {
      return TCL_ERROR;
   }
   if (nb <= 0) return TCL_OK;

   /* Create internal representation */
   a->nbSeg = nb;
   a->listSeg = (OneSeg *) Tcl_Alloc( nb * sizeof(OneSeg));
   
   /* Object name for time array */
   if (a->timeArrayName != NULL && strlen(a->timeArrayName) > 0) {
      timeArr = Tcl_NewStringObj(a->timeArrayName, -1);
   }

   /* Process segments list */
   for (i=0; i<nb; i++) {
      /* Split segment i into sublists */
      Tcl_ListObjGetElements(a->interp, listObj[i], &nbfield, &oneObj);

      /* get begin/end */
      x[0] = x[1] = 0.0;
      for (j=0; (j<2) && (j<nbfield); j++) {
	 if (Tcl_GetDoubleFromObj(a->interp, oneObj[j], &(x[j])) == TCL_OK)
	    continue;
	 if (timeArr == NULL
	     || (timeObj = Tcl_ObjGetVar2(a->interp, timeArr, oneObj[j],
		  TCL_LEAVE_ERR_MSG | TCL_GLOBAL_ONLY)) == NULL
	     || Tcl_GetDoubleFromObj(a->interp, timeObj, &(x[j])) != TCL_OK) {
	    nberror++;
	 }
      }
      a->listSeg[i].beg = x[0];
      a->listSeg[i].end = x[1];

      /* Get transcription */
      txt = NULL; nbchar = 0;
      if (nbfield >=3) {
	 txt = Tcl_GetStringFromObj(oneObj[2], &nbchar);
#ifdef TCL_ENCODING_START
	 nbchar = Tcl_NumUtfChars(txt, nbchar);
# endif
      }
      a->listSeg[i].txt = txt;
      a->listSeg[i].len = nbchar;

      /* Choose color border */
      border = NULL;
      if (nbfield >= 4) {
	 char *colorName = Tcl_GetStringFromObj(oneObj[3], NULL);
	 if ((colorName != NULL) && (strlen(colorName)>0))
	    border = GetBorder(a, colorName);
      }
      a->listSeg[i].col = border;
   }

   /* Free used objects */
   if (timeArr != NULL) {
      Tcl_DecrRefCount(timeArr);
   }

   /* Test for errors */
   if (nberror) {
      FreeList(a);
      return TCL_ERROR;
   }
   /* fprintf(stderr,"%d segments\n", a->nbSeg); */
   return TCL_OK;
}

/* Modify only changed time indice */
static int UpdateTimeVar (Segmt *a)   {
   Tcl_Obj *timeArr=NULL, *segObj, **listObj, **oneObj, *timeObj;
   int i, j, nb=0, nbfield=0, nberror=0;
   double x;

   /*fprintf(stderr,"Updating time %s for %s\n", a->indice, Tcl_GetCommandName(a->interp, a->tclCmd));*/

   /* Get segment variable into array */
   if ((segObj = GetSegObj(a)) == NULL) return TCL_OK;
   if (Tcl_ListObjGetElements(a->interp, segObj, &nb, &listObj) != TCL_OK) {
      return TCL_ERROR;
   }
   if (nb <= 0) return TCL_OK;
   /* If segmentation also changed, don't react now  :
      ParseSegmentVar will be called just after that by the trace */
   if (nb != a->nbSeg) return TCL_OK;

   /* Object name for time array */
   if (a->timeArrayName != NULL && strlen(a->timeArrayName) > 0) {
      timeArr = Tcl_NewStringObj(a->timeArrayName, -1);
   }
   if (timeArr == NULL) return TCL_ERROR;

   /* Process segments list */
   for (i=0; i<nb; i++) {
      /* Split segment i into sublists */
      Tcl_ListObjGetElements(a->interp, listObj[i], &nbfield, &oneObj);

      /* get begin/end */
      for (j=0; (j<2) && (j<nbfield); j++) {
	 char *n = Tcl_GetStringFromObj(oneObj[j],NULL);
	 if (strcmp(n, a->indice)) continue;
	 x = 0.0;
	 if ((timeObj = Tcl_ObjGetVar2(a->interp, timeArr, oneObj[j],
		  TCL_LEAVE_ERR_MSG | TCL_GLOBAL_ONLY)) == NULL
	     || Tcl_GetDoubleFromObj(a->interp, timeObj, &x) != TCL_OK) {
	    nberror++;
	 } else {
	    if (j==0) {a->listSeg[i].beg = x;}
	    if (j==1) {a->listSeg[i].end = x;}
	 }
      }
   }

   /* Free used objects */
   Tcl_DecrRefCount(timeArr);

   /* request display */
   /*AskRedraw(a, REALLY);*/

   /* Test for errors */
   if (nberror) {
      return TCL_ERROR;
   }
   /* fprintf(stderr,"%d segments\n", a->nbSeg); */
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

static char *
SegmtVarProc(clientData, interp, name1, name2, flags)
    ClientData clientData;      /* Information about button. */
    Tcl_Interp *interp;         /* Interpreter containing variable. */
    char *name1;                /* Not used. */
    char *name2;                /* Not used. */
    int flags;                  /* Information about what happened. */
{
   Segmt *a = (Segmt *)clientData;

   /* if variable disappear, create it empty and set a new trace */
   if (flags & TCL_TRACE_UNSETS) {
      if ((flags & TCL_TRACE_DESTROYED) && !(flags & TCL_INTERP_DESTROYED)) {
         Tcl_SetVar(interp, a->segVarName, "", TCL_GLOBAL_ONLY);
         Tcl_TraceVar(interp, a->segVarName,
                      TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
                      SegmtVarProc, clientData);
      }
   }

   /* adapt internal representation and request display */
   AskRedraw(a, REALLY|SEGVAR);
   return (char *) NULL;
}

/* --------------------------------------------------------------------- */

static char *
TimeVarProc(clientData, interp, name1, name2, flags)
    ClientData clientData;      /* Information about button. */
    Tcl_Interp *interp;         /* Interpreter containing variable. */
    char *name1;                /* Not used. */
    char *name2;                /* Time indice */
    int flags;                  /* Information about what happened. */
{
   Segmt *a = (Segmt *)clientData;

   if (name2 != NULL && strlen(name2) > 0) {
      /* If several time indices have moved, redisplay all */
      if (a->indice != NULL) {
	 if (strcmp(a->indice, name2)) {
	    /*fprintf(stderr,"changed %s after %s in %p\n", name2, a->indice, a);*/
	    AskRedraw(a, REALLY|SEGVAR);
	 }
      } else {
	 a->indice = StringDup(name2);
	 AskRedraw(a, REALLY|TIMVAR);
      }
   } else {
      /* if time line disappears, set a new trace (just in case) */
      if (flags & TCL_TRACE_UNSETS) {
	 if ((flags&TCL_TRACE_DESTROYED) && !(flags&TCL_INTERP_DESTROYED)) {
	    Tcl_TraceVar(interp, a->timeArrayName,
			 TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
			 TimeVarProc, clientData);
	 }
      }

      /* adapt internal representation and request display */
      /* should search only for changed times $name1(name2) */
      AskRedraw(a, REALLY|SEGVAR);
   }
   return (char *) NULL;
}

/* --------------------------------------------------------------------- */

/* Hash table for borders - NULL value for bogus colors */
Tk_3DBorder GetBorder(Segmt *a, char *colorName) {
   int new;
   Tk_3DBorder border;
   Tk_Uid uid = Tk_GetUid(colorName);
   Tcl_HashEntry *entry = Tcl_CreateHashEntry(&a->borderTable, uid, &new);
   if (new) {
      /* fprintf(stderr,"Creating border %s\n", colorName); */
      border = Tk_Get3DBorder(a->interp, a->tkwin, uid);
      Tcl_SetHashValue(entry, border);      
   } else {
      border = (Tk_3DBorder) Tcl_GetHashValue(entry);      
   }
   return border;
}

static void BorderTableFree(Segmt *a) {
   Tcl_HashSearch search;   
   Tcl_HashEntry *entry;
   Tk_3DBorder border;
   entry = Tcl_FirstHashEntry(&a->borderTable, &search);
   while (entry != NULL) {
      border = (Tk_3DBorder) Tcl_GetHashValue(entry);
      /* fprintf(stderr,"Deleting border %s\n", Tk_NameOf3DBorder(border)); */
      if (border != NULL) Tk_Free3DBorder(border);
      entry = Tcl_NextHashEntry(&search);
   }
   Tcl_DeleteHashTable(&a->borderTable);
}

/* --------------------------------------------------------------------- */

static void SegmtReallyDraw(Segmt *a)
{
   int bd = a->borderwidth;
   int bdX = bd + a->padX;
   int bdY = bd + a->padY;
   int width = a->pixwidth;
   int x[4], x1, x2, y1, y2, wrap, hStr, wStr, w2;
   int i, j, nbchar[2], last, height;
   double bp[2], X0;
   char *txt[2];
   Tk_TextLayout layout, layout2;
   Tk_3DBorder border;
   Tk_Font font;
   GC gc;

   /* Layout for "..." */
   layout2 = Tk_ComputeTextLayout( a->font, "...", 3, 0, 0, 0, 0, &w2);

   /* Horizontal segmt on background */
   Tk_Fill3DRectangle( a->tkwin, a->pixmap, a->background,
         0, 0, a->pixwidth, a->pixheight, 0, TK_RELIEF_FLAT);

   X0 = floor(width * a->begin / a->length);

   /* Process segments list */
   for (i=0; i<a->nbSeg; i++) {

      /* Get breakpoints, transcription and color */
      bp[0] = a->listSeg[i].beg;
      bp[1] = a->listSeg[i].end;
      txt[0] = a->listSeg[i].txt;
      nbchar[0] = a->listSeg[i].len;
      border = a->listSeg[i].col;
      if (border == NULL) {
	 if ((a->hiSegmtNb == i) && (a->highSegmt)) {
	    border = a->highSegmt;
	 } else if ((nbchar[0]<=0) && (a->emptySegmt)) {
	    border = a->emptySegmt;
	 } else if (a->fullSegmt) {
	    border = a->fullSegmt;
	 } else {
	    border = a->background;
	 }
      }

      /* If out of screen, next segment */
      if ((bp[1]<a->begin) || (bp[1]<bp[0] && bp[1]!=-1) || (bp[0]>a->end))
	 continue;

      /* Convert to pixel unit without and with overflow test */
      for (j=0; j<2; j++) {
	 x[j] = width * bp[j] / a->length - X0;
	 x[j+2] = bp[j]<a->begin ? -a->borderwidth 
	    : (bp[j]>a->end || bp[j]==-1) ? a->pixwidth + a->borderwidth
	    : width * bp[j] / a->length - X0;
      }

      /* Look for form-feeds to slice text in two parts */
      if (txt[0] != NULL) {
	txt[1] = strchr(txt[0], '\f');
      } else {
	txt[1] = NULL;
      }
      /* Detect if we need to write on half-height parts */
      if (txt[1] != NULL) {
	 nbchar[0] = txt[1] - txt[0];
#ifdef TCL_ENCODING_START
	 nbchar[0] = Tcl_NumUtfChars(txt[0], nbchar[0]);
# endif
	 txt[1] ++;
	 nbchar[1] = strlen(txt[1]);
#ifdef TCL_ENCODING_START
	 nbchar[1] = Tcl_NumUtfChars(txt[1], nbchar[1]);
# endif

	 y2 = a->pixheight/2;
	 height = a->height/2;
	 bdY = 0;
	 font = a->tiny ? a->tiny : a->font;
	 gc = a->tiny ? a->gc2 : a->gc;
      }	 else {
	 y2 = a->pixheight;
	 height = a->height;
	 bdY = bd + a->padY;
	 font = a->font;
	 gc = a->gc;
      }

      for (j=0; j<2 && (txt[1] || j<1); j++) {
	 y1 = (j==1 && txt[1] != NULL) ? a->pixheight/2 : 0;
	 /* Draw polygon */
	 if (x[3]-x[2] >= 2*bd) {
	    Tk_Fill3DRectangle( a->tkwin, a->pixmap, border, x[2], y1,
				x[3]-x[2], y2, bd, a->relief);
	 } else if (x[2]>= 0) {
	    /* Some ad-hoc test to give hashed aspect at very low resolution */
	    Tk_Fill3DRectangle( a->tkwin, a->pixmap, border, x[2], y1,
				2*bd, y2, x[2]%2, a->relief);
	 }
	 
	 /* Print transcription */
	 x1 = x[0] + bdX;
	 x2 = x[1] - bdX;
	 /* some ad-hoc test to choose not to center text in segment */
	 if ((i == a->nbSeg-1 && bp[1]-bp[0] > 3*a->length) || bp[1]==-1) {
	    wrap = 0;
	    if (bp[0] < a->begin-10*a->length) {
	       continue;
	    }
	 } else {
	    wrap = x2-x1;
	 }
	 if ((nbchar[j]>0)&&(x2>x1)) {
	    layout = Tk_ComputeTextLayout( font, txt[j], nbchar[j],
		wrap, TK_JUSTIFY_CENTER, 0,  &wStr, &hStr);
	    if (wrap>0) x1 = (x1+x2-wStr)/2;
	    y1 = y1+MAX((y2-hStr)/2,bdY);
	    if (hStr > (y2-2*bdY)) {
	       int x3,y3,w3,h3;
	       int tot = height * a->fm.linespace;
	       int mid = (height+1)/2 * a->fm.linespace;
	       last = Tk_PointToChar(layout, 0, mid);
	       Tk_DrawTextLayout( a->display, a->pixmap, gc,
		  layout, x1, y1, 0, last);
	       Tk_CharBbox(layout, last-1, &x3, &y3, &w3, &h3);
	       Tk_DrawTextLayout( a->display, a->pixmap, gc,
		  layout2, MIN(x1+x3+w3,x[1]-w2), y1+y3, 0, -1);
	       /* If needed, draw last part of text after "..." */
	       if (mid<tot) {
		  last = Tk_PointToChar(layout, 0, hStr-(tot-mid));
		  Tk_CharBbox(layout, last, &x3, &y3, &w3, &h3);
		  Tk_DrawTextLayout( a->display, a->pixmap, gc,
		     layout2, MAX(x1+x3-w2,x[0]), y1+mid, 0, -1);
		  Tk_DrawTextLayout( a->display, a->pixmap, gc,
				     layout, x1, y1-hStr+tot, last, -1);
	       }
	    } else {
	       /*if ((x1 >= bd) && (x1+wStr <= a->pixwidth-bd)) */
	       Tk_DrawTextLayout( a->display, a->pixmap, gc,
				  layout, x1, y1, 0, -1);
	    }
	    Tk_FreeTextLayout( layout);
	 }
      }
   }
   Tk_FreeTextLayout( layout2);
}

/* Display */
static void SegmtDisplay(ClientData clientData)
{
   Segmt *segmtPtr = (Segmt *)clientData;
   Tk_Window tkwin = segmtPtr->tkwin;
   int width, height;
   /* static int i=0; */

   segmtPtr->flags &= ~REDRAW;
   if ((tkwin == NULL) || !Tk_IsMapped(tkwin))
      return;
   
   /* Create new pixmap only if resize */
   width =  Tk_Width(tkwin);
   height = Tk_Height(tkwin);
   if ((segmtPtr->pixwidth !=width) || (segmtPtr->pixheight != height)) {
      segmtPtr->flags |= REALLY;      
      /* fprintf(stderr,"New pixmap %dx%d\n",width,height); */
      segmtPtr->pixwidth = width;
      segmtPtr->pixheight = height;
      /* free old pixmap */
      if (segmtPtr->pixmap != 0)
	 Tk_FreePixmap(segmtPtr->display, segmtPtr->pixmap);
      segmtPtr->pixmap = Tk_GetPixmap(segmtPtr->display, Tk_WindowId(tkwin),
            width, height, Tk_Depth(tkwin));
   }
   
   /* Needs to re-parse segmentation */
   if (segmtPtr->flags & SEGVAR) {
      if (ParseSegmentVar(segmtPtr) != TCL_OK) {
	 Tcl_BackgroundError(segmtPtr->interp);
      }
   } else if (segmtPtr->flags & TIMVAR) {
      if (UpdateTimeVar(segmtPtr) != TCL_OK) {
	 Tcl_BackgroundError(segmtPtr->interp);
      }
   }
   segmtPtr->flags &= ~SEGVAR;
   segmtPtr->flags &= ~TIMVAR;
   if (segmtPtr->indice != NULL) {
      /* fprintf(stderr,"forget %s in %p\n", segmtPtr->indice, segmtPtr);*/
      Tcl_Free(segmtPtr->indice);
      segmtPtr->indice = NULL;
   }


   /* Really redraw */
   if (segmtPtr->flags & REALLY) {
      /* fprintf(stderr,"Display %d\n", i++);*/
      SegmtReallyDraw( segmtPtr);
      segmtPtr->flags &= ~REALLY;      
   }

   XCopyArea( segmtPtr->display, segmtPtr->pixmap,
	      Tk_WindowId(tkwin), segmtPtr->gc,
	      0, 0, width, height, 0, 0);

   return;
}

/* Window Event Procedure */
static void SegmtEventProc(ClientData clientData, XEvent *eventPtr)
{
   Segmt *segmtPtr = (Segmt *)clientData;

   switch (eventPtr->type) {
   case Expose:
      if (eventPtr->xexpose.count == 0) AskRedraw(segmtPtr, 0);
      break;
   case ConfigureNotify:
      AskRedraw(segmtPtr, 0);
      break;
   case DestroyNotify:
      Tcl_DeleteCommandFromToken( segmtPtr->interp, segmtPtr->tclCmd);
      segmtPtr->tkwin = NULL;
      if (segmtPtr->flags & REDRAW) {
	 Tk_CancelIdleCall( SegmtDisplay, (ClientData) segmtPtr);
	 segmtPtr->flags &= ~REDRAW;
      }
      Tcl_EventuallyFree( (ClientData) segmtPtr, SegmtDestroy);
      break;
   case FocusIn:
      /* fprintf(stderr,"FocusIn\n"); */
      segmtPtr->flags |= FOCUS;
      break;
   case FocusOut:
      segmtPtr->flags &= ~FOCUS;
      break;
   }
   return;
}

static void AskRedraw(Segmt *a, int flag) 
{
   if ((a->tkwin != NULL) && Tk_IsMapped(a->tkwin) && !(a->flags & REDRAW)) {
	 Tk_DoWhenIdle(SegmtDisplay, (ClientData) a);
	 a->flags |= REDRAW;
   }
   a->flags |= flag;
}

/* Destroy */
static void SegmtDestroy(char *blockPtr)
{
   Segmt *segmtPtr = (Segmt *)blockPtr;

   if (segmtPtr->segVarName != NULL) {
        Tcl_UntraceVar(segmtPtr->interp, segmtPtr->segVarName,
                TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
                SegmtVarProc, (ClientData) segmtPtr);
   }
   if (segmtPtr->timeArrayName != NULL) {
        Tcl_UntraceVar(segmtPtr->interp, segmtPtr->timeArrayName,
                TCL_GLOBAL_ONLY|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
                TimeVarProc, (ClientData) segmtPtr);
   }

   if (segmtPtr->indice != NULL) {
      Tcl_Free(segmtPtr->indice);
   }
   if (segmtPtr->listSeg != NULL) {
      Tcl_Free((char *)segmtPtr->listSeg);
   }
   BorderTableFree(segmtPtr);
   if (segmtPtr->gc != None) {
      Tk_FreeGC(segmtPtr->display, segmtPtr->gc);
   }
   if (segmtPtr->gc2 != None) {
      Tk_FreeGC(segmtPtr->display, segmtPtr->gc2);
   }
   if (segmtPtr->flags & REDRAW) {
      Tk_CancelIdleCall( SegmtDisplay, (ClientData) segmtPtr);
   }
   Tk_FreeOptions( configSpecs, (char *) segmtPtr, segmtPtr->display, 0);
   Tcl_Free( (char *) segmtPtr);
}


