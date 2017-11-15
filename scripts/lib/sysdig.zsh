#!/usr/bin/env zsh


[[ $- == *"i"* ]] || set -euo pipefail ;

. ${0:A:h}/_base.zsh


ca-sysdig-watch-worker() {
    local worker_pid ;
    read -r worker_pid < <( ca-pidfile-read-worker-pid-or-die )
    typeset exec_args=()
    if [[ $UID -eq 0 ]]; then
        say "I'm already root - will run sysdig without sudo."
    else
        exec_args+=( 'sudo' )
    fi
    exec_args+=( 'sysdig' )

    typeset base_filter=(
        \(proc.pid=$worker_pid or proc.apid=$worker_pid\)
    )
    typeset extra_filter=()

    typeset sysdig_flags=( -A )
    typeset -i s_buffsize=512 # cli flag is -s
    local in_posargs=false
    local currarg
    while [[ $# -gt 0 ]]; do
        currarg=$1 ; shift ;
        if [ "$in_posargs" = false ]; then
            if [[ $currarg == "--" ]]; then
                in_posargs=true ; continue ;
            else
                case $currarg in
                    -s) { s_buffsize=$1 ; shift ; continue } ;;
                    *) { sysdig_flags+=( $currarg ) ; continue ; } ;;
                esac
            fi
        else
            extra_filter+=( $@ ) ; shift $# ; break ;
        fi
    done

    typeset final_filter=()
    final_filter+=( ${base_filter[@]} )
    if [[ ${#extra_filter} -gt 0 ]]; then
        final_filter+=( 'and' )
        final_filter+=( ${extra_filter[@]} )
    fi

    sysdig_flags+=( -s $s_buffsize )

    exec ${exec_args[@]} ${sysdig_flags[@]} ${final_filter[@]}

}


ca-sysdig-watch-worker-quiet() {
    ca-sysdig-watch-worker -- \(evt.type!=epoll_ctl and evt.type!=switch \
            and evt.type!=gettimeofday and evt.type!=epoll_wait \
            and evt.type!=wait4 \
            and evt.type!=clock_gettime\)
}

ca-sysdig-watch-worker-persistent() {
    if [[ $# -lt 1 ]]; then
        die "specify trace destination"
    fi
    local tracef=$1 ; shift ;
    say "writing sysdig trace to '$tracef'"
    ca-sysdig-watch-worker -w $tracef $@
}

# __runit() {
#     typeset filter_part=(
#         \(proc.pid=$worker_pid or proc.apid=$worker_pid\) \
#         and \
#         \(evt.type!=epoll_ctl and evt.type!=switch \
#             and evt.type!=gettimeofday and evt.type!=epoll_wait \
#             and evt.type!=wait4 \
#             and evt.type!=clock_gettime\)
#     )

#     if [[ $# -gt 0 ]]; then
#         filter_part+=( and $@ )
#     fi
#     exec ${exec_args[@]} -A -s 512 ${filter_part[@]}
# }

# __runit $@



