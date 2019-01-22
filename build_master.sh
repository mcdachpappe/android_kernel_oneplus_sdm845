#!/bin/bash

if [[ "${1}" != "skip" ]] ; then
	./build_clean.sh
	./build_kernel.sh stock "$@" || exit 1
fi

VERSION="$(cat version)-$(date +%F | sed s@-@@g)"

if [ -e boot.img ] ; then
	rm arter97-kernel-$VERSION.zip 2>/dev/null
	cp boot.img kernelzip/boot.img
	cp boot.img arter97-kernel-$VERSION.img
	cd kernelzip/
	7z a -mx0 arter97-kernel-$VERSION-tmp.zip *
	zipalign -v 4 arter97-kernel-$VERSION-tmp.zip ../arter97-kernel-$VERSION.zip
	rm arter97-kernel-$VERSION-tmp.zip
	cd ..
	ls -al arter97-kernel-$VERSION.zip
	rm kernelzip/boot.img
fi
