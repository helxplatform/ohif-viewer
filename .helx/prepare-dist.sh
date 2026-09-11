#!/bin/sh
#
# Adapt the dist tree produced by the repo-root Dockerfile's `builder` stage
# for the HeLx image. Run from the repo root:
#
#   .helx/prepare-dist.sh platform/app/dist <sentinel>
#
# On entry the tree is exactly what upstream produces: built with PUBLIC_URL
# set to <sentinel>, and run through .docker/compressDist.sh, which gzips every
# .js/.css/.map/.svg and leaves a zero-length original beside each .gz so that
# nginx's `try_files $uri` still matches and gzip_static can serve the .gz.
#
# On exit two things have changed, and /start-ohif.sh depends on both:
#   .helx-substitute   lists the files whose contents carry the sentinel
#   those files, plus app-config.js and google.js, are left UNcompressed
#
set -eu

DIST=${1:?usage: prepare-dist.sh <dist-dir> <sentinel>}
SENTINEL=${2:?usage: prepare-dist.sh <dist-dir> <sentinel>}
MANIFEST=.helx-substitute

cd "$DIST"

# The service worker precaches the entire build against a fixed scope. Every
# HeLx launch gets a fresh URL prefix, so a registration would be stale by the
# next launch while still holding storage, and the upstream loader unregisters
# every service worker on the origin -- which on HeLx means those belonging to
# the user's other running apps. Replace it with a loader that only cleans up
# after this app.
rm -f sw.js sw.js.gz sw.js.map sw.js.map.gz init-service-worker.js.gz
cat > init-service-worker.js <<'EOF'
// Service workers are disabled in the HeLx build: see .helx/prepare-dist.sh.
// Clean up a registration left by an earlier launch at this same path, and
// leave the registrations of the user's other HeLx apps alone.
if (navigator.serviceWorker) {
  navigator.serviceWorker.getRegistrations().then(function (registrations) {
    var base = window.PUBLIC_URL || '/';
    registrations.forEach(function (registration) {
      if (new URL(registration.scope).pathname === base) {
        registration.unregister();
      }
    });
  });
}
EOF

# Find the sentinel in both halves of the tree: the files compressDist.sh left
# alone (index.html above all) and the ones it gzipped. zgrep is not in every
# base image, so decompress through a pipe instead.
{
  find . -type f ! -name '*.gz' -size +0c -exec grep -lF "$SENTINEL" {} +
  find . -type f -name '*.gz' | while read -r gz; do
    if gzip -cd "$gz" 2>/dev/null | grep -qF "$SENTINEL"; then
      printf '%s\n' "${gz%.gz}"
    fi
  done
} | sed 's|^\./||' | sort -u > "$MANIFEST"

echo "prepare-dist: $(wc -l < "$MANIFEST") file(s) carry the PUBLIC_URL sentinel:"
sed 's/^/  /' "$MANIFEST"

# Two kinds of file have to stay uncompressed. Those carrying the sentinel are
# rewritten at container start, and re-compressing them there would add
# minutes to every launch. app-config.js and google.js can be replaced at
# start from the environment, and a stale .gz would win over the replacement
# because gzip_static is on. Both are served with nginx's on-the-fly gzip.
{
  cat "$MANIFEST"
  echo app-config.js
  echo google.js
} | sort -u | while read -r file; do
    if [ -f "$file.gz" ]; then
      gzip -df "$file.gz"
    fi
  done

echo "prepare-dist: done"
