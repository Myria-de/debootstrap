#!/usr/bin/env bash

# Copyright 2020 Laurence Alexander Hurst
# https://github.com/loz-hurst/build-debian-qemu-image
# German localization by Thorsten Eggeling (partially)
#
# This file is part of build-debian-qemu-image.
#
#    build-debian-qemu-image is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    build-debian-qemu-image is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with build-debian-qemu-image.  If not, see <https://www.gnu.org/licenses/>.
#
# See the file LICENCE in the original source code repository for the
# full licence.

if [[ $UID -ne 0 ]]
then
	echo "Dieses Script mit sudo als root starten." >&2
	exit 1
fi
THE_USER=$SUDO_USER
###################################
###### Konfiguration Anfang #######
###################################

WORKDIR=`pwd`
VMDIR=$WORKDIR/VMs
# Ubuntu Codename
DEFAULT_SUITE="noble"
DEFAULT_DOMAIN="$( hostname -d )"
# In MiB.  How large should swap be? First 271MiB is used for system (boot)
# partitions and reserved space, so 753 takes us to the 1024MiB (1GiB)
# position on the disk (1(reserved) + 270(efi) + 753(swap) = 1024MiB = 1GiB)
# In MiB. Wie groß sollte der Swap sein? Die ersten 271 MiB werden für Systempartitionen (Boot) 
# und reservierten Speicherplatz verwendet, 
# daher bringt uns 753 zur 1024 MiB (1 GiB) großen Position auf der Festplatte (1 (reserviert) + 270 (efi) + 753 (Swap) = 1024 MiB = 1 GiB).

DEFAULT_SWAP=753
# Kann in jedem von qemu-img erkannten Format vorliegen – beachten Sie, dass die Größen (K, M, G, T) in KiB und nicht in KB angegeben sind.
# An be in any format recognised by qemu-img - note sizes (K, M, G, T) are KiB not KB.
DEFAULT_SIZE="10G"
# Das erste Konto, Benutzernamen und Passwort
# First account
USERNAME="user"
PASSWORD="Geheim"
#packages
DESKTOP="cinnamon-desktop-environment"
# Zusätzliche Pakete
# Extra packages
EXTRA="base-files lightdm gnome-terminal openssh-server mc hunspell-de-at-frami hunspell-de-ch-frami hunspell-de-de-frami hyphen-de language-pack-de language-pack-gnome-de libreoffice libreoffice-help-de libreoffice-l10n-de mythes-de mythes-de-ch thunderbird-locale-de wngerman wogerman wswiss mintlocale command-not-found firefox firefox-locale-de synaptic xapp-appimage-thumbnailer xapp-epub-thumbnailer xapp-jxl-thumbnailer xapp-mp3-thumbnailer xapp-ora-thumbnailer xapp-raw-thumbnailer xapp-thumbnailers-common pix timeshift xed mint-l-icons mint-cursor-themes mint-info-cinnamon mint-artwork mint-backgrounds-vanessa mint-backgrounds-vera mint-backgrounds-victoria mint-backgrounds-virginia mint-common mint-cursor-themes mint-themes mint-translations mint-x-icons mint-y-icons mintbackup mintdrivers mintstick"

#apt Cache aktivieren
# USE_APT_CACHER="yes"
# oder ohne Cache
USE_APT_CACHER=
#################################
###### Konfiguration Ende #######
#################################

unmount_all () {
if [[ -z $SKIP_UNMOUNT ]]
then
	echo "Hänge chroot aus"
	sudo umount /mnt/debootstrap/proc /mnt/debootstrap/sys /mnt/debootstrap/dev/pts /mnt/debootstrap/dev /mnt/debootstrap/boot/efi /mnt/debootstrap

	echo "Trenne Verbindung zu $NBD_DEV"
	sync
	sudo qemu-nbd -d $NBD_DEV
else
	echo "WARNUNG: Unmount übersprungen (wie angefordert)" >&2
	echo "Mehrere Dateisysteme sind unter /mnt eingehängt. Vergessen Sie nicht, diese später auszuhängen."
	echo "NBD is noch verbunden , trennen Sie die Verbindung später (NACH dem Aushängen!) mit: qemu-nbd -d $NBD_DEV"
fi
}

usage() {
	cat - <<EOF
Usage: $0 [-hSDMU] [-s suite] [-f file] [-z size] [-r passwd] [name]

-h:        Diese Meldung anzeigen und beenden
-S:        Überspringen Sie die Initialisierung eines leeren Images durch
           Debootstrap und fahren Sie direkt mit dem Mounten fort.
           Erfordert eine bereits eingerichtete Image-Datei als Ziel.
-D:        Führen Sie nur Debootstrap aus und beenden Sie das Programm
           ohne Chrooting und ohne den zweiten Schritt. Da Debootstrap
           das zeitaufwändigste Element ist, kann dies in Kombination
           mit -S während des Debuggens und der Entwicklung hilfreich sein.
           Das zweite Skript wird trotzdem geschrieben.
-M:        Lassen Sie das NBD angeschlossen und die
           Chroot-Dateisysteme am Ende gemountet.
-U:        Hängen Sie alle gemounteten Dateisysteme aus
-s suite:  Die zu erstellende Debian/Ubuntu-Suite ist standardmäßig $DEFAULT_SUITE
           (entnommen aus der ersten Zeile, die mit /^deb/ in /etc/apt/sources.list
           übereinstimmt).
-f file:   Dateiname für das Bild, standardmäßig <name>.qcow2
-z size:   Größe des Images in einem vom Befehl qemu-img verstandenen
           Format. Standardmäßig $DEFAULT_SIZE, das erste 1 GB wird
           vollständig durch boot- und Swap-Partitionen verbraucht.
-w size:   Größe der Swap-Partition des Images in MiB
           (zum Deaktivieren auf 0 setzen), standardmäßig ${DEFAULT_SWAP}
-r var:    Verwenden Sie passwd in der Umgebungsvariablen var 
           als verschlüsseltes Root-Passwort im erstellten Image
           (um zu verhindern, dass das Passwort über die Befehlszeile
           angezeigt wird und jeder Benutzer im System sehen kann).
-d domain: Domäne als neue Hostdomäne verwenden, standardmäßig
           $DEFAULT_DOMAIN (übernommen aus dem Hostnamen -d dieses Hosts).
name:      Hostname, für den das Image konfiguriert werden soll,
           standardmäßig debian-<suite>
EOF
}

while getopts ":hSDMUs:f:z:r:d:" opt;
do
	case $opt in
		h )
			usage
			exit 0
			;;
		\? )
			usage
			exit 0
			;;
		s )
			SUITE="$OPTARG"
			;;
		f )
			FILE="$OPTARG"
			;;
		z )
			SIZE="$OPTARG"
			;;
		r )
			ROOT_PASSWD="$( eval "echo \${$OPTARG}" )"
			;;
		d )
			DOMAIN_NAME="$OPTARG"
			;;
		S )
			SKIP_DEBOOTSTRAP="skip"
			;;
		D )
			SKIP_STAGE2="skip"
			;;
		M )
			SKIP_UNMOUNT="skip"
			;;
		U )
			UNMOUNT_ALL="yes"
			;;
		: )
			echo "Error: option $OPTARG missing an argument" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND - 1))

NAME="$1"

# Legen Sie Standardwerte für alles fest, was sonst nicht festgelegt ist
# Set defaults for anything not set
[[ -z $SUITE ]] && SUITE="$DEFAULT_SUITE"
[[ -z $NAME ]] && NAME="linux-mint-$SUITE"
[[ -z $FILE ]] && FILE="$NAME.qcow2"
[[ -z $SIZE ]] && SIZE="$DEFAULT_SIZE"
[[ -z $DOMAIN_NAME ]] && DOMAIN_NAME="$DEFAULT_DOMAIN"
[[ -z $SWAP_SIZE ]] && SWAP_SIZE="$DEFAULT_SWAP"
[[ -z $ROOT_PASSWD ]] && echo "Kein Root-Passwort angegeben. Im Image wird keins festgelegt."
VMNAME=$NAME

if [ ! -d $VMDIR/$VMNAME ]
then
echo -e "- ${GREEN}Erstelle Verzeichnis $VMDIR/$VMNAME ${NC}"
mkdir -p $VMDIR/$VMNAME
fi
FILE="$VMDIR/$VMNAME/$FILE"

if ! [[ -z "$SKIP_DEBOOTSTRAP" || -z "$UNMOUNT_ALL" ]]
then
 if [ -e $FILE ]
 then
  echo "Datei $FILE ist bereits vorhanden. Bitte löschen. Abbruch."
  exit 1
 fi
fi

# Weitere Variablen, die möglicherweise geändert werden müssen, oder vom Benutzer bereitgestellte Optionen in der Zukunft
# Other variables that might need to be changed or user-provided options in
# the future
# NBD-Gerät zum Verbinden des Image
# NBD device for connecting image
NBD_DEV=/dev/nbd0 
# Wie groß sollte die EFI-Systempartition in MiB sein? Laut Archs Wiki sollte die Partition mindestens 260 MiB groß sein.
# In MiB, how large should be EFI system partition be. According to Arch's
# wiki "the partition should be at least 260 MiB":
# https://wiki.archlinux.org/index.php/EFI_system_partition
EFI_SIZE=270

if ! [[ -z $UNMOUNT_ALL ]]
then
unmount_all
exit 0
fi

echo "Erstelle ein Image mit der Größe $SIZE, mit Hostnamen $NAME,"
echo "  in $FILE von Suite $SUITE"
# Von nun an bei Fehler abbrechen
# From now on, abort on error
set -e
# Image erstellen, sofern kein vorhandenes wiederverwendet wird
# Create image file, unless reusing an existing one
if [[ -z "$SKIP_DEBOOTSTRAP" ]]
then
	echo "Creating image"
	qemu-img create -f qcow2 $FILE $SIZE
else
	if ! [[ -f $FILE ]]
	then
	        echo "Debootstrap kann nicht übersprungen werden, wenn das Image nicht vorhanden ist." >&2
		exit 1
	fi
fi
echo "Prüfe NBD-Unterstützung"
#echo "Checking for nbd support"
if ! lsmod | grep -q '^nbd\s'
then
	echo "Probing module"
	modprobe nbd
fi


if ! [[ -e $NBD_DEV ]]
then
	echo "Plausibilitätsprüfung für $NBD_DEV fehlgeschlagen. Abbruch." >&2
	exit 1
fi

echo "Hänge Image ein in $NBD_DEV"
qemu-nbd -c $NBD_DEV $FILE

PARTED_COMMANDS="mklabel gpt \
mkpart primary fat32 1MiB $(( 1 + EFI_SIZE ))MiB \
name 1 uefi \
set 1 esp on"
if [[ $SWAP_SIZE == 0 ]]
then
	echo "Überspringe Swap"
	NO_SWAP="no-swap"
	ROOT_PART=2
	ROOT_START="$(( 1 + EFI_SIZE ))MiB"
else
	echo "Partitioniere mit ${SWAP_SIZE}MiB für Swap der Rest für root"
	PARTED_COMMANDS="$PARTED_COMMANDS \
mkpart primary linux-swap $(( 1 + EFI_SIZE ))MiB $(( 1 + EFI_SIZE + SWAP_SIZE ))MiB \
name 2 swap"
	ROOT_PART=3
	ROOT_START="$(( 1 + EFI_SIZE + SWAP_SIZE ))MiB"
fi

PARTED_COMMANDS="$PARTED_COMMANDS \
mkpart primary ext4 $ROOT_START -0 \
name $ROOT_PART root"
unset ROOT_START

# Partitionierung nur anwenden, wenn Debootstrap nicht übersprungen wird
# Only apply partitioning if not skipping debootstrap
if [[ -z "$SKIP_DEBOOTSTRAP" ]]
then
	parted -s -a optimal -- $NBD_DEV \
		$PARTED_COMMANDS
	unset PARTED_COMMANDS
fi

echo "Partitioned disk:"
parted -s $NBD_DEV print

# Nur formatieren, wenn Debootstrap nicht übersprungen wird
# Only format if not skipping debootstrap
if [[ -z "$SKIP_DEBOOTSTRAP" ]]
then
	echo "Formating:"
	echo "...EFI partition"
	mkfs -t fat -F 32 -n EFI ${NBD_DEV}p1
	if [[ -z $NO_SWAP ]]
	then
		echo "...swap"
		mkswap -L swap ${NBD_DEV}p2
	fi
	echo "...root"
	mkfs -t ext4 -L root ${NBD_DEV}p${ROOT_PART}
fi
unset ROOT_PART

ROOT_UUID="$(blkid | grep "^${NBD_DEV}p[0-9]\+:" | grep ' LABEL="root" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //' )"
[[ -z $NO_SWAP ]] && SWAP_UUID="$(blkid | grep "^${NBD_DEV}p[0-9]\+:" | grep ' LABEL="swap" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //' )"
EFI_UUID="$(blkid | grep "^${NBD_DEV}p[0-9]\+:" | grep ' LABEL="EFI" ' | grep -o ' UUID="[^"]\+"' | sed -e 's/^ //' )"

echo "Root: $ROOT_UUID"
[[ -z $NO_SWAP ]] && echo "swap: $SWAP_UUID"
echo "EFI: $EFI_UUID"

echo "Mounting for chroot"
[[ -d /mnt/debootstrap ]] || mkdir -p /mnt/debootstrap
#if [[ ! -d /mnt/debootstrap ]] 
#then
# mkdir -p /mnt/debootstrap
#fi

mount $ROOT_UUID /mnt/debootstrap
[[ -d /mnt/debootstrap/boot/efi ]] || mkdir -p /mnt/debootstrap/boot/efi
mount $EFI_UUID /mnt/debootstrap/boot/efi

# Der Haupt-Debootstrap - überspringen, falls gewünscht
# The main debootstrap - skip if requested
if [[ -z "$SKIP_DEBOOTSTRAP" ]]
then
	echo "Bootstrapping ubuntu/linux mint"
	# XXX Hardcoded to x86_64 architecture but at the moment I do not want to run anything else.
	# debian
	# debootstrap --arch amd64 --include=salt-minion $SUITE /mnt http://ftp.uk.debian.org/debian
	# ubuntu / linux mint
	debootstrap --arch amd64 $SUITE /mnt/debootstrap http://de.archive.ubuntu.com/ubuntu/
fi

#apt Cache aktivieren
if [ "$USE_APT_CACHER" == "yes" ]
then
 if ! [[ -f /mnt/debootstrap/etc/apt/apt.conf.d/02proxy ]]
 then
  cp $WORKDIR/02proxy /mnt/debootstrap/etc/apt/apt.conf.d/
 fi
fi
echo "Hänge proc, dev und sys ein"
#echo "Mounting proc, dev and sys"
mount -o bind,ro /dev /mnt/debootstrap/dev
mount -o bind /dev/pts /mnt/debootstrap/dev/pts
mount -t sysfs /sys /mnt/debootstrap/sys
mount -t proc /proc /mnt/debootstrap/proc
#####################################################
# Linux Mint keyring
echo "Get keyrings"
mkdir /mnt/debootstrap/root/tmp
cd /mnt/debootstrap/root/tmp
wget -q -O - http://packages.linuxmint.com/pool/main/l/linuxmint-keyring/linuxmint-keyring_2022.06.21.tar.gz | tar xvzf - 
cp linuxmint-keyring-2016.05.26ubuntu1/etc/apt/trusted.gpg.d/linuxmint-keyring.gpg /mnt/debootstrap/etc/apt/trusted.gpg.d/
cp linuxmint-keyring-2016.05.26ubuntu1/usr/share/keyrings/linuxmint-keyring.gpg /mnt/debootstrap/usr/share/keyrings/

echo "Bereite Stage 2 vor"
#echo "Preparing stage 2"
cat > /mnt/debootstrap/root/stage-2-setup.bash <<EOF
#!/bin/bash

set -e # Abort on error

export DEBIAN_FRONTEND=noninteractive

echo "Configuring fstab"
cat > /etc/fstab <<S2EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
$( [[ -z $NO_SWAP ]] && echo "$SWAP_UUID none swap sw  0       0" )
$ROOT_UUID / ext4 errors=remount-ro 0 1
$EFI_UUID /boot/efi vfat defaults 0 1
S2EOF
cat /etc/fstab

echo "...mounting"
[[ -d /boot/efi ]] || mkdir /boot/efi
mount -a
echo "--------------------------------------------"

echo "Configuring networking"
cat - >/etc/netplan/01-network-manager-all.yaml <<S2EOF
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
S2EOF

echo "Configuring hostname"
echo "$NAME" > /etc/hostname

echo "Setting up /etc/hosts"
cat - >/etc/hosts <<S2EOF
127.0.0.1       localhost
127.0.1.1       $NAME.$DOMAIN_NAME $NAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
S2EOF

echo "--------------------------------------------"

echo "Configuring apt sources"
# Linux Mint
echo "# wurde ersetzt durch official-package-repositories.list" > /etc/apt/sources.list 

cat - >/etc/apt/sources.list.d/official-package-repositories.list  <<S2EOF
deb http://packages.linuxmint.com xia main upstream import backport #id:linuxmint_main

deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
S2EOF

cat - >/etc/apt/preferences.d/nosnap.pref  <<S2EOF
# To prevent repository packages from triggering the installation of Snap,
# this file forbids snapd from being installed by APT.
# For more information: https://linuxmint-user-guide.readthedocs.io/en/latest/snap.html

Package: snapd
Pin: release a=*
Pin-Priority: -10
S2EOF

cat - >/etc/apt/preferences.d/official-extra-repositories.pref  <<S2EOF
Package: *
Pin: origin "build.linuxmint.com"
Pin-Priority: 700
S2EOF

cat - >/etc/apt/preferences.d/official-package-repositories.pref  <<S2EOF
Package: *
Pin: release o=linuxmint,c=upstream
Pin-Priority: 700
S2EOF

apt-get -qq -y update

echo "--------------------------------------------"

# ubuntu / mint German locales
apt -qq -y install locales console-setup debconf-utils language-selector-common linuxmint-keyring
localedef -i de_DE -c -f UTF-8 de_DE.UTF-8 

locale-gen de_DE.UTF-8
echo "Europe/Berlin" > /etc/timezone && \
dpkg-reconfigure -f noninteractive tzdata && \
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
sed -i -e 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen && \
echo 'LANG="de_DE.UTF-8"'>/etc/default/locale && \
dpkg-reconfigure --frontend=noninteractive locales && \
update-locale LANG=de_DE.UTF-8

echo "Configuring keyboard"
debconf-set-selections <<S2EOF
keyboard-configuration keyboard-configuration/layoutcode string de
keyboard-configuration keyboard-configuration/layout select de
keyboard-configuration keyboard-configuration/variant select German
keyboard-configuration keyboard-configuration/model select Generic 105-key PC
keyboard-configuration keyboard-configuration/xkb-keymap string de
S2EOF

cat - >/etc/default/keyboard <<S2EOF
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) manual page.
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
S2EOF
#apt-get -qq -y install locales console-setup

echo "--------------------------------------------"

echo "Installing kernel"
#apt-get -qq -y install linux-image-amd64
# ubuntu / mint
apt -qq -y install linux-image-generic
echo "--------------------------------------------"

echo "Installing bootloader"
apt-get -qq -y install grub-efi-amd64 shim-signed

# Keine Suche nach anderen Systemen
cat - >>/etc/default/grub <<S2EOF
GRUB_DISABLE_OS_PROBER=true
S2EOF

#remove grub quiet
sed -i -e 's/quiet splash//g' /etc/default/grub

grub-install --target=x86_64-efi
update-grub

echo "--------------------------------------------"

echo "Enabling serial console"
systemctl enable serial-getty@ttyS0.service

echo "--------------------------------------------"

# Additionall packages
apt -qq -y install sudo 
useradd -m -s /bin/bash -G adm,disk,cdrom,sudo,dip,plugdev $USERNAME
# Set password
        echo "--------------------------------------------"
	echo "Setting admin password"
	echo '$USERNAME:$PASSWORD' | chpasswd
	echo "--------------------------------------------"
	
	
apt -qq -y install mint-info-cinnamon
apt -qq -y install $DESKTOP
echo "------------------- LANG ------------------------"
apt -y install $EXTRA
apt -y install $(check-language-support -l de)

# Configure Linux Mint 22 default theme

if [ ! -e /etc/dconf/db/local.d ]
then 
 mkdir -p /etc/dconf/db/local.d
fi

cat - >>/etc/dconf/db/local.d/15-cinnamon-settings <<S2EOF
[org/cinnamon/theme]
name="Mint-L"

[org/cinnamon/desktop/interface]
cursor-theme='Bibata-Modern-Classic'
gtk-theme='Mint-L'
icon-theme='Mint-L'
[org/gnome/desktop/interface]
gtk-theme='Mint-L'
icon-theme='Mint-L'
S2EOF

if [ ! -e /etc/dconf/profile ]
then
 mkdir -p /etc/dconf/profile  
fi
cat - >>/etc/dconf/profile/user <<S2EOF
user-db:user
system-db:local
S2EOF

dconf update

apt update
apt -y upgrade
apt -y autoremove

echo "Tidying..."
apt-get clean

echo "=== STAGE 2 SUCCESSFULLY REACHED THE END ==="
EOF

# Only do stage 2 if not skipping it
if [[ -z $SKIP_STAGE2 ]]
then
	echo "Running stage 2 script in chroot"
	LANG=C.UTF-8 chroot /mnt/debootstrap/ /bin/bash /root/stage-2-setup.bash

	echo "Removing stage 2 script"
	rm /mnt/debootstrap/root/stage-2-setup.bash
else
	echo "Skipping stage 2, script has been writtn to /mnt/root/stage-2-setup.bash"
fi

if [[ -z $SKIP_UNMOUNT ]]
then
	echo "Unmounting chroot"
	umount /mnt/debootstrap/proc /mnt/debootstrap/sys /mnt/debootstrap/dev/pts /mnt/debootstrap/dev /mnt/debootstrap/boot/efi /mnt/debootstrap

	echo "Disconnecting $NBD_DEV"
	sync
	qemu-nbd -d $NBD_DEV
else
	echo "WARNING: Unmount skipped (as requested)" >&2
	echo "Multiple filesystems are mounted at and under /mnt, do not forget to unmount when finished."
	echo "NBD is also still connected, disconnect (AFTER unmounting!) with: qemu-nbd -d $NBD_DEV"
fi
# Alles aushängen
unmount_all

chown -R $THE_USER:$THE_USER $VMDIR/$VMNAME

