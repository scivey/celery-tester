#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;

. ${0:A:h}/_base.zsh

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

