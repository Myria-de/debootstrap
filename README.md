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

**"USE_APT_CACHER"**: Wer mehrere Linux-PCs (Ubuntu, Linux Mint, Debian) verwendet kann den Download von Paketen bei der Installation und bei Updates mit einem Cache beschleunigen. Das ist auch bei häufigen automatischen Installationen nützlich. Die Installation des Cache erfolgt auf einem ständig verfügbaren Server-PC mit
```
sudo apt install apt-cacher-ng
```
Für weitere Infos siehe [Schnellere Updates für Linux-PCs auf gleicher Basis](https://www.pcwelt.de/1150247)

Auf den Clients benötigt man die Datei „02proxy“ mit einem Inhalt wie
```
Acquire::http { Proxy "http://192.168.178.111:3142"; };
Acquire::https { Proxy "https//"; };
```
Ersetzen Sie die IP-Nummer durch die Ihres Server-PCs. Die Datei liegt im Arbeitsverzeichnis und wird in das Image kopiert, wenn Sie 
```
USE_APT_CACHER="yes"
```
konfiguren. Wenn Sie keinen Cache verwenden lautet die Konfiguration
```
USE_APT_CACHER=
```

**Script starten:** Ist alles konfiguriert, starten Sie das Script im Arbeitsverzeichnis mit
```
sudo ./build-ubuntu-noble-image.sh
```

**Linux Mint 22 installieren:** Linux Mint 22 basiert auf Ubuntu, verwendet zusätzlich aber eigene Pakete. Mit dem Script **"build-linux_mint-22-image.sh"** instalölieren Sie Linux Mint 22 in einem Image. Die Konfiguration entspricht der für Ubuntu.

**Problembehebung:** Sollte ein Script wegen eines Fehlers vorzeitig abbrechen, bleibt die virtuelle Festplatte eingehängt. Wenn das passiert, starten Sie
```
sudo ./build-ubuntu-noble-image.sh -U
```
Löschen Sie die Image-Datei im Order "VMs". Beheben Sie den Fehler und starten Sie das Script erneut.

## Virtuelle Maschine erstellen
Die Scripts "create-vm-ubuntu-noble.sh" und "create_vm_linux_mint.sh" erstellen eine VM für KVM/Qemu. Die Scripts "create-vbox-ubuntu-noble.sh" und "create_vbox_vm_linux_mint.sh" konvertieren die Image-Datei für Virtualbox und erstellen eine VM.

Passen Sie die Bezeichnungen in allen Scripts an. 

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


