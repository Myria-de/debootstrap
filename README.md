# Ubuntu/Linux Mint per Debootstrap installieren
Für Linux stehen viele unterschiedliche Installationsmethoden bereit. Eine davon bietet debootstrap, was zusammen mit einem Script für die Konfiguration schnell zu einem lauffähigen System führt.

Unser Beispielscript installiert Ubuntu 24.04 oder Linux Mint 22 vollautomatisch in einem Festplattenabbild für die Kernel Virtual Machine (KVM). Für Virtualbox können Sie die Datei konvertieren.

Das Verfahren entspricht in etwa dem Ergebnis der automatischen Installation, wie unter https://github.com/Myria-de/Ubuntu-Preseed beschrieben. Allerdings ist bei Debootstrap der Konfigurationsaufwand höher. Was man bei der automatischen Installation dem Installer (Ubiquity und Subiquity) mitgibt, muss bei Debootstrap per Script erfolgen. Das Verfahren ist dadurch jedoch flexibler.

## Linux per Script installieren
Debootstrap allein reicht für ein lauffähiges System nicht aus. Für ein Ubuntu mit Desktop sind weitere Pakete erforderlich, außerdem muss die Datei "/etc/fstab" für die vorhandenen Partitionen erzeugt werden. Anpassungen sind auch für die Netzwerkkonfiguration, Sprache und Tastaturbelegung nötig. Das ist eine komplexe Aufgabe, für die Sie das Script **"build-ubuntu-noble-image.sh"** (Ubuntu 24.04) verwenden. Das Original-Script stammt von https://github.com/loz-hurst/build-debian-qemu-image, und wir haben es für ein deutschsprachiges Ubuntu angepasst. Neben debootstrap benötigt das Script noch zwei Pakete, die Sie mit
```
sudo apt install dosfstools qemu-utils
```
installieren.

Laden Sie das Script-Paket über https://m6u.de/DEBSTDL herunter und entpacken Sie es in einen Arbeitsordner, beispielsweise "~/debootstrap" (oder clonen Sie dieses Repository). Öffnen Sie "build-ubuntu-noble-image.sh" im Texteditor. Die folgenden Variablen unterhalb von "Configuration" sollten Sie prüfen und bei Bedarf ändern:

**"DEFAULT_SUITE":** Geben Sie die gewünschte Ubuntu-Version für debootstrap an. Belassen Sie "noble", außer Sie wünschen ein älteres oder neueres System.

**"DEFAULT_SWAP":** Legen Sie die Größe der Swap-Partition fest. Soll keine angelegt werden, geben Sie "0" an.

**"DEFAULT_SIZE":** Bestimmen Sie die Größe der virtuellen Festplatte. Die Vorgabe "10G" für 10 GiB reicht für Ubuntu aus, Sie können aber auch deutlich mehr Speicherplatz bereitstellen.

**"USERNAME="** und **"PASSWORD":** Geben Sie die Anmeldedaten für das erste Konto ein, das auch über Systemverwalterrechte verfügt.

**"DESKTOP":** Dieser Wert steht für das Metapaket der Desktop-Umgebung. Die Angabe "ubuntu-desktop" installierte den Gnome-Desktop. Es werden nur die wichtigsten Pakete automatisch installiert.

**"EXTRA":** Einige Programme fehlen im Metapaket, beispielsweise Libre Office. Zusätzlich Pakete enthält diese Variable als Liste. Ergänzen Sie weitere Pakete, die Sie im System verwenden wollen.

**"BROWSER":** Ubuntu installiert Firefox und Chromium als Snap-App. In der chroot-Umgebung ist das nicht möglich, kann aber später im laufenden System nachgeholt werden (siehe "SNAP"). Unser Script bietet als Alternative die deb-Pakete der Browser an. Tragen Sie bei dieser Variable "firefox" oder "chromium" ein. Ist die Variable leer, wird kein Browser installiert. Wenn "SNAP=yes" gesetzt ist, wird Firefox als Snap App installiert.

**"SNAP":** Bei Ubuntu ist Snap nicht nur für den Browser zuständig, sondern auch für Ubuntu Software. Wer auf Snap grundsätzlich verzichten kann, lässt diese Variable leer. Andernfalls wird der Snap Store beim ersten Start des neuinstallierten Systems eingerichtet. Zusätzlich wird Firefox als Snap App installiert wenn "BROWSER=" (also leer).

**"USE_APT_CACHER"**: Wer mehrere Linux-PCs (Ubuntu, Linux Mint, Debian) verwendet kann den Download von Paketen bei der Installation und bei Updates mit einem Cache beschleunigen. Das ist auch bei häufigen automatischen Installationen nützlich. Die Installation des Cache erfolgt auf einem ständig verfügbaren Server-PC mit
```
sudo apt install apt-cacher-ng
```
Für weitere Infos siehe [Schnellere Updates für Linux-PCs auf gleicher Basis](https://www.pcwelt.de/1150247)

Auf den Clients benötigt man die Datei "02proxy" mit einem Inhalt wie
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

**Linux Mint 22 installieren:** Linux Mint 22 basiert auf Ubuntu, verwendet zusätzlich aber eigene Pakete. Mit dem Script **"build-linux_mint-22-image.sh"** installieren Sie Linux Mint 22 in einem Image. Die Konfiguration entspricht der für Ubuntu.

**Problembehebung:** Sollte ein Script wegen eines Fehlers vorzeitig abbrechen, bleibt die virtuelle Festplatte eingehängt. Wenn das passiert, starten Sie
```
sudo ./build-ubuntu-noble-image.sh -U
```
Löschen Sie die Image-Datei im Order "VMs". Beheben Sie den Fehler und starten Sie das Script erneut.

## Virtuelle Maschine erstellen
Die Scripts "create-vm-ubuntu-noble.sh" und "create_vm_linux_mint.sh" erstellen eine VM für KVM/Qemu. Die Scripts "create-vbox-ubuntu-noble.sh" und "create_vbox_vm_linux_mint.sh" konvertieren die Image-Datei für Virtualbox und erstellen eine VM.

**Passen Sie die Bezeichnungen in allen Scripts an.**

## System aus dem Image auf eine physische Festplatte kopieren
Verwenden Sie dafür das Script "virt_to_disk.sh".

**Aber Vorsicht!** Es setzt voraus, dass eine zweite Festplatte für die Installation vorhanden ist. Die kann für einen anderen PC auch über einen SATA-USB-Adapter verbunden sein. Die Festplatte wird neu partitioniert und alles Daten darauf gehen verloren.

Tragen Sie beispielsweise
```
TARGET_DRIVE=/dev/sdb
```
im Script ein und passen Sie auch "TARGET_EFI_PART=" und "TARGET_ROOT_PART=" an. **Prüfen Sie dieses Angaben genau**, damit Sie nicht versehentlich das falsche Laufwerk formatieren.

Das Script erstellt eine EFI-Partition mit der Bezeichung "EFI" und eine root-Partition mit der Bezeichnung "root". Die Bezeichnungen sind für die Identifizierung der Parttionen wichtig. Sollten andere Partitionen die gleichen Bezeichungen verwenden, müssen Sie das im Script anpassen.

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



