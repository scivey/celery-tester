#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;

. ${0:A:h}/_base.zsh

ca-pidfile-path() {
    local proc_name=$1 ; shift ;
    echo "$RUN_D/${proc_name}.pid"
}

ca-pidfile-write() {
    # process id is only valid if you're going to `exec()`
    local proc_name=$1 ; shift ;
    zmodload zsh/system
    local proc_pid=$sysparams[pid]
    local destf ; read -r destf < <( ca-pidfile-path $proc_name )

    if [[ -e $destf ]] && ca-pidfile-read $proc_name &>/dev/null; then
        fatal "existing pidfile $destf seems to refer to a valid process"
    fi

    local tmpf="${destf}.tmp~"
    mkdir -p $RUN_D
    rm -f $tmpf ;
    echo "$proc_pid" > $tmpf ;
    mv -f $tmpf $destf
}


ca-pidfile-read() {
    local pidf_path ;
    local proc_name=$1 ; shift ;
    read -r pidf_path < <( ca-pidfile-path $proc_name )
    if [[ ! -e $pidf_path ]]; then
        warn "no pidfile found in $RUN_D for process $proc_name"
        return 1
    fi
    local pid_value
    read -r pid_value < $pidf_path
    pid_value=${pid_value// /}
    if [[ $pid_value == "" ]]; then
        warn "invalid pidfile contents: '$pid_value'"
        return 1
    fi
    if ! kill -0 $pid_value &>/dev/null; then
        warn "process $pid_value referenced by $pidf_path does not exist."
        return 1
    fi
    echo $pid_value
}


ca-pidfile-read-worker-pid-or-die() {
    if ! ca-pidfile-read $WORKER_PROCNAME; then
        fatal "failed to read worker pid."
    fi
}
