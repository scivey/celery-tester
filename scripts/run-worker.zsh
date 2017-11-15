#!/usr/bin/env zsh
#
[[ $- == *"i"* ]] || set -euo pipefail ;
. ${0:A:h}/_common.zsh

ca-pidfile-write "celery-worker"
ca-venv-exec-in-app-dir celery -A celery_app.conf worker -l info --concurrency 4

