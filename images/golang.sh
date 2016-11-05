#!/bin/sh

set -ex

apk add --no-cache ca-certificates

GOPATH=/go
GOLANG_VERSION={{ .version }}
GOLANG_SRC_URL=https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz
GOLANG_SRC_SHA256={{ .hash }}

apk add --no-cache --virtual .build-deps \
	bash \
	gcc \
	musl-dev \
	openssl \
	go \
  curl

export GOROOT_BOOTSTRAP="$(go env GOROOT)"

curl -sL -o golang.tar.gz "$GOLANG_SRC_URL"
echo "$GOLANG_SRC_SHA256  golang.tar.gz" | sha256sum -c -
tar -C /usr/local -xzf golang.tar.gz
rm golang.tar.gz
cd /usr/local/go/src
./make.bash

apk del .build-deps

mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
