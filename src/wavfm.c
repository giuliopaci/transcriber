/* 
 * RCS: @(#) $Id$
 *
 * Copyright (C) 1998-2000, DGA - part of the Transcriber program
 * distributed under the GNU General Public License (see COPYING file)
 */

/* Tk Widget in C for waveform display */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <tcl.h>
#include <tk.h>

extern int useOldObjAPI;

#if defined Linux || defined WIN || defined _LITTLE_ENDIAN
#  define LE
#endif

#ifdef LE
static char *byteOrder="littleEndian";
#else
static char *byteOrder="bigEndian";
#endif

#define BE_OK(x) {int res = (x); if (res != TCL_OK) return res;}

/* --------------------------------------------------------------------- */
typedef struct {
   short max;
   short min;
} Maxmin;

/* Widget data structure */
typedef struct {
   Tk_Window tkwin;
   Display *display;
   Tcl_Interp *interp;
   Tcl_Command tclCmd;

   /* Widget attributes */
   Tk_3DBorder background;
   XColor *foreground;
   XColor *cursorcolor;
   Tk_3DBorder selectbg;
   XColor *selectfg;
   double selectbegin;
   double selectend;
   int borderwidth;
   int winwidth;
   int winheight;
   int padX;
   int padY;
   Tk_Font font;
   double begin;
   double length;
   double cursor;
   double volume;
   char *signal;
   char *shapename;

   /* Graphic contexts, internals */
   int flags;
   int channels;
   int rate;
   Pixmap pixmap;
   Pixmap pixmap2;
   int pixwidth;
   int pixheight;
   GC gc;
   GC cursorgc;
   GC selectgc;
   Tcl_Obj *sampObj;
   short  *samples;
   int nbsamp;
   Maxmin *shape;
   XPoint *points;
   int nbshap;
   double end;
   double prev_begin;
   double prev_length;
   int    prev_width;
} Wavfm;

/* Flags definition */
#define REDRAW 0x1
#define REALLY 0x2
#define FOCUS  0x4
#define CURSOR 0x8

/* Widget attributes descriptions */
typedef enum {
  OPTION_SIGNAME, OPTION_SHAPNAME
} ConfigSpec;

static Tk_ConfigSpec configSpecs[] = {
    {TK_CONFIG_STRING, "-sound", "sound", "sound",
        "", Tk_Offset(Wavfm, signal), 0},
    {TK_CONFIG_STRING, "-shape", "shape", "shape",
        "", Tk_Offset(Wavfm, shapename), 0},

    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "light blue", Tk_Offset(Wavfm, background),
        TK_CONFIG_COLOR_ONLY},
    {TK_CONFIG_BORDER, "-background", "background", "Background",
        "white", Tk_Offset(Wavfm, background),
        TK_CONFIG_MONO_ONLY},
    {TK_CONFIG_SYNONYM, "-bg", "background", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_PIXELS, "-borderwidth", "borderWidth", "BorderWidth",
        "2", Tk_Offset(Wavfm, borderwidth), 0},
    {TK_CONFIG_SYNONYM, "-bd", "borderWidth", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_PIXELS, "-width", "width", "Width",
        "500", Tk_Offset(Wavfm, winwidth), 0},
    {TK_CONFIG_PIXELS, "-height", "height", "Height",
        "100", Tk_Offset(Wavfm, winheight), 0},

    {TK_CONFIG_COLOR, "-foreground", "foreground", "Foreground",
        "black", Tk_Offset(Wavfm, foreground), 0},
    {TK_CONFIG_SYNONYM, "-fg", "foreground", (char *) NULL,
        (char *) NULL, 0, 0},

    {TK_CONFIG_COLOR, "-cursorcolor", "cursorColor", "CursorColor",
        "red", Tk_Offset(Wavfm, cursorcolor), 0},

    {TK_CONFIG_FONT, "-font", "font", "Font",
        "Courier 18", Tk_Offset(Wavfm, font), 0},

    {TK_CONFIG_PIXELS, "-padx", "padX", "Pad",
        "10", Tk_Offset(Wavfm, padX), 0},
    {TK_CONFIG_PIXELS, "-pady", "padY", "Pad",
        "5", Tk_Offset(Wavfm, padY), 0},

    {TK_CONFIG_DOUBLE, "-begin", "begin", "Begin",
        "0", Tk_Offset(Wavfm, begin), 0},
    {TK_CONFIG_DOUBLE, "-length", "length", "Length",
        "10", Tk_Offset(Wavfm, length), 0},
    {TK_CONFIG_DOUBLE, "-cursor", "cursor", "Cursor",
        "0", Tk_Offset(Wavfm, cursor), 0},
    {TK_CONFIG_DOUBLE, "-volume", "volume", "Volume",
        "1.0", Tk_Offset(Wavfm, volume), 0},

    {TK_CONFIG_BORDER, "-selectbackground", "selectBackground", "Foreground",
        "#d0b098", Tk_Offset(Wavfm, selectbg),
        TK_CONFIG_COLOR_ONLY},
    {TK_CONFIG_BORDER, "-selectbackground", "selectBackground", "Foreground",
        "black", Tk_Offset(Wavfm, selectbg),
        TK_CONFIG_MONO_ONLY},

    {TK_CONFIG_COLOR, "-selectforeground", "selectForeground", "Background",
        "black", Tk_Offset(Wavfm, selectfg),
        TK_CONFIG_COLOR_ONLY},
    {TK_CONFIG_COLOR, "-selectforeground", "selectForeground", "Background",
        "white", Tk_Offset(Wavfm, selectfg),
        TK_CONFIG_MONO_ONLY},

    {TK_CONFIG_DOUBLE, "-selectbegin", "selectBegin", "Begin",
        "0", Tk_Offset(Wavfm, selectbegin), 0},
    {TK_CONFIG_DOUBLE, "-selectend", "selectEnd", "End",
        "0", Tk_Offset(Wavfm, selectend), 0},

    {TK_CONFIG_END, (char *) NULL, (char *) NULL, (char *) NULL,
        (char *) NULL, 0, 0}
};

/* Prototypes (C ANSI now) */
int WavfmCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[]);
static int WavfmInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[]);
static int WavfmConfigure( Tcl_Interp *interp, Wavfm *w,
		      int argc, char *argv[], int flags);
static void WavfmDisplay(ClientData clientData);
static void WavfmAddCursor(Wavfm *w);
static void WavfmEventProc(ClientData clientData, XEvent *eventPtr);
static void WavfmDestroy(char *blockPtr);

/* --------------------------------------------------------------------- */

/* Wavfm class command */
int WavfmCmd( ClientData clientData, Tcl_Interp *interp,
	      int argc, char *argv[])
{
   Tk_Window main = (Tk_Window) clientData;
   Wavfm *wavfmPtr;
   Tk_Window tkwin;

   /* Create window */
   if (argc < 2) {
      Tcl_AppendResult(interp, "Wrong # args: should be '",
		       argv[0], " pathname ?options?'", (char *)NULL);
      return TCL_ERROR;
   }
   tkwin = Tk_CreateWindowFromPath( interp, main, argv[1], (char *)NULL);
   if (tkwin == NULL) {
      return TCL_ERROR;
   }
   Tk_SetClass( tkwin, "Wavfm");

   /* Init data */
   wavfmPtr = (Wavfm *) Tcl_Alloc(sizeof(Wavfm));
   wavfmPtr->tkwin = tkwin;
   wavfmPtr->display = Tk_Display(tkwin);
   wavfmPtr->interp = interp;
   wavfmPtr->background = NULL;
   wavfmPtr->foreground = NULL;
   wavfmPtr->cursorcolor = NULL;
   wavfmPtr->selectbg = NULL;
   wavfmPtr->selectfg = NULL;
   wavfmPtr->borderwidth = 0;
   wavfmPtr->font = NULL;
   wavfmPtr->pixmap = 0;
   wavfmPtr->pixmap2 = 0;
   wavfmPtr->pixwidth = 0;
   wavfmPtr->pixheight = 0;
   wavfmPtr->winwidth = 0;
   wavfmPtr->winheight = 0;
   wavfmPtr->gc = None;
   wavfmPtr->cursorgc = None;
   wavfmPtr->selectgc = None;
   wavfmPtr->flags = 0;
   wavfmPtr->begin = 0;
   wavfmPtr->length = 0;
   wavfmPtr->end = 0;
   wavfmPtr->cursor = 0;
   wavfmPtr->selectbegin = 0;
   wavfmPtr->selectend = 0;
   wavfmPtr->signal = NULL;
   wavfmPtr->shapename = NULL;
   wavfmPtr->padX = 0;
   wavfmPtr->padY = 0;
   wavfmPtr->channels = 1;
   wavfmPtr->rate = 1;
   wavfmPtr->prev_begin = 0;
   wavfmPtr->prev_length = 0;
   wavfmPtr->prev_width = 0;
   wavfmPtr->sampObj = NULL;
   wavfmPtr->samples = NULL;
   wavfmPtr->nbsamp = 0;
   wavfmPtr->shape = NULL;
   wavfmPtr->points = NULL;
   wavfmPtr->nbshap = 0;

   /* Process events */
   Tk_CreateEventHandler(wavfmPtr->tkwin,
	ExposureMask|StructureNotifyMask|FocusChangeMask,
	WavfmEventProc, (ClientData) wavfmPtr);

   /* Create object command */
   wavfmPtr->tclCmd = Tcl_CreateCommand(interp,
	Tk_PathName(wavfmPtr->tkwin), WavfmInstanceCmd,
	(ClientData) wavfmPtr, (Tcl_CmdDeleteProc *)NULL);

   /* Parse options */
   if (WavfmConfigure(interp, wavfmPtr, argc-2, argv+2, 0) != TCL_OK) {
      Tk_DestroyWindow(wavfmPtr->tkwin);
      return TCL_ERROR;
   }

   /* Return window name */
   interp->result = Tk_PathName(wavfmPtr->tkwin);
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

/* Wavfm instance command */
int WavfmInstanceCmd(ClientData clientData, Tcl_Interp *interp,
		       int argc, char *argv[])
{
   Wavfm *w = (Wavfm *)clientData;
   int len;

   if (argc < 2) {
      Tcl_AppendResult(interp, "wrong # args: should be '",
		       argv[0], " option ?arg ...?'", (char *)NULL);
      return TCL_ERROR;
   }
   len = strlen(argv[1]);
   if ((strncmp(argv[1],"cget",len)==0) && (len>=2)) {
      if (argc==3) {
	 return Tk_ConfigureValue( interp, w->tkwin, configSpecs,
				  (char *) w, argv[2], 0);
      } else {
	 Tcl_AppendResult(interp, "wrong # args: should be '", argv[0],
			  " cget option'", (char *)NULL);
	 return TCL_ERROR;
      }
   } else if ((strncmp(argv[1],"configure",len)==0) && (len>=2)) {
      if (argc==2) {
	 return Tk_ConfigureInfo( interp, w->tkwin, configSpecs,
				  (char *) w, (char *)NULL, 0);
      } else if (argc==3) {
	 return Tk_ConfigureInfo( interp, w->tkwin, configSpecs,
				  (char *) w, argv[2], 0);
      } else {
	 return WavfmConfigure( interp, w, argc-2, argv+2,
				 TK_CONFIG_ARGV_ONLY);
      }
   } else if ((strncmp(argv[1],"cursor",len)==0) && (len>=2)) {
      if (argc==3) {
          if (Tcl_GetDouble(interp, argv[2], &(w->cursor)) != TCL_OK)
            return TCL_ERROR;
	  if ((w->tkwin != NULL) && Tk_IsMapped( w->tkwin)
	      && !(w->flags & REDRAW)) {
	    Tk_DoWhenIdle( WavfmDisplay, (ClientData) w);
	    w->flags |= REDRAW;
	  }
        w->flags |= CURSOR;
	  return TCL_OK;
      } else {
	 Tcl_AppendResult(interp, "wrong # args: should be '", argv[0],
			  " cursor value'", (char *)NULL);
	 return TCL_ERROR;
      }
   } else {
      Tcl_AppendResult(interp, "bad option '", argv[1],
		       "': must be cget or configure", (char *)NULL);
      return TCL_ERROR;
   }
}

/* --------------------------------------------------------------------- */
/* Communications with file server through sockets */

/* Send command for signal */
static int SendCmd( Wavfm *w, char *cmd)
{
   Tcl_Obj *cmdObj;
   int result;

   /* fprintf(stderr,"%s\n",cmd); */
   cmdObj = Tcl_NewStringObj( w->signal, -1);
   Tcl_AppendStringsToObj( cmdObj, " ", cmd, NULL);
   Tcl_IncrRefCount( cmdObj);
   result = Tcl_GlobalEvalObj( w->interp, cmdObj);
   if (result != TCL_OK) { 
      Tcl_BackgroundError( w->interp);
      /* forget any callback command which doesn't work */
      w->signal[0] = '\0';
   }
   Tcl_DecrRefCount( cmdObj);
   return result;
}

/* Get signal from audio file server */
static int ReadSignal( Wavfm *w, long pos, long width)
{
   int size;
   char cmd[256], *p = NULL;
   Tcl_Obj *res;

   w->nbsamp = 0;
   if (w->signal == NULL || strlen(w->signal)==0) return -1;

   sprintf(cmd, "datasamples -start %ld -end %ld -byteorder %s\n",
	   pos, pos+width-1, byteOrder);
   if (SendCmd( w, cmd) != TCL_OK) return -1;
   
   if (w->sampObj != NULL) {
      Tcl_DecrRefCount( w->sampObj);
      w->sampObj = NULL;
      w->samples = NULL;
   }
   res = Tcl_GetObjResult( w->interp);
   if (useOldObjAPI) {
      p = Tcl_GetStringFromObj( res, &size);
   } else {
#ifdef TCL_81_API
      p = (char *) Tcl_GetByteArrayFromObj( res, &size);
#endif
   }
   if (size == 0) {
      w->nbsamp = 0;
      return 0;
   }
   Tcl_IncrRefCount(w->sampObj = res);
   w->samples = (short *) p;
   w->nbsamp = size/(w->channels*sizeof(short));
   return w->nbsamp;
}

/* Get shape of signal from audio file server */
static int ReadShape( Wavfm *w, int width, double begin, double length)
{
   int size, c, width2, i, j, base;
   double delta, prev;
   char cmd[256], *p = NULL;

   w->nbshap = 0;
   if (w->signal == NULL || strlen(w->signal)==0) return -1;

   /* Request memory for the right size */
   size = width * w->channels * sizeof(Maxmin);
   w->nbshap = width;
   if (size == 0) {
      return 0;
   }
   if (w->shape != NULL) {
      w->shape = (Maxmin *) Tcl_Realloc( (char *)w->shape, size);
   } else {
      w->shape = (Maxmin *) Tcl_Alloc( size);
   }

   /* Handle scrolling case with minimal load */
   base = 0;
   if ((w->prev_width==width) &&
       ((int)(w->rate*w->prev_length) == (int)(w->rate*length))) {
      prev = w->prev_begin;
      delta = begin - prev;
      if (delta == 0.0) return 0;
      /* Scroll only with step < window length */
      if (fabs(delta)<length*.9) {
	 width2 = abs(floor(prev/length*width)-floor(begin/length*width));
	 if (width2 < 1) return 0;
	 if (delta > 0) {
	    /* Scroll forward */
	    begin = prev + length;
	    base = width-width2;
	    for (i=0; i<width-width2; i++)
	       for (c=0; c<w->channels; c++) {
		  j = c+i*w->channels;
		  w->shape[j] = w->shape[j+width2*w->channels];
	       }
	 } else {
	    /* Scroll backward */
	    for (i=width-1; i>=width2; i--)
	       for (c=0; c<w->channels; c++) {
		  j = c+i*w->channels;
		  w->shape[j] = w->shape[j-width2*w->channels]; 
	       }
	 }
	 length = (length*width2)/(double)width;
	 width = width2;
	 /*fprintf(stderr, "Scroll %d %f %f != %f\n",width, begin, length, delta);*/
      }
   }

   sprintf(cmd, "shape -width %d -start %ld -end %ld -byteorder %s",
	   width, (long) floor(w->rate*begin),
	   (long) ceil(w->rate*(begin+length))-1, byteOrder);
   if (w->shapename != NULL && strlen(w->shapename) > 0) {
      strcat(cmd, " -shape ");
      strcat(cmd, w->shapename);
   }
   strcat(cmd, "\n");
   if (SendCmd(w, cmd) != TCL_OK) return -1;

   if (useOldObjAPI) {
      p = Tcl_GetStringFromObj(Tcl_GetObjResult(w->interp), &size);
   } else {
#ifdef TCL_81_API
      p = (char *) Tcl_GetByteArrayFromObj(Tcl_GetObjResult(w->interp), &size);
#endif
   }
   if (size != sizeof(Maxmin)*width*w->channels || base+width > w->nbshap) {
      Tcl_AppendResult(w->interp, "Shape size problem", NULL);
      Tcl_BackgroundError(w->interp);
      w->nbshap = 0;
      /* forget the callback command which doesn't work */
      w->signal[0] = '\0';
      return -1;
   }
   memcpy (w->shape + base * w->channels, p, size);
   return width;
}

static void AllocPoints( Wavfm *w, int nb)
{
   int size = nb * sizeof(XPoint);
   if (size == 0) return;
   if (w->points != NULL) {
      w->points = (XPoint *) Tcl_Realloc( (char *)w->points, size);
   } else {
      w->points = (XPoint *) Tcl_Alloc( size);
   }
}

/* --------------------------------------------------------------------- */

/* Widget (re)configuration */
int WavfmConfigure( Tcl_Interp *interp, Wavfm *w,
		      int argc, char *argv[], int flags)
{
   XGCValues gcValues;
   GC newGC;

   if (Tk_ConfigureWidget( interp, w->tkwin, configSpecs,
         argc, argv, (char *) w, flags) != TCL_OK) {
      return TCL_ERROR;
   }

   /* Initial background */
   /* Tk_SetWindowBackground(w->tkwin,
      Tk_3DBorderColor(w->background)->pixel); */

   /* Set graphic context */
   gcValues.background = Tk_3DBorderColor(w->background)->pixel;
   gcValues.foreground = w->foreground->pixel;
   gcValues.font = Tk_FontId(w->font);
   gcValues.graphics_exposures = False;
   newGC = Tk_GetGC(w->tkwin,
         GCBackground|GCForeground|GCFont|GCGraphicsExposures, &gcValues);
   if (w->gc != None) {
      Tk_FreeGC(w->display, w->gc);
   }
   w->gc = newGC;

   /* Cursor graphic context */
   gcValues.foreground = w->cursorcolor->pixel;
   gcValues.line_style = LineOnOffDash;
   gcValues.dashes = 3;
   newGC = Tk_GetGC(w->tkwin,
         GCBackground|GCForeground|GCLineStyle|GCDashList|GCGraphicsExposures,
         &gcValues);
   if (w->cursorgc != None) {
      Tk_FreeGC(w->display, w->cursorgc);
   }
   w->cursorgc = newGC;
 
   /* Selection graphic context */
   gcValues.background = Tk_3DBorderColor(w->selectbg)->pixel;
   gcValues.foreground = w->selectfg->pixel;
   newGC = Tk_GetGC(w->tkwin,
         GCBackground|GCForeground|GCGraphicsExposures, &gcValues);
   if (w->selectgc != None) {
      Tk_FreeGC(w->display, w->selectgc);
   }
   w->selectgc = newGC;

   /* New signal name */
   if (configSpecs[OPTION_SIGNAME].specFlags & TK_CONFIG_OPTION_SPECIFIED) {
      w->prev_begin=0;
      w->prev_length=0;
      w->prev_width=0;
      if (w->signal != NULL && strlen(w->signal)!=0) {
	 BE_OK(SendCmd(w, "cget -frequency"));
	 BE_OK(Tcl_GetIntFromObj(w->interp, Tcl_GetObjResult(w->interp), &(w->rate)));
	 BE_OK(SendCmd(w, "cget -channels"));
	 BE_OK(Tcl_GetIntFromObj(w->interp, Tcl_GetObjResult(w->interp), &(w->channels)));
      }
   }

   if (w->channels<=0) w->channels=1;
   if (w->rate<0) w->rate=1;
   if (w->length<=0) w->length=1;
   w->end = w->begin + w->length;
   
   /* default geometry */
   Tk_GeometryRequest( w->tkwin, w->winwidth, w->winheight);

   /* request display */
   if ((w->tkwin != NULL)
         && Tk_IsMapped( w->tkwin)
         && !(w->flags & REDRAW)) {
      Tk_DoWhenIdle( WavfmDisplay, (ClientData) w);
      w->flags |= REDRAW;      
   }
   w->flags |= REALLY;
   return TCL_OK;
}

/* --------------------------------------------------------------------- */

static void WavfmReallyDraw(Wavfm *w)
{
   int bd = w->borderwidth;
   int bdX = bd + w->padX;
   int bdY = bd + w->padY;
   int width, height, center, x1, y1, x2, y2, i, j, c, min, max, y1p, y2p;
   int x1sel = -1, x2sel = -1;
   double hRatio, vRatio, bg, nd;

   /* Sizes and ratios */
   width = w->pixwidth-2*bdX-1;
   height = (w->pixheight-2*bdY-(w->channels-1)*w->padY) / w->channels;
   vRatio = height/65536.0;
   if ((w->volume>0) && (w->volume!=1.0)) vRatio *= w->volume;
   /* fprintf(stderr,"hRatio: %f\n", hRatio); */

   /* Background */
   Tk_Fill3DRectangle( w->tkwin, w->pixmap, w->background, 0, 0,
         w->pixwidth, w->pixheight, w->borderwidth, TK_RELIEF_RIDGE);

   /* Selection */
   bg = (w->selectbegin < w->begin) ? w->begin : w->selectbegin;
   nd = (w->selectend > w->end) ? w->end : w->selectend;
   if ((bg < nd) && (bg < w->end) && (nd > w->begin)) {
      x1 = bdX + (width+1)*(bg - w->begin)/w->length;
      x2 = (width+1)*(nd-bg)/w->length;
      y1 = bd; y2 = w->pixheight-2*bd;
      Tk_Fill3DRectangle( w->tkwin, w->pixmap, w->selectbg, x1, y1,
	  x2, y2, 0, TK_RELIEF_FLAT);
      x1sel = x1; x2sel = x1+x2;
   }

   /* Draw waveform */
   hRatio = w->rate * w->length / width;
   if (hRatio > 1) {
      /* Request shape to file server */
      ReadShape(w, width, w->begin, w->length);
      AllocPoints( w, 2 * w->nbshap);
      for (c = 0; c < w->channels; c++) {
	 /* Horizontal axis */
	 min = bdY + c*(height+w->padY);
	 max = min + height;
	 center = min + height/2;
	 x1 = bdX; x2 = x1 + width;
	 y1 = y2 = center;
	 XDrawLine(w->display, w->pixmap, w->gc, x1, y1, x2, y2);
	 
	 y1p = center; y2p = center;
	 for (i = 0; i < w->nbshap; i++) {
	    j = c+i*w->channels;
	    y1 = center - w->shape[j].max * vRatio;
	    y2 = center - w->shape[j].min * vRatio; 
	    x1 = x2 = bdX + i;
	    /* clipping */
	    if (y1<min) y1=min; else if (y1>max) y1=max;
	    if (y2<min) y2=min; else if (y2>max) y2=max;
	    /* put both points in array */
	    w->points[2*i  ].x = x1; w->points[2*i  ].y = y1;
	    w->points[2*i+1].x = x2; w->points[2*i+1].y = y2;
	    /* should change fg color for selection */
	 }
	 XDrawLines(w->display, w->pixmap, w->gc, w->points, 2 * w->nbshap, 
		    CoordModeOrigin);
      }
   } else if (hRatio>0) {
      /* Request signal to file server */
      long p1, p2, nb;
      double dc;
      p1 = floor(w->begin*w->rate);
      p2 = ceil(w->end*w->rate);
      nb = p2-p1+1;
      dc = floor(w->begin*w->rate/hRatio)*hRatio - p1;
      if ((w->prev_begin!=w->begin) || (w->prev_length!=w->length))
	 nb = ReadSignal( w, p1, nb);
      AllocPoints( w, w->nbsamp);
      for (c = 0; c < w->channels; c++) {
	 /* Horizontal axis */
	 min = bdY + c*(height+w->padY);
	 max = min + height;
	 center = min + height/2;
	 x1 = bdX; x2 = x1 + width;
	 y1 = y2 = center;
	 XDrawLine(w->display, w->pixmap, w->gc, x1, y1, x2, y2);
	 
	 for (i = 0; i < w->nbsamp; i++) {
	    w->points[i].x = bdX + (i-dc)/hRatio;
	    w->points[i].y = center - w->samples[c + i*w->channels] * vRatio;
	    /* should do some clipping and change fg color for selection */
	 }
	 if (w->nbsamp > 0) {
	    XDrawLines(w->display, w->pixmap, w->gc, w->points, w->nbsamp, 
		       CoordModeOrigin);
	 }
      }
   }
   
   /* Draw cursor */
   WavfmAddCursor(w);

   /* Keep previous parameters */
   w->prev_width=width;
   w->prev_begin=w->begin;
   w->prev_length=w->length;
}

/* pixmap2 = pixmap + cursor */
static void WavfmAddCursor(Wavfm *w)
{
   int bd = w->borderwidth;
   int bdX = bd + w->padX;
   int width = w->pixwidth-2*bdX-1;
   int x1, y1, x2, y2;

   XCopyArea( w->display, w->pixmap, w->pixmap2,
	      w->gc, 0, 0, w->pixwidth, w->pixheight, 0, 0);

   if ((w->cursor >= w->begin) && (w->cursor <= w->end)) {
     x1 = x2 = bdX + width*(w->cursor - w->begin)/w->length;
     y1 = bd; y2 = w->pixheight-bd-1;
     XDrawLine(w->display, w->pixmap2, w->cursorgc, x1, y1, x2, y2);
   }
}

/* Display */
static void WavfmDisplay(ClientData clientData)
{
   Wavfm *w = (Wavfm *)clientData;
   Tk_Window tkwin = w->tkwin;
   int height, width;
   /* static int i=0; */

   w->flags &= ~REDRAW;
   if ((tkwin == NULL) || !Tk_IsMapped(tkwin))
      return;
   
   /* Create new pixmap only if resize */
   width =  Tk_Width(tkwin);
   height = Tk_Height(tkwin);
   if ((w->pixwidth !=width) || (w->pixheight != height)) {
      w->flags |= REALLY;      
      /* fprintf(stderr,"New pixmap %d x %d\n",width,height); */
      w->pixwidth = width;
      w->pixheight = height;
      /* free old pixmaps */
      if (w->pixmap != 0)
	 Tk_FreePixmap(w->display, w->pixmap);
      w->pixmap = Tk_GetPixmap(w->display, Tk_WindowId(tkwin),
            width, height, Tk_Depth(tkwin));
      if (w->pixmap2 != 0)
	 Tk_FreePixmap(w->display, w->pixmap2);
      w->pixmap2 = Tk_GetPixmap(w->display, Tk_WindowId(tkwin),
            width, height, Tk_Depth(tkwin));
   }
   
   if (w->flags & REALLY) {
      /* fprintf(stderr,"Display %d\n", i++);*/
      WavfmReallyDraw( w);
      w->flags &= ~REALLY;      
   }

   if (w->flags & CURSOR) {
      WavfmAddCursor( w);
      w->flags &= ~CURSOR;      
   }

   XCopyArea( w->display, w->pixmap2, Tk_WindowId(tkwin),
	      w->gc, 0, 0, width, height, 0, 0);

   return;
}

/* Window Event Procedure */
static void WavfmEventProc(ClientData clientData, XEvent *eventPtr)
{
   Wavfm *w = (Wavfm *)clientData;

   switch (eventPtr->type) {
   case Expose:
      if (eventPtr->xexpose.count == 0) goto redraw;
      break;
   case ConfigureNotify:
      goto redraw;
      break;
   case DestroyNotify:
      Tcl_DeleteCommandFromToken( w->interp, w->tclCmd);
      w->tkwin = NULL;
      if (w->flags & REDRAW) {
	 Tk_CancelIdleCall( WavfmDisplay, (ClientData) w);
	 w->flags &= ~REDRAW;
      }
      Tcl_EventuallyFree( (ClientData) w, WavfmDestroy);
      break;
   case FocusIn:
      /* fprintf(stderr,"FocusIn\n"); */
      w->flags |= FOCUS;
      break;
   case FocusOut:
      w->flags &= ~FOCUS;
      break;
   }
   return;

redraw:
   if ((w->tkwin != NULL) && !(w->flags & REDRAW)) {
      Tk_DoWhenIdle( WavfmDisplay, (ClientData) w);
      w->flags |= REDRAW;
   }
}

/* Destroy */
static void WavfmDestroy(char *blockPtr)
{
   Wavfm *w = (Wavfm *)blockPtr;

   if (w->sampObj != NULL) {
      Tcl_DecrRefCount( w->sampObj);
   }
   if (w->shape != NULL) {
      Tcl_Free( (char *) w->shape);
   }
   if (w->points != NULL) {
      Tcl_Free( (char *) w->points);
   }
   if (w->gc != None) {
      Tk_FreeGC(w->display, w->gc);
   }
   if (w->cursorgc != None) {
      Tk_FreeGC(w->display, w->cursorgc);
   }
   if (w->selectgc != None) {
      Tk_FreeGC(w->display, w->selectgc);
   }
   if (w->pixmap != 0) {
     Tk_FreePixmap(w->display, w->pixmap);
   }
   if (w->pixmap2 != 0) {
     Tk_FreePixmap(w->display, w->pixmap2);
   }
   if (w->flags & REDRAW) {
      Tk_CancelIdleCall( WavfmDisplay, (ClientData) w);
   }
   Tk_FreeOptions( configSpecs, (char *) w, w->display, 0);
   Tcl_Free( (char *) w);
}
