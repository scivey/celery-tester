#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;
. ${0:A:h}/_common.zsh
ca-lib-load 'venv'
ca-venv-exec-in-app-dir ipython


