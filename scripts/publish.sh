#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
MAILHOG_VERSION=$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' local/mailhog:amd64)
MAILHOG_COMMIT=$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' local/mailhog:amd64)
: "${MAILHOG_VERSION:?}" "${MAILHOG_COMMIT:?}"
image="${DOCKERHUB_NAMESPACE:-paha77}/${DOCKERHUB_IMAGE:-mailhog-arm64v8}"
: "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_RUN_ATTEMPT:?}"
release="v${MAILHOG_VERSION}-${GITHUB_SHA}-run${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}"
for arch in amd64 arm64; do
    test "$(docker image inspect --format '{{.Architecture}}' "local/mailhog:$arch")" = "$arch"
    test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "local/mailhog:$arch")" = "$MAILHOG_VERSION"
    test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "local/mailhog:$arch")" = "$MAILHOG_COMMIT"
done
for arch in amd64 arm64; do
    docker tag "local/mailhog:$arch" "$image:$release-$arch"
    docker push "$image:$release-$arch"
done
docker manifest create "$image:$release" "$image:$release-amd64" "$image:$release-arm64"
docker manifest annotate "$image:$release" "$image:$release-arm64" --os linux --arch arm64 --variant v8
docker manifest push "$image:$release"
# Validate the release before promoting either compatibility alias.
docker buildx imagetools inspect "$image:$release" --raw | docker run --rm -i ghcr.io/jqlang/jq:1.8.1 -e '
    [.manifests[].platform | .os + "/" + .architecture] | sort == ["linux/amd64", "linux/arm64"]'
for alias in "v$MAILHOG_VERSION" latest; do
    docker buildx imagetools create -t "$image:$alias" "$image:$release"
done
