#!/bin/sh
#
# Point the built viewer at the URL prefix this container was launched under,
# then serve it.
#
# The viewer is a static bundle whose asset URLs, router basename and
# index.html links all derive from PUBLIC_URL, which upstream fixes at build
# time. HeLx cannot: it mints /private/<app>/<user>/<guid> per launch and
# passes that prefix through to the container. So the image is built with a
# sentinel in place of PUBLIC_URL and the real prefix is substituted here, into
# the handful of files .helx/prepare-dist.sh recorded as carrying it.
#
set -eu

SENTINEL=${HELX_PUBLIC_URL_SENTINEL:-/__HELX_PUBLIC_URL__/}
HTML_DIR=${HELX_HTML_DIR:-/usr/share/nginx/html}
PORT=${HELX_PORT:-8080}
MANIFEST="$HTML_DIR/.helx-substitute"
STAMP="$HTML_DIR/.helx-public-url"

# PUBLIC_URL wins if set explicitly, otherwise take the prefix HeLx assigned.
BASE_URL=${PUBLIC_URL:-${NB_PREFIX:-/}}
case "$BASE_URL" in
  /*) ;;
   *) BASE_URL="/$BASE_URL" ;;
esac
case "$BASE_URL" in
  */) ;;
   *) BASE_URL="$BASE_URL/" ;;
esac

# What the assets currently say, so that restarting a container whose writable
# layer survived -- with a different prefix -- still converges.
APPLIED=$(cat "$STAMP" 2>/dev/null || echo "$SENTINEL")

if [ ! -f "$MANIFEST" ]; then
  echo "start-ohif: $MANIFEST is missing -- the image was not built by" \
       ".helx/Dockerfile, or .helx/prepare-dist.sh did not run" >&2
  exit 1
fi

if [ "$APPLIED" != "$BASE_URL" ]; then
  echo "start-ohif: rewriting asset base path $APPLIED -> $BASE_URL"
  while read -r file; do
    [ -f "$HTML_DIR/$file" ] || continue
    sed -i "s|$APPLIED|$BASE_URL|g" "$HTML_DIR/$file"
  done < "$MANIFEST"
  echo "$BASE_URL" > "$STAMP"
else
  echo "start-ohif: asset base path already $BASE_URL"
fi

# Runtime configuration, upstream-compatible: APP_CONFIG holds the JavaScript
# itself, APP_CONFIG_FILE points at a mounted file. Leave `routerBasename`
# unset (null) in either -- it falls back to window.PUBLIC_URL, which is the
# prefix substituted above.
if [ -n "${APP_CONFIG_FILE:-}" ]; then
  echo "start-ohif: taking app-config.js from $APP_CONFIG_FILE"
  cp "$APP_CONFIG_FILE" "$HTML_DIR/app-config.js"
elif [ -n "${APP_CONFIG:-}" ]; then
  # At build time APP_CONFIG names one of platform/app/public/config/*.js; at
  # run time it holds the config itself. Those sources are not in the image, so
  # a path here would otherwise be written out verbatim as the config.
  case "$APP_CONFIG" in
    *window.config*)
      echo "start-ohif: taking app-config.js from \$APP_CONFIG"
      printf '%s\n' "$APP_CONFIG" > "$HTML_DIR/app-config.js"
      ;;
    *)
      echo "start-ohif: \$APP_CONFIG must hold the JavaScript config itself," \
           "not a path to it ($APP_CONFIG). Use \$APP_CONFIG_FILE to point at" \
           "a mounted file, or --build-arg APP_CONFIG to choose one of the" \
           "in-tree configs at build time." >&2
      exit 1
      ;;
  esac
fi

# nginx has to answer on the prefix as well as at the root: HeLx forwards the
# full /private/... path. Strip it and let one location tree handle both.
#
# The bare prefix redirects instead, because react-router only strips a
# basename off a path that actually carries it -- landing on
# /private/a/b/c with a basename of /private/a/b/c/ renders an empty page.
# A redirect also satisfies the default readiness probe, which requests
# exactly that bare form and accepts any 2xx or 3xx.
PREFIX=${BASE_URL%/}
if [ -n "$PREFIX" ]; then
  PREFIX_RE=$(printf '%s' "$PREFIX" | sed 's/[.[\*^$()+?{|]/\\&/g')
  HELX_REWRITE="rewrite ^${PREFIX_RE}/(.*)\$ /\$1 last;

    location = ${PREFIX} {
        return 301 ${PREFIX}/\$is_args\$args;
    }"
else
  HELX_REWRITE="# served at the root; no prefix to strip"
fi

export HELX_PORT="$PORT"
export HELX_HTML_DIR="$HTML_DIR"
export HELX_REWRITE
envsubst '${HELX_PORT} ${HELX_HTML_DIR} ${HELX_REWRITE}' \
  < /etc/nginx/helx/default.conf.template \
  > /etc/nginx/conf.d/default.conf

echo "start-ohif: serving the OHIF Viewer on port $PORT at $BASE_URL"
exec nginx -g 'daemon off;'
