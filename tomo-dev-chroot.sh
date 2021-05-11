#!/bin/sh
set -e
## build/release process
## create and enter build chroot
# [sudo] ./tomo-dev-chroot.sh make /opt/tomo-dev-chroot
# [sudo] ./tomo-dev-chroot.sh enter /opt/tomo-dev-chroot
## within chroot
# apt-get install -y mercurial libx11-dev libxext-dev libc6-dev gcc
# cd /opt
# hg clone https://src.xj-ix.luxe/tomo/
# cd tomo
# export objtype=386
# export syshost=Linux
# export iroot=/opt/tomo
# ./makemk.sh
# mk nuke
# mk install
# tar -C /opt/tomo -cjf /opt/tomo-$syshost-$objtype.tbz2 .
# ^D
# scp /opt/tomo-dev-chroot/opt/tomo-$syshost-$objtype.tbz2 $release_target
case "${1}" in
	make)
		shift
		MY_CHROOT=$1
		DEBIAN_STABLE=buster
		debootstrap --arch i386 $DEBIAN_STABLE $MY_CHROOT http://deb.debian.org/debian/
		exit 0
		;;
	enter)
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
	*)
		echo "$0 [make|enter] MY_CHROOT"
		exit 1
		;;
esac

