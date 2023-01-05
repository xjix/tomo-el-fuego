#!/bin/sh
# tomo-dev.sh(1) - dev utility scripts
# ====================================
#
## dev process
#
# ```
# [sudo] ./tomo-dev.sh make-chroot /opt/tomo-dev-chroot
# [sudo] ./tomo-dev.sh bind-chroot /opt/tomo-dev-chroot
# [sudo] ./tomo-dev.sh bind-checkout /opt/tomo
# [sudo] ./tomo-dev.sh rebuild-chroot /opt/tomo-dev-chroot
# ```
#
## build/release process
#
# from an existing checkout, create and enter build chroot
#
# ```
# [sudo] ./tomo-dev.sh make-chroot /opt/tomo-dev-chroot
# [sudo] ./tomo-dev.sh bind-chroot /opt/tomo-dev-chroot
# [sudo] ./tomo-dev.sh enter-chroot /opt/tomo-dev-chroot
# ```
#
# within chroot
#
# ```
# cd /opt/tomo
# ./tomo-dev.sh setup-chroot
# ./tomo-dev.sh release-Linux
# ```
#
# exit chroot, upload release artifact somewhere
#
# scp /opt/tomo-dev-chroot/opt/tomo-$syshost-$objtype.tbz2 $release_target
#
## multilib notes
#
# see ci file.
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
		#echo "proc $MY_CHROOT/proc proc defaults 0 0" >> /etc/fstab
		mount proc $MY_CHROOT/proc -t proc
		#echo "sysfs $MY_CHROOT/sys sysfs defaults 0 0" >> /etc/fstab
		mount sysfs $MY_CHROOT/sys -t sysfs
		cp /etc/hosts $MY_CHROOT/etc/hosts
		cp /proc/mounts $MY_CHROOT/etc/mtab
		exec chroot $MY_CHROOT /bin/bash
		;;
	bind-chroot)
		shift
		MY_CHROOT=$1
		mount --bind `pwd` $MY_CHROOT/opt/tomo
		;;
	bind-checkout)
		shift
		mount --bind `pwd` ${1:-"/opt/tomo"}
		;;
	setup-ci)
		dpkg --add-architecture i386
		apt update >/dev/null
		apt install -yy \
			curl:i386 \
			binutils:i386 \
			gcc:i386 \
			libc6-dev-i386 \
			libx11-dev:i386 \
			libxext-dev:i386 \
			zip:i386 \
			>/dev/null
		;;
	setup-chroot)
		shift
		apt-get update
		apt-get install -y \
			gcc \
			libc6-dev \
			libx11-dev \
			libxext-dev \
			fossil
		;;
	build)
		shift
		set -e
		export iroot=$1
		export syshost=$2
		export objtype=$3
		export PATH=$iroot/$syshost/$objtype/bin:$PATH
		./makemk.sh
		mk mkdirs
		mk nuke
		mk install
		;;
	nuke)
		shift
		set -e
		export iroot=$1
		export syshost=$2
		export objtype=$3
		export PATH=$iroot/$syshost/$objtype/bin:$PATH
		mk nuke
		;;
	rebuild)
		shift
		export iroot=$1
		export syshost=$2
		export objtype=$3
		export PATH=$iroot/$syshost/$objtype/bin:$PATH
		mk install
		;;
	nuke-Linux)
		shift
		$0 nuke ${1:-"/opt/tomo"} Linux 386
		;;
	rebuild-Linux)
		shift
		$0 rebuild ${1:-"/opt/tomo"} Linux 386
		;;
	build-Linux)
		shift
		$0 build ${1:-"/opt/tomo"} Linux 386
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
	upload-ci)
		shift
		# since we host on fossil, the release-upload script can be hosted using
		# the ext feature so access can be managed in the usual way!
		# https://fossil-scm.org/home/doc/trunk/www/serverext.wiki
		artifact="$1"
		artifact_path=`realpath $artifact`
		set -xe
		zip -r "$artifact" *
		curl -Ssf -m 360 \
			-X POST \
			--data-binary "@$artifact_path" \
			"https://$HP_CI_UPLOAD_KEY@$HP_CI_UPLOAD_ENDPOINT?n=$artifact"
		;;
	*)
		echo "$0 [make-chroot|enter-chroot] MY_CHROOT"
		echo TODO: print useful help
		exit 1
		;;
esac

