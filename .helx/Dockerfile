# HeLx image for the OHIF Viewer.
#
#   make -C .helx build
#
# This stage 2 only. Stage 1 is the `builder` stage of the repo-root Dockerfile,
# built separately and passed in as BUILDER_IMAGE, so that the recipe for
# building the viewer lives in exactly one place -- upstream's. `make build`
# does both; see .helx/README.md for the two commands if you need them apart.
#
# Everything HeLx-specific lives under .helx/, and no file tracked by upstream
# OHIF/Viewers is modified, so `git rebase upstream/master` never conflicts on
# account of the HeLx integration.
#
# Unlike the upstream image, this one is not pinned to a URL prefix. HeLx gives
# every launched app a path of its own -- /private/<app>/<user>/<guid> -- that
# is not known until the container starts, so the builder is invoked with
# PUBLIC_URL set to a sentinel and /start-ohif.sh substitutes the real prefix
# into the built assets.

ARG BUILDER_IMAGE=ohif-viewer-builder
FROM ${BUILDER_IMAGE} AS builder

# Undo the parts of upstream's build that assume a fixed PUBLIC_URL, and record
# what has to be rewritten at startup.
ARG PUBLIC_URL=/__HELX_PUBLIC_URL__/
RUN .helx/prepare-dist.sh platform/app/dist "${PUBLIC_URL}"

FROM nginxinc/nginx-unprivileged:1.27-alpine AS final

ARG HELX_PORT=8080
ENV HELX_PORT=${HELX_PORT}
ENV HELX_HTML_DIR=/usr/share/nginx/html

# Carry the sentinel forward so /start-ohif.sh substitutes exactly what the
# build baked in, including when PUBLIC_URL was overridden above.
ARG PUBLIC_URL=/__HELX_PUBLIC_URL__/
ENV HELX_PUBLIC_URL_SENTINEL=${PUBLIC_URL}

USER root

RUN rm -f /etc/nginx/conf.d/default.conf

# HeLx runs app containers under an arbitrary UID (TYCHO_APP_RUN_AS_USER --
# 30000:1136 on the dev and test clusters, 0:0 by default), so nothing may
# depend on the image's own user owning these paths. Both the served tree and
# conf.d are written in place at startup, hence world-writable rather than
# merely readable; setting the mode during COPY avoids duplicating the tree in
# a second layer.
COPY --chmod=0755 .helx/root /
COPY --from=builder --chmod=0777 /usr/src/app/platform/app/dist ${HELX_HTML_DIR}
# --chmod covers what COPY creates, but HELX_HTML_DIR already exists in the
# base image and keeps its own mode. sed -i needs the directory writable, not
# just the file, because it rewrites via a temp file alongside it.
RUN chmod 0777 ${HELX_HTML_DIR} /etc/nginx/conf.d

USER nginx

EXPOSE ${HELX_PORT}

ENTRYPOINT ["/start.sh"]
