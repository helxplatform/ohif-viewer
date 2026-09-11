#!/bin/sh
#
# HeLx container entrypoint. Mirrors the convention used by the other HeLx
# images (rstudio-server, pgadmin4-ldap, filebrowser): run every *.sh in
# /helx in name order, then hand off to $FINAL_COMMAND.
#
set -eu

export USER=${USER:-helx}

# HeLx routes each launched app at /private/<app>/<user>/<guid> and, for an app
# declared with `proxy-rewrite-rule: True`, passes that prefix through to the
# container untouched. NB_PREFIX carries it and never has a trailing slash.
export NB_PREFIX=${NB_PREFIX:-/}

# Change to the root directory to mitigate problems if the current working
# directory is deleted.
cd /

HELX_SCRIPT_DIR=${HELX_SCRIPT_DIR:-/helx}
INIT_SCRIPTS_TO_RUN=$(ls -1 "$HELX_SCRIPT_DIR"/*.sh 2>/dev/null) || true
for INIT_SCRIPT in $INIT_SCRIPTS_TO_RUN; do
  echo "Running $INIT_SCRIPT"
  "$INIT_SCRIPT"
done

FINAL_COMMAND=${FINAL_COMMAND:-/start-ohif.sh}
exec "$FINAL_COMMAND" "$@"
