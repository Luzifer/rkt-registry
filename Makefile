BUCKET=rkt.luzifer.io
DATE:=$(shell date +%Y%m%d)

default: index pubkeys

index:
	aws s3 cp --acl=public-read index.html s3://$(BUCKET)/index.html

pubkeys:
	gpg2 --export -a rkt@luzifer.io > pubkeys.gpg
	aws s3 cp --acl=public-read pubkeys.gpg s3://$(BUCKET)/pubkeys.gpg

images: debian-jessie alpine-v3.4

debian-%:
	korvike -v date=$(DATE) -v version="$*" < images/debian.json > manifest
	sudo debootstrap --verbose --variant=minbase --include=iproute,iputils-ping --arch=amd64 $* rootfs
	sudo rm -rf rootfs/var/cache/*
	sudo tar -czf debian-$*-$(DATE).aci manifest rootfs
	$(MAKE) sign-debian-$*-$(DATE).aci
	aws s3 cp --acl=public-read debian-$*-$(DATE).aci s3://$(BUCKET)/linux/amd64/$(BUCKET)/
	aws s3 cp --acl=public-read debian-$*-$(DATE).aci.asc s3://$(BUCKET)/linux/amd64/$(BUCKET)/

alpine-%:
	korvike -v date=$(DATE) -v version="$*" < images/alpine.json > manifest
	sudo rkt run --dns=8.8.8.8 \
		--volume data,kind=host,source=$(CURDIR) --mount volume=data,target=/data \
		quay.io/coreos/alpine-sh --exec=/bin/sh -- \
		-c 'apk add --update bash tzdata && /data/images/alpine.sh -r $*'
	sudo tar -czf alpine-$*-$(DATE).aci manifest rootfs
	$(MAKE) sign-alpine-$*-$(DATE).aci
	aws s3 cp --acl=public-read alpine-$*-$(DATE).aci s3://$(BUCKET)/linux/amd64/$(BUCKET)/
	aws s3 cp --acl=public-read alpine-$*-$(DATE).aci.asc s3://$(BUCKET)/linux/amd64/$(BUCKET)/

sign-%:
	rm -f $*.asc
	gpg2 -u rkt@luzifer.io -o $*.asc --detach-sign $*

clean:
	sudo rm -rf rootfs *.asc *.aci manifest pubkeys.gpg
