#!/usr/bin/env bash
SOURCE=/mnt/debootstrap
TARGET=/mnt/target
TARGET_DRIVE=
#TARGET_DRIVE=/dev/sdb
TARGET_EFI_PART=/dev/sdb1
TARGET_ROOT_PART=/dev/sdb2
NO_SWAP="no-swap"

if [ -z $TARGET_DRIVE ]
then
echo "Bitte dieses Script zuerst konfigurieren und als root starten." >&2
exit 1
fi

if [[ $UID -ne 0 ]]
then
	echo "Dieses Script muss als root gestartet werden." >&2
	exit 1
fi

umount_all () {
echo "Zieldateisystem aushängen"
umount $TARGET/proc $TARGET/sys $TARGET/dev/pts $TARGET/dev $TARGET/boot/efi $TARGET
sudo ./build-ubuntu-noble-image.sh -U
}

# Vorbereitete Image-Datei einhängen und eingehängt lassen ohne weitere Aktionen
sudo ./build-ubuntu-noble-image.sh -S -D -M

if [ ! -d $SOURCE/usr ]
then
 echo "$SOURCE ist wahrscheinlich nicht eingehängt. Abbruch"
 exit 1
fi

create_partitions () {
EFI_SIZE=270
PARTED_COMMANDS="mklabel gpt \
mkpart primary fat32 1MiB $(( 1 + EFI_SIZE ))MiB \
name 1 uefi \
set 1 esp on"
ROOT_PART=2
ROOT_START="$(( 1 + EFI_SIZE ))MiB"
PARTED_COMMANDS="$PARTED_COMMANDS \
mkpart primary+ext4 $ROOT_START -0 \
name $ROOT_PART root"
unset ROOT_START
parted -s -a optimal -- $TARGET_DRIVE $PARTED_COMMANDS
unset PARTED_COMMANDS
echo "Partitioniertes Laufwerk:"
parted -s $TARGET_DRIVE print
echo ${TARGET_DRIVE}${ROOT_PART}

echo "Formatiere:"
echo "...EFI partition"
mkfs -t fat -F 32 -n EFI ${TARGET_DRIVE}1
echo "...root"
mkfs -t ext4 -L root ${TARGET_ROOT_PART}
unset ROOT_PART
}
create_partitions

if [ ! -d $TARGET ]
then
 mkdir $TARGET
fi

echo "Dateisysteme einhängen"
mount $TARGET_ROOT_PART $TARGET

if [ ! -d $TARGET/boot/efi ]
then
 mkdir -p $TARGET/boot/efi
fi
mount $TARGET_EFI_PART $TARGET/boot/efi

echo "Kopiere Dateien"
sudo rsync -aAXv $SOURCE/ \
--exclude={dev/*,proc/*,sys/*,tmp/*,run/*,mnt/*,media/*,cdrom/*,lost+found} \
 $TARGET/
sync

ROOT_UUID="$(blkid | grep "^${TARGET_ROOT_PART}:" | grep ' LABEL="root" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //')"
[[ -z $NO_SWAP ]] && SWAP_UUID="$(blkid | grep "^${TARGET_ROOT_PART}:" | grep ' LABEL="swap" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //' )"
EFI_UUID="$(blkid | grep "^${TARGET_EFI_PART}:" | grep ' LABEL="EFI" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //' )"

echo "Root: $ROOT_UUID"
echo "EFI: $EFI_UUID"

echo "Configuring fstab"
cat > $TARGET/etc/fstab <<S2EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
$ROOT_UUID / ext4 errors=remount-ro 0 1
$EFI_UUID /boot/efi vfat defaults 0 1
S2EOF

echo "Update Grub"
cat > $TARGET/root/update_grub.bash <<EOF
#!/bin/bash
mount -t efivarfs none /sys/firmware/efi/efivars  
grub-install --target=x86_64-efi
update-grub
umount /sys/firmware/efi/efivars
EOF
echo "Mounting proc, dev and sys"
mount -o bind,ro /dev $TARGET/dev
mount -o bind /dev/pts $TARGET/dev/pts
mount -t sysfs /sys $TARGET/sys
mount -t proc /proc $TARGET/proc

LANG=C.UTF-8 chroot $TARGET/ /bin/bash /root/update_grub.bash

#rm $TARGET/root/update_grub.bash
umount_all
echo "Erledigt"

