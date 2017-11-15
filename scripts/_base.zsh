#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;

export SCRIPTS_D=${0:A:h}
export SCRIPTS_LIB_D=$SCRIPTS_D/lib
export ROOT_D=${SCRIPTS_D:h}
export TMP_D=${ROOT_D}/tmp
export RUN_D=$TMP_D/run
export VENV_D=${TMP_D}/venv
export APP_PACKAGE="celery_app"
export APP_PACKAGE_D=$ROOT_D/$APP_PACKAGE
export WORKER_PROCNAME="celery-worker"

# export CA_DEBUG_loader="1"
# export CA_DEBUG_base="1"
function pushd() { builtin pushd $@ >/dev/null ; }
function popd() { builtin popd $@ > /dev/null ; }


die() { echo "FATAL: $*" >&2 ; exit 1 ; }
say() { echo "[info] $*" >&2 ; }
warn() { echo "WARNING: $*" >&2 ; }

_ca-sym-defined() {
    if ! typeset $1 &>/dev/null; then
        return 1
    fi
}
_ca-sym-read() {
    if ! _ca-sym-defined $1; then
        return 1
    fi
    local result="" ;
    local src='result="${'"$1"':-""}"'
    eval "$src" ;
    echo $result
}

debug-ifdef() {
    local sym_suffix=$1 ; shift ;
    local sym="CA_DEBUG_${sym_suffix}"
    if ! _ca-sym-defined $sym ; then return ; fi
    local sym_val ;
    read -r sym_val < <( _ca-sym-read "$sym" ) ;
    # echo "DEBUG2: \$sym_val='$sym_val'" >&2 ;
    if [[ "$sym_val" == "" ]] || [[ "$sym_val" == "0" ]]; then
        return
    fi
    echo "[DEBUG / ${sym_suffix}] : $*" >&2
}
debug() {
    debug-ifdef 'base' $@
}
debug-loader() {
    debug-ifdef 'loader' $@
}


_ca-loader-die-not-found() {
    die "lib '$1' not found."
}
_ca-loader-resolve-name() {
    local lib_name=$1 ; shift ;
    local lib_d=$SCRIPTS_LIB_D ;
    local target=$lib_name
    if [[ -e $target ]]; then
        echo $target ; return ;
    fi

    if [[ $target == "/"* ]]; then
        if [[ -e "${target}.zsh" ]]; then
            echo "${target}.zsh" ; return ;
        fi
        _ca-loader-die-not-found $lib_name
    fi
    local candidate=${lib_d}/${lib_name}
    [[ ! -e $candidate ]] || { echo $candidate ; return ; }

    candidate="${candidate}.zsh"
    [[ ! -e $candidate ]] || { echo $candidate ; return ; }

    _ca-loader-die-not-found $lib_name
}

typeset -Ax CA_LOADED
CA_LOADED=("dummy" "1")

ca-lib-load() {
    local curr_lib orig_name
    typeset -A local_seen
    local_seen=("local-dummy" "1")
    for orig_name in $@; do
        read -r curr_lib < <( _ca-loader-resolve-name $orig_name )
        if [[ -z ${local_seen[$curr_lib]+x} ]]; then
            local_seen+=( $curr_lib "1" )
        else
            debug-loader "$curr_lib already loaded (same call)" ;
            continue ;
        fi
        if [[ -z ${CA_LOADED[$curr_lib]+x} ]]; then
            CA_LOADED+=( $curr_lib "1" )
        else
            debug-loader "$curr_lib already loaded (same process)" ;
            continue ;
        fi
        debug-loader "loading $orig_name (resolved to $curr_lib)"
        [[ -e $curr_lib ]] || die "$curr_lib should always exist here."
        . $curr_lib
    done
}

ca-lib-list() {
    find $SCRIPTS_LIB_D -maxdepth 1 -mindepth 1 -type f -printf '%P\n' \
        | grep -Ev '^_' \
        | grep -Ev '(\.disabled$|\.disabled\..*)'
}

ca-lib-load-all() {
    local curr_name
    typeset names=()
    while read -r curr_name; do
        names+=( $curr_name )
    done < <( ca-lib-list )
    ca-lib-load ${names[@]}
}
