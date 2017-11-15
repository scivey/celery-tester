#!/usr/bin/env zsh
#
[[ $- == *"i"* ]] || set -euo pipefail ;
. ${0:A:h}/_common.zsh
WORKER_CMD_BASEN=${0:A:t}

ca-lib-load 'pidfile'

ca-worker-cmd::pstree() {
    local worker_pid ;
    read -r worker_pid < <( ca-pidfile-read-worker-pid-or-die )
    exec pstree -s -p $worker_pid
}
ca-worker-cmd::getpid-parent() {
    ca-pidfile-read-worker-pid-or-die
}
ca-worker-cmd::getpid-subs() {
    local parent_worker_pid ;
    read -r parent_worker_pid < <( ca-pidfile-read-worker-pid-or-die )
    ps -o pid --ppid $parent_worker_pid --no-heading | sort -n
}


_ls-pids-internal-unsorted() {
    ca-worker-cmd::getpid-parent ;
    ca-worker-cmd::getpid-subs ;
}
_ls-pids-internal-joined() {
    _ls-pids-internal-unsorted \
        | tr '\n' ',' \
        | sed -r 's/,$/\n/'
}

ca-worker-cmd::ls-pids() {
    _ls-pids-internal-unsorted | sort -n
}

_ca-priv-proc-count-helper() {
    printf '%s\n' "$(tr -d --complement ',' <<< "$1")" ;
}

_ca-priv-proc-count-from-pid-str() {
    # 10,512,52 -> 3
    # 82,12,9,1241 -> 4
    # 937,10 -> i'm not going to explain it again. next time listen.
    local pid_str=$1 ;
    local just_commas ;
    read -r just_commas < <( _ca-priv-proc-count-helper "$pid_str" )
    just_commas=",${just_commas}"
    echo ${#just_commas}

}
ca-worker-cmd::debug-pidstr() {
    local pids_str ; read -r pids_str < <( _ls-pids-internal-joined )
    echo "ROLE COLUMN" >&2 ;
    _ca-internal-ps-extra-role-col "$pids_str"
    echo "END ROLE COLUMN" >&2
}

_ca-internal-ps-extra-role-col() {
    # this expects the first PID to be the main worker process
    local pids_str=$1 ;
    typeset -i proc_count=0
    read -r proc_count < <( _ca-priv-proc-count-from-pid-str $pids_str )
    typeset -i sub_count=0
    (( sub_count=proc_count-1 ))
    echo "ROLE" ;
    echo "parent" ;
    typeset -i seq_lim=0
    (( seq_lim=sub_count-1 ))
    seq 0 $seq_lim | sed -r 's/^.*$/child/'
}

ca-worker-cmd::ps() {
    local pids_str ;
    read -r pids_str < <( _ls-pids-internal-joined )
    # say "pids_str='$pids_str'"
    paste <( _ca-internal-ps-extra-role-col $pids_str ) \
          <( ps -q "$pids_str" $@ )
}

ca-worker-cmd::ps-fmt1() {
    typeset fmt_parts=(
        pid
        pgid
        pri  # sched priority
    )

    fmt_parts+=(
        %cpu
        time # not how long process has been alive -- a measure of cpu usage
    )

    fmt_parts+=(
        %mem
        rss  # resident set size (memory in use)
        vsz  # another mem metric - rss plus paged-out ('virtual') memory
    )


    fmt_parts+=(
        start   # the actual time the process started
                # this is HH:MM:SS if the process is newish, but
                # can also be a datestamp

        etime   # actual elapsed time since the process started
                # (unlike the 'time' metric).
                # like `start`, this can be a timestamp or datestamp
                # depending on age.

    )

    fmt_parts+=(
        nlwp # thread count
    )
    fmt_parts+=(
        tty    # controlling tty, if any
        tpgid  # the PGID of the connected tty (if any)
    )

    fmt_parts+=(
        comm  # process name -- just the basename of the executable
    )
    # command
    ca-worker-cmd::ps \
        -o ${(j.,.)fmt_parts}
}


ca-worker-cmd::show-commands() {
    functions + \
        | grep -E '^ca-worker-cmd::' \
        | sed -r 's/^ca-worker-cmd::(.*)$/\1/'
}
_show-help-internal() {
    echo "USAGE" ;
    printf '\t$WORKER_CMD_BASEN COMMAND ARG1 ... [, ARGN]\n' ;
    echo "" ;
    echo "COMMANDS" ;
    ca-worker-cmd::show-commands \
        | sed -r 's/^/  - /' ;
    echo "----" ;
}

ca-worker-cmd::help() {
    _show-help-internal >&2 ;
}
_err-give-command() {
    _show-help-internal >&2;
    die "Specify command"
}
_err-unknown-command() {
    _show-help-internal >&2 ;
    local cmd_name=$1 ; shift ;
    local cmd_args="''" ;
    [[ $# -lt 1 ]] || { cmd_args="'$*'" ; shift ; }
    die "Unknown command '$cmd_name' with args '$cmd_args'"
}
__runit() {
    [[ $# -gt 0 ]] || _err-give-command ;
    local cmd_name=$1 ; shift ;
    case "$cmd_name" in
        -h | --help | help ) { ca-worker-cmd::help ; exit 0 ; } ;;
        # *) { true ; } ;;
    esac
    local full_sym="ca-worker-cmd::${cmd_name}"
    debug "full_sym='$full_sym'"
    if ! type "$full_sym" &>/dev/null; then
        _err-unknown-command "$cmd_name" $@
    fi
    ${full_sym} $@
}
__runit $@

