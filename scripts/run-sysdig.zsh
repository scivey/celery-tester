#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;
. ${0:A:h}/_common.zsh

__read-worker-pid() {
    if ! ca-pidfile-read "celery-worker"; then
        fatal "failed to read worker pid."
    fi
}

__runit() {
    local worker_pid ;
    read -r worker_pid < <( __read-worker-pid )
    typeset exec_args=()
    if [[ $UID -eq 0 ]]; then
        say "I'm already root - will run sysdig without sudo."
    else
        exec_args+=( 'sudo' )
    fi
    exec_args+=( 'sysdig' )

    exec ${exec_args[@]} -A -s 512 proc.pid=$worker_pid or proc.apid=$worker_pid
}

__runit $@



