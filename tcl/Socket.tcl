#!/bin/sh
#  -*-tcl-*-\
exec wish8.3 "$0" ${1:+"$@"}

# RCS: @(#) $Id$

# Copyright (C) 1998-2000, DGA - part of the Transcriber program
# distributed under the GNU General Public License (see COPYING file)

# Server: launch Transcriber with
#  % trans -patch Socket.tcl
#
# Client (within Tcl code):
#   source Socket.tcl
#   TransClient command args
#
# where command is currently one of:
#     NewTrans [$sig]
#     ReadTrans $trans [$sig]
#     Signal $sig
#     EmptySignal
#     SetCursor $pos
#     GetCursor => $pos
#     SetSelection $begin $end
#     GetSelection $beginVar $endVar => 1 if selection, 0 else
#     GetSelectionBoundaries => {begin end} / {}
#     ViewSelection [$begin $end]
#     Play
#     PlayCurrentSegmt
#     PlayAround [$len]
#     PauseAudio
#     IsPlaying => 0/1
#     SetCurrentSegment $nb
#     MoveNextSegmt +1/-1
#     GetSegmtNb seg0
#     GetSegmtField seg0 $v(segmt,curr) -begin/-end/-text
#     GetCurrentSegmt => {begin end text}
#     InsertSegment
#     DeleteSegment
#     PasteAll $v(tk,edit) $text
#
# and args doesn't contain newline, ] or ; chars.

######################################################################

# Sending Tcl command through sockets - Client side
#
# socket::Send $server $port $cmd
# returns result of $cmd execution on $server/$port.
#
# Protocol:
# 1/ open socket $port on $server
# 2/ send "CMD $id ENC $enc LEN $len <RETURN> $cmd" on socket
#    where $id is a random ID, encoding should be 'binary', len is $cmd length
# 3/ get back string "RES $id CODE $code ENC $enc LEN $len <RETURN> $res"
#    where $id is same ID, code is 'ok' or 'error', encoding is 'binary'
#    and len is $result length

namespace eval socket {

  # send Tcl command to server:port socket
  proc Send {server port cmd} {
    set channel [Client $server $port]
    set id [expr int(65536*rand())]
    set enc [fconfigure $channel -encoding]
    set len [string length $cmd]
    puts $channel "CMD $id ENC $enc LEN $len"
    puts -nonewline $channel $cmd
    if {[catch {
      flush $channel
      set res [gets $channel]
    }]} {
      # connexion seems closed; reopen and retry
      CloseClient $server $port
      Send $server $port $cmd
      return
    }
    if {[regexp {^ *RES +([^ ]+) +CODE +([^ ]+) +ENC +([^ ]+) +LEN +(-?[0-9]+) *$} $res x rid code enc len]} {
      if {$len > 0} {
	set res [read $channel $len]
	if {[string length $res] < $len} {
	  CloseClient $server $port
	  return -code error "socket error on $server:$port - missing chars"
	}
      } else {
	set res ""
      }
      if {$rid != $id} {
	CloseClient $server $port
	return -code error "socket error on $server:$port - wrong command ID"
      }
      return -code $code $res
    } else {
      CloseClient $server $port
      return -code error "socket error on $server:$port - $res"
    }
  }

  # At first call, connect to server with given port, and keep connection
  # channel in an array for further calls.
  proc Client {server port} {
    variable chan
    if {![info exists chan($server,$port)]} {
      if {[catch {socket $server $port} channel]} {
	error "Couldn't open command server $port on $server\n($channel)"
      }
      fconfigure $channel -buffering full -translation binary
      set chan($server,$port) $channel
    }
    return $chan($server,$port)
  }

  proc CloseClient {server port} {
    variable chan
    catch {
      close $chan($server,$port)
    }
    catch {
      unset chan($server,$port)
    }
  }
}

######################################################################

# Sending Tcl command through sockets - Server side
#
# socket::Server $port $interface
#   start socket command server on port $port, with optional interface 
#   for monitoring socket use (0=disabled, 1=enabled (default)).
#
# Restrictions:
#  - only accepts connexions from local host
#  - don't accept multiple commands (sequence or embedded)
#  - limited to a list of commands (transAPI)


namespace eval socket {
  variable transAPI {
    NewTrans
    ReadTrans
    Signal
    EmptySignal
    SetCursor
    GetCursor
    SetSelection
    GetSelection
    GetSelectionBoundaries
    ViewSelection
    Play
    PlayCurrentSegmt
    PlayAround
    PauseAudio
    IsPlaying
    SetCurrentSegment
    MoveNextSegmt
    GetSegmtNb
    GetSegmtField
    GetCurrentSegmt
    InsertSegment
    DeleteSegment
    PasteAll
  }

  variable servsock
  variable servport
  variable peer
  variable busy
  variable msg

  # Socket server
  proc Server {port {interface 1}} {
    Msg "Sound server port $port"
    if [catch {
      variable servsock [socket -server socket::Accept $port]
      variable servport $port
      #vwait forever - needed only for tclsh case
      if {$interface} Interface
    } error] {
      puts $error
      exit
    }
  }

  # Connection to server
  proc Accept {sock addr port} {
    # We reject here foreign hosts - we could have some restricted list
    set local [lindex [fconfigure $sock -sockname] 0]
    if {$addr != $local} {
      Msg "Reject $sock from $addr port $port"
      close $sock
      return
    }
    Msg "Accept $sock from $addr port $port"
    fconfigure $sock -buffering full -translation binary
    fileevent $sock readable [list socket::Get $sock]
  }

  proc Get {sock} {
    Busy $sock
    set line ""
    if {[catch {gets $sock line} error]} {
      #Msg "in $sock line $line error $error"
      Close $sock
    } else {
      set id -1
      if {![regexp {^ *CMD +([^ ]+) +ENC +([^ ]+) +LEN +(-?[0-9]+) *$} $line x id enc len]} {
	Error $sock $id "Wrong header: $line"
	return
      }
      set line [string trim [read $sock $len]]
      Msg $line
      # prevent multiple/embedded commands (also restricts parameter values)
      if {[regexp "\[;\n\[]" $line]} {
	Error $sock $id "Wrong content: $line"	
	return
      }
      variable transAPI
      if {[lsearch $transAPI [lindex $line 0]] >= 0} {
	Exec $sock $id $line
      } else {
	Error $sock $id "Wrong command: $line"
      }
    }
    Free
  }

  # Execute command and write result to the socket channel in the format :
  #   CODE $code LEN $len <RETURN> $result
  proc Exec {sock id cmd} {
    if [catch {uplevel \#0 $cmd} res] {
      set code "error" 
    } else {
      set code "ok"
    }
    set enc [fconfigure $sock -encoding]
    set len [string length $res]
    puts $sock "RES $id CODE $code ENC $enc LEN $len"
    puts -nonewline $sock $res
    flush $sock
    return $res
  }

  proc Error {sock id msg} {
    Exec $sock $id [list error $msg]
    Close $sock
  }

  proc Close {sock} {
    Msg "closing connection"
    catch {close $sock}
    Free
  }

  proc Msg {txt} {
    variable msg $txt
    update idletasks
  }

  proc Busy {sock} {
    variable busy 1
    if {[catch {
      variable peer [lindex [fconfigure $sock -peername] 1]
    }]} {
      variable peer ""
    }
    update idletasks
  }

  proc Free {} {
    variable busy 0
  }

  proc CloseServ {} {
    variable servsock
    catch {close $servsock}
    exit
  }

  proc Restart {} {
    variable servsock
    variable servport
    catch {close $servsock}
    Server $servport
  }

  proc Interface {} {
    #wm title . "Transcriber's Socket Server"
    #wm protocol . WM_DELETE_WINDOW {Quit}

    set w1 [toplevel .sock -relief raised -bd 1]
    #pack $w -side top -fill both -expand true
    
    foreach i {1} n {
      "Port"
    } var {socket::servport} {
      pack [frame $w1.$i] -side top -fill x
      label $w1.$i.l -text "$n:" -width 20 -anchor e
      pack $w1.$i.l -side left -padx 1m -pady 1m
      entry $w1.$i.e -textvariable $var -width 30
      pack $w1.$i.e -side left -padx 1m -pady 1m -fill x -expand true
    }
    
    set w [frame $w1.mid -relief raised -bd 1]
    pack $w -side top -fill both -expand true
    
    pack [frame $w.1] -side top -fill x
    label $w.1.l1 -text "Client:" -width 10
    label $w.1.l2 -textvariable socket::peer -width 20 -relief sunken -anchor w
    pack $w.1.l1 $w.1.l2 -side left -padx 1m -pady 1m

    pack [frame $w.3] -side top -fill x
    checkbutton $w.3.c -text busy -var socket::busy -anchor w
    pack $w.3.c -side left -padx 1m -pady 1m
    label $w.3.m -textvariable socket::msg -width 40 -relief sunken -anchor w
    pack $w.3.m -side left -padx 1m -pady 1m -fill x -expand true
    
    set w [frame $w1.bot -relief raised -bd 1]
    pack $w -side top -fill x

    #button $w.r -text Restart -command socket::Restart
    #button $w.q -text Close -command {socket::CloseServ; destroy .sock}
    #pack $w.r $w.q -side left -expand true -padx 3m -pady 2m
  }
}

######################################################################
# if launched from within Transcriber, automatically start server
# else create client facility procedure

if {[info exists v(trans,name)]} {
  socket::Server 8033
  # New procedures for more easy external use
  proc GetCurrentSegmt {} {
    global v
    return [list [GetSegmtField seg0 $v(segmt,curr) -begin] \
		[GetSegmtField seg0 $v(segmt,curr) -end] \
		[GetSegmtField seg0 $v(segmt,curr) -text]]
  }
  proc GetSelectionBoundaries {} {
    if {[GetSelection a b]} {
      return [list $a $b]
    } else {
      return {}
    }
  }
} else {
  proc TransClient {args} {
    socket::Send localhost 8033 $args
  }
}
