#!/bin/sh
#
# Identity and prefix of the running container, for triaging a launch that
# comes up at the wrong URL or cannot write to the served tree.
#
set -eu

echo "uid=$(id -u) gid=$(id -g) groups=$(id -G)"
echo "USER=${USER:-} NB_PREFIX=${NB_PREFIX:-} PUBLIC_URL=${PUBLIC_URL:-}"
echo "HELX_HTML_DIR=${HELX_HTML_DIR:-} HELX_PORT=${HELX_PORT:-}"
