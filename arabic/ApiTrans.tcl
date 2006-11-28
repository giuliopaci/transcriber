global v 
set v(win,active) 1
proc GetDuration  {} {
    global v
    return $v(sig,len)
}

proc Path-sound2 {} {
    global v
    return $v(sig,name)
}

proc WindowActive {} {
    global v
    return $v(win,active)
}

proc isPlaying {} {
    global v
    return $v(play,state)
}




#bind $v(tk,wavfm) <Enter> {
bind . <FocusIn> {
    set v(win,active) 1
}

bind . <FocusOut> {
    set v(win,active) 0
}