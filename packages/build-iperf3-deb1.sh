#!/usr/bin/env bash
set -euo pipefail

VERSION="3.20"
PKGNAME="iperf3"
PKGVER="${VERSION}-1"
WORKDIR="$HOME/iperf3.make"
SRC_ARCHIVE="iperf-${VERSION}.tar.gz"
SRC_SHA="${SRC_ARCHIVE}.sha256"
SRC_DIR="iperf-${VERSION}"

echo "[1/9] Installiere Build-Abhängigkeiten..."
sudo apt update
sudo apt install -y \
  build-essential \
  devscripts \
  debhelper \
  dh-make \
  dpkg-dev \
  fakeroot \
  lintian \
  autoconf \
  automake \
  libtool \
  pkgconf \
  libsctp-dev \
  wget

echo "[2/9] Arbeitsverzeichnis vorbereiten..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[3/9] Quellen herunterladen..."
wget -O "$SRC_ARCHIVE" "https://downloads.es.net/pub/iperf/${SRC_ARCHIVE}"
wget -O "$SRC_SHA" "https://downloads.es.net/pub/iperf/${SRC_SHA}"

echo "[4/9] SHA256 prüfen..."
sha256sum -c "$SRC_SHA"

echo "[5/9] Quellen entpacken..."
rm -rf "$SRC_DIR"
tar xf "$SRC_ARCHIVE"
cd "$SRC_DIR"

echo "[6/9] Debian-Verzeichnis neu erzeugen..."
rm -rf debian
export DEBFULLNAME="Ewald"
export DEBEMAIL="ewald@localhost"
dh_make --createorig -s -p "${PKGNAME}_${VERSION}" -y

rm -f debian/*.ex debian/*.EX 2>/dev/null || true
rm -rf debian/upstream.ex 2>/dev/null || true

echo "[7/9] Debian-Dateien schreiben..."

cat > debian/control <<'EOT'
Source: iperf3
Section: net
Priority: optional
Maintainer: Ewald <ewald@localhost>
Build-Depends:
 debhelper-compat (= 13),
 libsctp-dev
Standards-Version: 4.7.0
Rules-Requires-Root: no
Homepage: https://software.es.net/iperf/

Package: iperf3
Architecture: any
Depends:
 ${shlibs:Depends},
 ${misc:Depends},
 libiperf0 (= ${binary:Version})
Description: Internet Protocol bandwidth measuring tool
 iperf3 is a tool for active measurements of the maximum achievable
 bandwidth on IP networks. This package contains the command line utility.

Package: libiperf0
Section: libs
Architecture: any
Depends:
 ${shlibs:Depends},
 ${misc:Depends}
Description: Internet Protocol bandwidth measuring tool (runtime files)
 This package contains the shared runtime library for iperf3.

Package: libiperf-dev
Section: libdevel
Architecture: any
Depends:
 ${misc:Depends},
 libiperf0 (= ${binary:Version})
Description: Internet Protocol bandwidth measuring tool (development files)
 This package contains the development files for the iperf3 shared library.
EOT

cat > debian/rules <<'EOT'
#!/usr/bin/make -f

%:
	dh $@
EOT
chmod +x debian/rules

cat > debian/changelog <<EOT
iperf3 (${PKGVER}) unstable; urgency=medium

  * Local build of upstream ${VERSION}.

 -- Ewald <ewald@localhost>  Sun, 15 Mar 2026 20:40:00 +0100
EOT

mkdir -p debian/source
cat > debian/source/format <<'EOT'
3.0 (quilt)
EOT

cat > debian/iperf3.install <<'EOT'
usr/bin/iperf3
usr/share/man/man1/iperf3.1
EOT

cat > debian/libiperf0.install <<'EOT'
usr/lib/*/libiperf.so.0*
EOT

cat > debian/libiperf-dev.install <<'EOT'
usr/include/iperf_api.h
usr/lib/*/libiperf.a
usr/lib/*/libiperf.so
usr/share/man/man3/libiperf.3
EOT

cat > debian/libiperf-dev.docs <<'EOT'
README.md
EOT

cat > debian/not-installed <<'EOT'
usr/lib/*/libiperf.la
EOT

cat > debian/copyright <<'EOT'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: iperf3
Source: https://software.es.net/iperf/

Files: *
Copyright: ESnet and contributors
License: BSD-3-clause

License: BSD-3-clause
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 .
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 .
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 .
 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.
 .
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES.
EOT

echo "[8/9] Pakete bauen..."
dpkg-buildpackage -us -uc -b

echo "[9/9] Fertig"
echo
echo "Pakete liegen hier:"
ls -lh ../*.deb
echo
echo "Installieren mit:"
echo "sudo apt remove -y iperf3 libiperf0 libiperf-dev"
echo "sudo apt install ../libiperf0_${PKGVER}_arm64.deb ../iperf3_${PKGVER}_arm64.deb"
echo
echo "Optional dev:"
echo "sudo apt install ../libiperf-dev_${PKGVER}_arm64.deb"
