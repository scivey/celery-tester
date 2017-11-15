#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;

export SCRIPTS_D=${0:A:h}
export ROOT_D=${SCRIPTS_D:h}
export TMP_D=${ROOT_D}/tmp
export RUN_D=$TMP_D/run
export VENV_D=${TMP_D}/venv
export APP_PACKAGE="celery_app"
export APP_PACKAGE_D=$ROOT_D/$APP_PACKAGE


function pushd() { builtin pushd $@ >/dev/null ; }
function popd() { builtin popd $@ > /dev/null ; }


ca-venv-ensure() {
    if [[ ! -d $VENV_D ]]; then
        virtualenv -p python2.7 $VENV_D
        $VENV_D/bin/pip install --upgrade pip
        $VENV_D/bin/pip install -r $ROOT_D/requirements.txt
    fi
}

ca-venv-exec() {
    ca-venv-ensure ;
    local bin_name=$1 ; shift ;
    exec $VENV_D/bin/$bin_name $@
}

ca-venv-exec-in-app-dir() {
    pushd $ROOT_D
    export PYTHONPATH=$ROOT_D
    ca-venv-exec $@
}

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

die() { echo "FATAL: $*" >&2 ; exit 1 l }
say() { echo "[info] $*" >&2 ; }
warn() { echo "WARNING: $*" >&2 ; }

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


