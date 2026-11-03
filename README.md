# Multi-platform MailHog image

Builds `paha77/mailhog-arm64v8` for **linux/amd64** (Intel/AMD) and
**linux/arm64/v8** (including Apple Silicon). The existing Docker Hub name is
retained; Docker selects the appropriate architecture automatically.

Based on the [existing image](https://hub.docker.com/r/paha77/mailhog-arm64v8)
and the build/validate/publish pattern in
[php-docker-images](https://github.com/paha77/php-docker-images).
Each build resolves the latest stable MailHog release from GitHub and builds
its exact commit with its vendored dependencies. Drafts and prereleases are
excluded; resolution errors stop the build. `versions.env` owns the release API
and base image configuration.
Go and Alpine follow their current stable tags; fresh builds pull bases without
cache. This refreshes the toolchain/OS, but does not update MailHog's vendored
dependencies. Review those separately when maintaining the image.

## Run

```sh
docker run --rm --name mailhog \
  -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 \
  paha77/mailhog-arm64v8:latest
```

Open <http://localhost:8025>; send SMTP to `localhost:1025` without TLS or
authentication. Mail is captured in memory by default. The image runs as
`mailhog` (UID 1000) in `/home/mailhog` and retains the `MailHog` entrypoint.
Pass MailHog flags after the image name or configure its `MH_*` environment
variables. See [upstream configuration](https://github.com/mailhog/MailHog/blob/v1.0.1/docs/CONFIG.md).

## Build and check locally

Docker with Buildx and a running daemon is the only host dependency; scripts use
the standard shell. Docker Desktop includes cross-platform emulation. Linux
hosts need binfmt/QEMU for the other architecture (CI installs it automatically).

```sh
sh scripts/build.sh             # build and test both architectures
sh scripts/build.sh amd64       # Intel/AMD only
sh scripts/build.sh arm64       # ARM only
```

For a fully containerized invocation (also avoids host shell/tool differences):

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD:/work" -w /work docker:cli sh scripts/build.sh
```

Images load as `local/mailhog:amd64` and `local/mailhog:arm64`.
Both architectures use the same resolved release and commit, recorded in image
labels. Use `scripts/build.sh` to resolve the release before building; the
Dockerfile requires explicit source arguments and has no pinned fallback.
Each check executes the target image, verifies its architecture and non-root
user, loads the UI, sends a message through SMTP and retrieves it via the API.
The temporary check container is removed on exit. Source is downloaded inside
Docker; no host Go, Git, Python, jq or compiler is required for builds.

## GitHub automation

`.github/workflows/images.yml` resolves the release once, then builds and tests both architectures separately on
pull requests and pushes. Default-branch pushes, Monday 05:23 UTC schedules and
manual default-branch runs publish only after both checks pass. Other branches
and pull requests never receive registry credentials or publish images.

Like the PHP image workflow, CI transfers the exact validated images through
one-day Actions artifacts; publication loads them without rebuilding. Rerun the
whole workflow if artifacts expire. Publishing runs serialize. Actions are
pinned to the same full commit SHAs as the reference workflow.

Published tags:

- `v<mailhog-version>-<source-sha>-run<run-id>.<attempt>`: unique multi-platform release.
- The release tag plus `-amd64` or `-arm64`: architecture images.
- `v<mailhog-version>` and `latest`: aliases promoted after the release manifest passes checks.

The run identity distinguishes scheduled refreshes at the same source commit.
Publication reads the version and commit from the validated images and rejects
architecture images with differing releases; it does not resolve or rebuild.
Configure Docker Hub immutability for release tags if available. Alias updates
are separate registry operations; a failure can leave them at different releases.
Pin a validated release tag or digest for reproducibility.

### Initial setup

The repository uses branch `main` and the **SSH** remote:

```sh
git@github.com:paha77/paha77-mailhog-images.git
```

In that repository, configure Actions secrets:

| Secret | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Docker Hub login with write access to the image repository |
| `DOCKERHUB_TOKEN` | Docker Hub access token with read/write access, without delete |

Optional Actions variables `DOCKERHUB_NAMESPACE` and `DOCKERHUB_IMAGE` default to
`paha77` and `mailhog-arm64v8`. Ensure that Docker Hub repository exists.
Enable GitHub Actions, review the files, commit and push when ready. The first
default-branch push publishes automatically once secrets are configured.
Secrets from another GitHub repository are not inherited; organization secrets
must explicitly allow this repository. Never put token values in source files,
build arguments or command arguments.

This checkout does not configure secrets or publish an image locally.
After pushing, inspect the Actions result and published manifest:

```sh
docker buildx imagetools inspect paha77/mailhog-arm64v8:latest
```

Expect `linux/amd64` and `linux/arm64/v8`.

## Validation status

Both architectures were built locally and passed the UI, SMTP, API, architecture
and UID checks. Containerized Actionlint 1.7.7 and shell syntax checks passed.
GitHub execution and registry publication have not yet been verified; registry
credentials must be configured separately in GitHub Actions.
