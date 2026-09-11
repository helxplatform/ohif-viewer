# HeLx packaging for the OHIF Viewer

This directory builds the helx app image. Everything is packaged
in .helx to keep the repo easily rebaseable.

| | |
|---|---|
| Image | `containers.renci.org/helxplatform/ohif-viewer` |
| Port | 8080 |
| Entrypoint | `/start.sh` → `/helx/*.sh` → `/start-ohif.sh` → `nginx` |
| App spec | [helxplatform/helx-apps](https://github.com/helxplatform/helx-apps) → `app-specs/ohif-viewer/` |

```sh
make -C .helx build     # build the image (context is the repo root)
make -C .helx run       # run it locally under a fake HeLx prefix
make -C .helx help      # every target
```

`build` runs two stages: upstream's own `builder` stage from the repo-root
`Dockerfile` (`make builder` alone), then `.helx/Dockerfile`, which takes it as
`BUILDER_IMAGE`. `run` serves the viewer at the same shape of URL a real launch
gets; edit `docker-run.env` to change it, or empty `NB_PREFIX` to serve at `/`.

On Apple Silicon, build with `make PLATFORM=linux/arm64 build` — the published
image is amd64 and CI builds it natively, but rspack segfaults under qemu.

## The URL prefix

HeLx gives every launch a path of its own, `/private/<app>/<user>/<guid>`,
forwards it to the container, and passes it in `NB_PREFIX` (no trailing slash).
OHIF compiles `PUBLIC_URL` into the webpack bundle's `publicPath`, every
`href` in `index.html`, `pluginImports.js`. So the image is built with a sentinel
in its place and the real prefix is substituted at startup:

- **`prepare-dist.sh`** (build) lists the files whose contents carry
  `/__HELX_PUBLIC_URL__/` in `dist/.helx-substitute` and decompresses just
  those, since upstream's `compressDist.sh` has already gzipped the tree and a
  file rewritten at startup cannot be served from a `.gz` written before the
  rewrite. Only 10 of several thousand files carry it, so startup stays instant
  and nginx compresses just those ten on the fly.
- **`start-ohif.sh`** (start) rewrites those files, records what it applied in
  `dist/.helx-public-url` so a restart under a different prefix converges,
  renders the nginx config, and execs nginx.

`routerBasename` must stay `null` in any config — it falls back to
`window.PUBLIC_URL`, which the rewrite sets. Hardcoding it breaks the launch.

Two consequences worth knowing:

- nginx strips the prefix, and redirects the bare form to a trailing slash.
  React-router will not match a basename the path does not carry, and the
  readiness probe requests exactly the bare form (a 301 counts as success).
- Service workers are disabled. Scope is the path, which changes every launch,
  and upstream's loader unregisters every service worker on the origin — on
  HeLx, that means the user's other apps.

## Configuration

| Variable | Effect |
|---|---|
| `NB_PREFIX` | The URL prefix to serve at. Set by HeLx; defaults to `/`. |
| `PUBLIC_URL` | Overrides `NB_PREFIX`. Mainly for running outside HeLx. |
| `APP_CONFIG` | The JavaScript for `app-config.js` itself. At *build* time the same name instead selects one of `platform/app/public/config/*.js`. |
| `APP_CONFIG_FILE` | Path to a mounted file to use as `app-config.js`. |
| `HELX_PORT` | Port to listen on. Defaults to 8080; also a build arg. |
| `FINAL_COMMAND` | What `/start.sh` hands off to. Defaults to `/start-ohif.sh`. |

The image bakes in `config/default.js`, whose data source is OHIF's public demo
server. Additional startup work goes in `root/helx/` as `NN-name.sh`.
