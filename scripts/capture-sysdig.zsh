#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;
. ${0:A:h}/_common.zsh

ca-lib-load 'sysdig' 'pidfile'

__runit() {
    ca-sysdig-watch-worker-persistent $@
}

__runit $@


