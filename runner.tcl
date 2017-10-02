#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec wish -encoding utf-8 "$0" ${1+"$@"}

package require sshcomm

source [file dirname [info script]]/lockuser.tcl

apply {{} {
    set opts [lockuser::posix-getopt ::argv]

    set hostList [lassign $::argv user]

    set emitter [list apply {args {
        puts [{*}$args]
    }}]

    set top .
    foreach host $hostList {
        set ssh [sshcomm::ssh $host \
                     -sudo yes \
                     -sudo-askpass-path /usr/libexec/openssh/gnome-ssh-askpass]
        set cid [$ssh comm new]
        comm::comm send $cid [sshcomm::definition ::lockuser]
        $cid ::lockuser lck -user $user {*}$opts
        pack [button $top.w[incr i] -text "Run on $host" \
                  -command [list {*}$emitter $cid lck run]]
        update
    }
}}


# proc Reload [list [list dirname [file dirname [info script]]]] {
#     source $dirname/lockuser.tcl
#     comm::comm send $::cid [sshcomm::definition ::lockuser]
# }

# Reload

# $cid ::lockuser lck -user XXX
