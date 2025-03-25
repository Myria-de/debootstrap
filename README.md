# Ubuntu/Linux Mint per Debootstrap installieren
Für Linux stehen viele unterschiedliche Installationsmethoden bereit. Eine davon bietet debootstrap, was zusammen mit einem Script für die Konfiguration schnell zu einem lauffähigen System führt.

Unser Beispielscript installiert Ubuntu 24.04 oder Linux Mint 22 vollautomatisch in einem Festplattenabbild für die Kernel Virtual Machine (KVM). Für Virtualbox können Sie die Datei konvertieren.

## Linux per Script installieren
Debootstrap alleine reicht für ein lauffähiges System nicht aus. Für ein Ubuntu mit Desktop sind weitere Pakete erforderlich, außerdem muss die Datei „/etc/fstab“ für die vorhandenen Partitionen erzeugt werden. Anpassungen sind auch für Netzwerkkonfiguration, Sprache und Tastaturbelegung nötig. Das ist eine komplexe Aufgabe, für die Sie das Script **„build-ubuntu-noble-image.sh“** (Ubuntu 24.04) verwenden. Das Original-Script stammt von https://github.com/loz-hurst/build-debian-qemu-image, und wir haben es für ein deutschsprachiges Ubuntu angepasst. Neben debootstrap benötigt das Script noch zwei Pakete, die Sie mit
```
sudo apt install dosfstools qemu-utils
```
installieren.

Kopieren Sie das Script in einen Arbeitsordner und öffnen Sie es im Texteditor. Die folgenden Variablen unterhalb von „Configuration“ sollten Sie prüfen und bei Bedarf ändern:

**„DEFAULT_SUITE“:** Geben Sie die gewünschte Ubuntu-Version für debootstrap an. Belassen Sie „noble“, außer Sie wünschen ein älteres oder neueres System.

**„DEFAULT_SWAP“:** Legen Sie die Größe der Swap-Partition fest. Soll keine angelegt werden, geben Sie „0“ an.

**„DEFAULT_SIZE“:** Bestimmen Sie die Größe der virtuellen Festplatte. Die Vorgabe „10G“ für 10 GiB reicht für Ubuntu aus, Sie können aber auch deutlich mehr Speicherplatz bereitstellen.

**„USERNAME=“** und **„PASSWORD“:** Geben Sie die Anmeldedaten für das erste Konto ein, das auch über Systemverwalterrechte verfügt.

**„DESKTOP“:** Dieser Wert steht für das Metapaket der Desktop-Umgebung. Die Angabe „ubuntu-desktop“ installierte den Gnome-Desktop. Es werden nur die wichtigsten Pakete automatisch installiert.

**„EXTRA“:** Einige Programme fehlen im Metapaket, beispielsweise Libre Office. Zusätzlich Pakete enthält diese Variable als Liste. Ergänzen Sie weitere Pakete, die Sie im System verwenden wollen.

**„Browser“:** Ubuntu installiert Firefox und Chromium als Snap-App. In der chroot-Umgebung ist das nicht möglich, kann aber später im laufenden System nachgeholt werden. Unser Script bietet als Alternative die deb-Pakete der Browser an. Tragen Sie bei dieser Variable „firefox“ oder „chromium“ ein.

Ist alles konfiguriert, starten Sie das Script im Arbeitsverzeichnis mit
```
sudo ./build-ubuntu-noble-image.sh
```
**Linux Mint 22 installieren:** Linux Mint 22 basiert auf Ubuntu, verwendet zusätzlich aber eigene Pakete. Mit dem Script **"build-linux_mint-22-image.sh"** instalölieren Sie Linux Mint 22 in einem Image. Die Konfiguration entspricht der für Ubuntu.

## Befehlszeilen aus der LinuxWelt 2025-03 

**So verwenden Sie debootstap**
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
## Links
Das Original-Script build-debian-qemu-image: https://github.com/loz-hurst/build-debian-qemu-image


