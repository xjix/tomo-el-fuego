#!/bin/sh
# tomo-dev.sh(1) - dev utility scripts
# ====================================
## TODO in no particular order
# * [x] find
# * [ ] qwm
# * [ ] design architecture
# * [ ] theme ui
# * [ ] playfs
# * [x] ircfs
# * [ ] authsrv9
# * [ ] /dev/audio->jack/pipewire
# * [ ] reducer transform protocol library
# * [ ] tweetnacl
# * [ ] attrfs->systemdb
# * [ ] ttffs (how did i convert that oldschool pc font?)
# * [ ] add opendyslexic font
# * [ ] add hermit font
# * [ ] add atkinson-hyperlegible font (new default)
#
## build/release process
#
# create and enter build chroot
#
# [sudo] ./tomo-dev.sh make-chroot /opt/tomo-dev-chroot
# [sudo] ./tomo-dev.sh enter-chroot /opt/tomo-dev-chroot
#
# within chroot
#
# apt-get install -y mercurial libx11-dev libxext-dev libc6-dev gcc
# cd /opt
# hg clone https://src.xj-ix.luxe/tomo/
# cd tomo
# ./tomo-dev.sh release-Linux
#
# exit chroot, upload release artifact somewhere
#
# scp /opt/tomo-dev-chroot/opt/tomo-$syshost-$objtype.tbz2 $release_target
#
case "${1}" in
	make-chroot)
		shift
		MY_CHROOT=$1
		DEBIAN_STABLE=buster
		debootstrap --arch i386 $DEBIAN_STABLE $MY_CHROOT http://deb.debian.org/debian/
		exit 0
		;;
	enter-chroot)
		shift
		MY_CHROOT=$1
		echo "proc $MY_CHROOT/proc proc defaults 0 0" >> /etc/fstab
		mount proc $MY_CHROOT/proc -t proc
		echo "sysfs $MY_CHROOT/sys sysfs defaults 0 0" >> /etc/fstab
		mount sysfs $MY_CHROOT/sys -t sysfs
		cp /etc/hosts $MY_CHROOT/etc/hosts
		cp /proc/mounts $MY_CHROOT/etc/mtab
		exec chroot $MY_CHROOT /bin/bash
		;;
	build)
		shift
		set -e
		export iroot=$1
		export syshost=$2
		export objtype=$3
		export PATH=$iroot/$syshost/$objtype/bin:$PATH
		./makemk.sh
		mk nuke
		mk install
		;;
	rebuild)
		shift
		export iroot=$1
		export syshost=$2
		export objtype=$3
		export PATH=$iroot/$syshost/$objtype/bin:$PATH
		mk install
		;;
	rebuild-Linux)
		$0 rebuild /opt/tomo Linux 386
		;;
	build-Linux)
		$0 build /opt/tomo Linux 386
		;;
	release-Linux)
		set -e
		build_id=`hg id --id`
		iroot=/opt/tomo
		syshost=Linux
		objtype=386
		$0 build $iroot $syshost $objtype
		tar --exclude-vcs -C /opt/ -cvjf /opt/tomo-$syshost-$objtype-$build_id.tbz2 tomo
		;;
	*)
		echo "$0 [make-chroot|enter-chroot] MY_CHROOT"
		exit 1
		;;
esac

