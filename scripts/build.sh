#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. ./versions.env
if [ "$#" -eq 0 ]; then set -- amd64 arm64; fi
for target in "$@"; do
    case "$target" in amd64) platform=linux/amd64 ;; arm64) platform=linux/arm64/v8 ;; *) echo "Unknown architecture: $target" >&2; exit 1 ;; esac
    docker buildx build --pull --no-cache --provenance=false --load --platform "$platform" \
        --build-arg "GO_IMAGE=$GO_IMAGE" --build-arg "RUNTIME_IMAGE=$RUNTIME_IMAGE" \
        --build-arg "MAILHOG_VERSION=$MAILHOG_VERSION" --build-arg "MAILHOG_COMMIT=$MAILHOG_COMMIT" \
        -t "local/mailhog:$target" .
    sh scripts/check-image.sh "$target"
done
