#!/bin/bash
SUITE="noble"
NAME="ubuntu-$SUITE"
WORKDIR=`pwd`
VMDIR=$WORKDIR/VMs
VMNAME=$NAME
FILE="$NAME.qcow2"
FILE="$VMDIR/$VMNAME/$FILE"

if [[ $UID -eq 0 ]]
then
	echo "Dieses Script nicht als root aufrufen" >&2
	exit 1
fi
echo "Erstelle KVM-VM $NAME"
virt-install --virt-type kvm --name $NAME \
    --vcpus 2 \
    --memory 4096 \
    --os-variant ubuntu24.04 \
    --disk $FILE \
    --import \
    --network default \
    --boot uefi \
    --graphics spice \
    --noautoconsole \
    --console pty,target_type=serial
virt-manager --connect qemu:///system --show-domain-console $VMNAME
