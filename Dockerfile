# syntax=docker/dockerfile:1
ARG GO_IMAGE=golang:1-alpine
ARG RUNTIME_IMAGE=alpine:3
FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS builder
ARG MAILHOG_COMMIT=0441dd494b03c9255a9b8e90e3458ebb115eacff
ARG TARGETOS
ARG TARGETARCH
WORKDIR /go/src/github.com/mailhog/MailHog
ADD https://codeload.github.com/mailhog/MailHog/tar.gz/${MAILHOG_COMMIT} /tmp/mailhog.tar.gz
RUN tar -xzf /tmp/mailhog.tar.gz --strip-components=1
RUN CGO_ENABLED=0 GO111MODULE=off GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -o /out/MailHog .

FROM ${RUNTIME_IMAGE}
ARG MAILHOG_VERSION=1.0.1
LABEL org.opencontainers.image.title="MailHog" \
      org.opencontainers.image.version="${MAILHOG_VERSION}" \
      org.opencontainers.image.licenses="MIT"
RUN apk add --no-cache ca-certificates \
    && adduser -D -u 1000 mailhog
COPY --from=builder /out/MailHog /usr/local/bin/MailHog
COPY --from=builder /go/src/github.com/mailhog/MailHog/LICENSE.md /usr/share/licenses/mailhog/LICENSE.md
USER mailhog
WORKDIR /home/mailhog
EXPOSE 1025 8025
ENTRYPOINT ["MailHog"]
