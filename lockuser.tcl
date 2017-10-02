#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

package require Tcl 8.5
package require snit
package require struct::list

source [file join [file dirname [info script]] utils.tcl]

snit::type lockuser {
    
    option -dry-run no
    option -console ""

    option -user
    option -home /home

    option -target {usermod dotssh procmailrc mailaliases}

    #========================================

    method test args {
        if {![llength $args]} {
            set args $options(-target)
        }
        foreach action $args {
            set res [$self $action test]
            $self msg $res
        }
    }

    method run {args} {
        if {![llength $args]} {
            set args $options(-target)
        }
        set okng [dict create OK 0 NG 0]
        foreach action $args {
            set res [$self $action test]
            $self msg $res
            if {[lindex $res 0] eq "OK"} {
                dict incr okng OK
            } elseif {[lindex $res 0] eq "NG"} {
                $self $action action
                if {$options(-dry-run)} continue
                set res [$self $action test]
                if {[lindex $res 0] eq "OK"} {
                    dict incr okng OK
                } else {
                    $self msg $res
                    dict incr okng NG
                }
            }
        }
        set okng
    }

    #========================================

    #========================================

    variable myLogBuffer []
    method buffered args {
        set options(-console) ""
        set myLogBuffer []
        $self msg RESULT: [$self {*}$args]
        set myLogBuffer
    }
    option -trace no
    method msg args {
        if {$options(-console) ne ""} {
            puts $options(-console) $args
        } else {
            set prefix []
            if {$options(-trace)} {
                set info [info frame -1]
                set prefix "[dict get $info proc] line [dict get $info line]: "
            }
            append myLogBuffer $prefix[join $args]\n
        }
    }

    method do args {
        if {$options(-dry-run)} {
            $self msg "# $args"
        } else {
            if {[lindex $args 0] eq "self"} {
                $self {*}$args
            } else {
                {*}$args
            }
        }
    }

    #========================================

    method home {} {
        if {$options(-user) eq ""} {
            error "Please specify -user!"
        }
        return $options(-home)/$options(-user)
    }

    #========================================
    # usermod
    #========================================

    option -shadow /etc/shadow

    method {usermod test} {} {
        set entry [$self passwd find $options(-user) $options(-shadow)]
        if {$entry eq ""} {
            list NG msg "No such user"
        } elseif {[string index [lindex $entry 1] 0] ne "!"} {
            list NG msg "Not locked"
        } else {
            list OK msg "already locked"
        }
    }

    method {usermod action} {} {
        $self do exec usermod -L $options(-user)
    }

    method {passwd find} {user file} {
        foreach line [read_file_lines $file] {
            set items [split $line :]
            if {[lindex $items 0] eq $user} {
                return $items
            }
        }
    }

    #========================================
    # dotssh
    #========================================

    method {dotssh filename} {} {
        return [$self home]/.ssh
    }

    method {dotssh test} {} {
        set fn [$self dotssh filename]
        if {[file exists $fn]} {
            list NG fn $fn msg "should be removed"
        } else {
            list OK fn $fn msg "already removed"
        }
    }

    method {dotssh action} {} {
        set fn [$self dotssh filename]
        set newFn [file join [file dirname $fn] dot[file tail $fn]]
        
        $self do file rename $fn $newFn
    }

    #========================================
    # procmailrc
    #========================================

    method {procmailrc filename} {} {
        return [$self home]/.procmailrc
    }

    method {procmailrc test} {} {
        set fn [$self procmailrc filename]
        if {[file exists $fn]} {
            list NG fn $fn msg "should be removed"
        } else {
            list OK fn $fn msg "already removed"
        }
    }

    method {procmailrc action} {} {
        set fn [$self procmailrc filename]
        set newFn [file join [file dirname $fn] dot[file tail $fn]]
        
        $self do file rename $fn $newFn
    }

    #========================================
    # mailaliases
    #========================================    

    option -mailaliases /etc/aliases
    method {mailaliases filename} {} {
        return $options(-mailaliases)
    }

    option -mailalias-remover-script [list perl -Mstrict -wple {
            our $USER; BEGIN {$USER = shift};
            if (my ($alias, $sep, $values) = /^([-\w\.]+)(:\s*)(.*)/) {
                my @U = split /\s*,\s*/, $values;
                if (grep {$_ eq $USER} @U) {
                    $_ = "$alias$sep".join(", ", grep {$_ ne $USER} @U);
                    print STDERR "Updated: $alias";
                }
            }
    }]

    method {mailaliases test} {} {
        set fn [$self mailaliases filename]
        
        catch {exec {*}$options(-mailalias-remover-script) \
                   $options(-user) $fn >/dev/null} result

        if {[llength $result]} {
            list NG fn $fn msg "should be modified" diag $result
        } else {
            list OK fn $fn msg "already clean"
        }
    }

    method {mailaliases action} {} {
        if {$options(-dry-run)} {
            error "Dry-run is not supported for mailaliases action!"
        }

        set fn [$self mailaliases filename]

        catch {exec {*}[linsert $options(-mailalias-remover-script) \
                            1 -i.bak] \
                   $options(-user) $fn} result

        if {[llength $result]} {
            list NG fn $fn msg "modified" diag $result
        } else {
            list OK fn $fn msg "already clean"
        }
    }

    #========================================

    #========================================

}

if {![info level] && [info script] eq $::argv0} {
    set opts [lockuser::posix-getopt ::argv]

    lockuser obj {*}$opts
    
    if {[llength $::argv]} {
        puts [obj buffered {*}$::argv]
    } else {
        obj test
    }
}
