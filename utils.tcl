#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

package require Tcl 8.5

namespace eval lockuser {
    proc read_file {fn args} {
	set fh [open $fn]
	scope_guard fh [list close $fh]
	if {[llength $args]} {
	    fconfigure $fh {*}$args
	}
	read $fh
    }

    proc read_file_lines {fn args} {
	set fh [open $fn]
	scope_guard fh [list close $fh]
	if {[llength $args]} {
	    fconfigure $fh {*}$args
	}
	set lines {}
	while {[gets $fh line] >= 0} {
	    lappend lines $line
	}
	set lines
    }

    proc append_file {fn data args} {
	write_file $fn $data {*}$args -access a
    }

    proc write_file_lines {fn list args} {
	write_file $fn [join $list \n] {*}$args
    }

    proc write_file {fn data args} {
	set data [string trim $data]
	regsub {\n*\Z} $data \n data
	write_file_raw $fn $data {*}$args
    }

    proc write_file_raw {fn data args} {
	set access [dict-cut args -access w]
	if {![regexp {^[wa]} $access]} {
	    error "Invalid access flag to write_file $fn: $access"
	}
	set attlist {}
	set rest {}
	if {[set perm [dict-cut args -permissions ""]] ne ""} {
	    if {[string is integer $perm]} {
		lappend rest $perm
	    } else {
		lappend attlist -permissions $perm
	    }
	}
	foreach att [list -group -owner] {
	    if {[set val [dict-cut args $att ""]] ne ""} {
		lappend attlist $att $val
	    }
	}
	set fh [open $fn $access {*}$rest]
	if {$attlist ne ""} {
	    file attributes $fn {*}$attlist
	}
	scope_guard fh [list close $fh]
	if {[llength $args]} {
	    fconfigure $fh {*}$args
	}
	puts -nonewline $fh $data
	set fn
    }

    proc dict-cut {dictVar key args} {
	upvar 1 $dictVar dict
	if {[dict exists $dict $key]} {
	    set res [dict get $dict $key]
	    dict unset dict $key
	    set res
	} elseif {[llength $args]} {
	    lindex $args 0
	} else {
	    error "No such key: $key"
	}
	
    }

    proc scope_guard {varName command} {
	upvar 1 $varName var
	uplevel 1 [list trace add variable $varName unset \
		       [list apply [list args $command]]]
    }
    
    proc posix-getopt {argVar {dict ""} {shortcut ""}} {
	upvar 1 $argVar args
	set result {}
	while {[llength $args]} {
	    if {![regexp ^- [lindex $args 0]]} break
	    set args [lassign $args opt]
	    if {$opt eq "--"} break
	    if {[regexp {^-(-no)?(-\w[\w\-]*)(=(.*))?} $opt \
		     -> no name eq value]} {
		if {$no ne ""} {
		    set value no
		} elseif {$eq eq ""} {
		    set value [expr {1}]
		}
	    } elseif {[dict exists $shortcut $opt]} {
		set name [dict get $shortcut $opt]
		set value [expr {1}]
	    } else {
		error "Can't parse option! $opt"
	    }
	    lappend result $name $value
	    if {[dict exists $dict $name]} {
		dict unset dict $name
	    }
	}

	list {*}$dict {*}$result
    }


    namespace export *
}
