#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. ./versions.env
# Resolve without host tools or credentials. Fail closed on API/network errors.
docker run --rm -e "MAILHOG_RELEASE_API=$MAILHOG_RELEASE_API" "$RUNTIME_IMAGE" sh -ec '
    apk add --no-cache curl jq >/dev/null
    tag=$(curl -fsSL "$MAILHOG_RELEASE_API" | jq -er '\''select(.draft == false and .prerelease == false) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))'\'')
    commit=$(curl -fsSL "https://api.github.com/repos/mailhog/MailHog/commits/$tag" | jq -er '\''.sha | select(test("^[0-9a-f]{40}$"))'\'')
    printf "MAILHOG_VERSION=%s\nMAILHOG_COMMIT=%s\n" "${tag#v}" "$commit"
'
