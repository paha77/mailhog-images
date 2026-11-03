#!/bin/sh
set -eu
arch=${1:?Usage: check-image.sh amd64|arm64}
case "$arch" in amd64) platform=linux/amd64 ;; arm64) platform=linux/arm64/v8 ;; *) exit 1 ;; esac
image="local/mailhog:$arch"
test "$(docker image inspect --format '{{.Architecture}}' "$image")" = "$arch"
test "$(docker run --rm --platform "$platform" --entrypoint id "$image" -u)" = 1000
name="mailhog-check-$arch-$$"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
docker run -d --platform "$platform" --name "$name" "$image" >/dev/null
# Use the image's own shell/tools so Docker is the only host dependency.
docker exec "$name" sh -ec '
    i=0
    until wget -qO /tmp/messages http://127.0.0.1:8025/api/v2/messages; do
        i=$((i+1)); test "$i" -lt 30; sleep 1
    done
    wget -qO /tmp/ui http://127.0.0.1:8025/
    grep -qi mailhog /tmp/ui
    printf "EHLO localhost\r\nMAIL FROM:<sender@example.test>\r\nRCPT TO:<recipient@example.test>\r\nDATA\r\nSubject: mailhog-smoke-test\r\n\r\nHello from the image check.\r\n.\r\nQUIT\r\n" | nc -w 5 127.0.0.1 1025 > /tmp/smtp
    grep -q "250 Ok" /tmp/smtp
    wget -qO /tmp/messages http://127.0.0.1:8025/api/v2/messages
    grep -q mailhog-smoke-test /tmp/messages
    grep -q "\"total\":1" /tmp/messages
'
echo "Passed MailHog UI, SMTP, API and non-root checks ($arch)."
