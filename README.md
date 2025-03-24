# debootstrap
Ubuntu debootstrap installation script
** Befehlszeilen aus der LinuxWelt 2025-03**

***So verwenden Sie debootstap**
```
sudo apt install debootstrap
```
```
sudo debootstrap --arch amd64 [Suite] [Ziellaufwerk] http://de.archive.ubuntu.com/ubuntu/
```

**Linux per Script installieren**
```
sudo apt install dosfstools qemu-utils
```
**Die Phasen der Installation**
```
modprobe nbd && qemu-nbd -c /dev/nbd0 [Dateiname]
```
```
mount -o bind,ro /dev /mnt/debootstrap/dev
```
```
qemu-nbd -d /dev/nbd0
```

**Die Abbilddatei in einer VM nutzen**
```
./create-vm-ubuntu-noble.sh
```
```
./create-vbox-ubuntu-noble.sh
```
