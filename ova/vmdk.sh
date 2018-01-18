#! /bin/bash

set -e

# constants
CURRENT_DIR=$(dirname $0)
SETUP_SCRIPT="chroot-setup.sh"

# CL args
REPOSITORY=$1
DISTRIBUTION=$2
ARCH=$3
ORIGINAL_VMDK=$4
VMDK=$5
FLAVOR=$6
shift 6
EXTRA_PACKAGES=$@

## main
QCOW2=${VMDK/.vmdk/.qcow2}
BASE_TMP_DIR="/tmp/tmp.vmdk-chroot-${FLAVOR}-${DISTRIBUTION}"
CHROOT_DIR=$(mktemp -d ${BASE_TMP_DIR}.XXXXX)
TMP_VMDK="/tmp/${FLAVOR}.vmdk"

# clean up if something went wrong during previous run, but make
# sure we do it in the right order, or we'll mess up the host system
# since those were bind mounts
if mount | grep -q ${BASE_TMP_DIR} ; then
  for dir in ${BASE_TMP_DIR}.* ; do
    for pfs in sys proc dev/pts dev ; do
      umount ${dir}/$pfs || true
    done
  done
fi

# NBD support
rmmod nbd || true
modprobe nbd max_part=32

case $FLAVOR in
  adtran) NUM=3 ;;
  apc) NUM=6 ;;
  untangle) NUM=9 ;;
  *) NUM=0 ;;
esac
while [[ -e /var/lock/qemu-nbd-nbd${NUM} ]] ; do
  NUM=$(( NUM + 1 ))
done
NBD_DEV="/dev/nbd${NUM}"

# convert to qcow2
qemu-img convert -O qcow2 ${ORIGINAL_VMDK} ${QCOW2}

# attach and mount
qemu-nbd -d ${NBD_DEV} || true
qemu-nbd -c ${NBD_DEV} ${QCOW2}
sleep 3
mount ${NBD_DEV}p1 ${CHROOT_DIR}

# mount required PFS
for pfs in dev dev/pts proc sys ; do
  mount --bind /$pfs ${CHROOT_DIR}/$pfs
done

# setup Untangle in chroot
cp ${CURRENT_DIR}/${SETUP_SCRIPT} ${CHROOT_DIR}/tmp/
extraPackagesFile=${CURRENT_DIR}/extra-packages.txt
if [ -f $extraPackagesFile ] ; then
  cp $extraPackagesFile ${CHROOT_DIR}/tmp/
fi
chroot ${CHROOT_DIR} /tmp/${SETUP_SCRIPT} ${REPOSITORY} ${DISTRIBUTION} ${ARCH} ${NBD_DEV} ${EXTRA_PACKAGES}

# umount PFS
for pfs in sys proc dev/pts dev ; do
  umount -l ${CHROOT_DIR}/$pfs || true
done

# free ressources, and cleanup
umount ${CHROOT_DIR}
qemu-nbd -d ${NBD_DEV}
rm -fr ${CHROOT_DIR}

# convert back to an ESX-compatible VMDK
qemu-img convert -O vmdk -o subformat=streamOptimized ${QCOW2} ${TMP_VMDK}
rm -f ${VMDK}
vboxmanage clonehd ${TMP_VMDK} ${VMDK} --format VMDK --variant Stream
