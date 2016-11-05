BUCKET=rkt.luzifer.io

GOLANG_VERSION=1.7.3
GOLANG_HASH=79430a0027a09b0b3ad57e214c4c1acfdd7af290961dd08d322818895af1ef44

default: index pubkeys

index:
	aws s3 cp --acl=public-read index.html s3://$(BUCKET)/index.html

pubkeys:
	gpg2 --export -a rkt@luzifer.io > pubkeys.gpg
	aws s3 cp --acl=public-read pubkeys.gpg s3://$(BUCKET)/pubkeys.gpg

images: debian-jessie alpine-v3.4

golang:
	$(MAKE) clean
	mkdir -p build
	korvike -v version=$(GOLANG_VERSION) -v hash=$(GOLANG_HASH) < images/golang.acb > build/golang.acb
	korvike -v version=$(GOLANG_VERSION) -v hash=$(GOLANG_HASH) < images/golang.sh > build/golang.sh
	chmod +x build/golang.sh
	sudo acbuild script build/golang.acb
	$(MAKE) sign-golang-$(GOLANG_VERSION) push-golang-$(GOLANG_VERSION)
 
debian-%:
	$(MAKE) clean
	korvike -v version="$*" < images/debian.json > manifest
	sudo debootstrap --verbose --variant=minbase --include=iproute,iputils-ping --arch=amd64 $* rootfs
	sudo rm -rf rootfs/var/cache/*
	sudo tar -czf debian-$*.aci manifest rootfs
	$(MAKE) sign-debian-$* push-debian-$*

alpine-%:
	$(MAKE) clean
	korvike -v version="$*" < images/alpine.json > manifest
	sudo rkt run --dns=8.8.8.8 \
		--volume data,kind=host,source=$(CURDIR) --mount volume=data,target=/data \
		quay.io/coreos/alpine-sh --exec=/bin/sh -- \
		-c 'apk add --update bash tzdata && /data/images/alpine.sh -r $*'
	sudo tar -czf alpine-$*.aci manifest rootfs
	$(MAKE) sign-alpine-$* push-alpine-$*

sign-%:
	rm -f $*.aci.asc
	gpg2 -u rkt@luzifer.io -o $*.aci.asc --detach-sign $*.aci

push-%:
	aws s3 cp --acl=public-read $*.aci s3://$(BUCKET)/linux/amd64/$(BUCKET)/
	aws s3 cp --acl=public-read $*.aci.asc s3://$(BUCKET)/linux/amd64/$(BUCKET)/

clean:
	sudo rm -rf rootfs *.asc *.aci manifest pubkeys.gpg build

.PHONY: clean
