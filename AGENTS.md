# Repository instructions

Keep changes scoped to MailHog image builds and automation. Docker with Buildx is
the only host dependency. Reuse `versions.env` for version configuration.
Build and smoke-test both `linux/amd64` and `linux/arm64/v8` with
`sh scripts/build.sh` after changes to the Dockerfile or checks.
Never publish before both architecture checks pass. Publication must use the
validated images, without rebuilding. Never commit credentials or inject them
into build arguments/layers. Keep Actions credentials confined to publication.
Do not commit, push, or change remotes without explicit user instructions.
