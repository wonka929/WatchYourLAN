#!/usr/bin/env sh
set -e
# Simple helper to build the APK using abuild.
# NOTE: abuild must be run on an Alpine system (or in an Alpine chroot/container)
# and NOT as root. See the README below for setup notes.

# Imposta PKGDIR come directory dello script, portabile ovunque venga eseguito
HERE=$(cd "$(dirname "$0")" && pwd)
PKGDIR="$HERE"

if ! command -v abuild >/dev/null 2>&1; then
  echo "abuild non trovato. Installa 'abuild' in Alpine: apk add abuild alpine-sdk" >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "Non eseguire questo script come root. Esegui come utente normale in Alpine." >&2
  exit 1
fi

# Generate abuild key if missing
if [ ! -f "$HOME/.abuild/abuild-$(whoami).rsa" ]; then
  echo "Generazione chiave abuild (abuild-keygen -a -i)..."
  abuild-keygen -a -i
fi

echo "Preparazione directory di build..."
# Read pkgname and pkgver from APKBUILD to build a correct source folder name
pkgname=$(sed -n 's/^pkgname=\(.*\)/\1/p' "$PKGDIR/APKBUILD" | tr -d '"')
pkgver=$(sed -n 's/^pkgver=\(.*\)/\1/p' "$PKGDIR/APKBUILD" | tr -d '"')
if [ -z "$pkgname" ] || [ -z "$pkgver" ]; then
  pkgname=watchyourlan
  pkgver=2.4.1
fi
srcdir_name="$pkgname-$pkgver"

# Ensure abuild writes packages inside the repo to avoid using /home/<other>/packages
PACKAGES="$PKGDIR/packages"
export PACKAGES
mkdir -p "$PACKAGES"

# Create a temporary build directory inside pack/alpine to avoid permission/path issues
tmpdir="$PKGDIR/build"
mkdir -p "$tmpdir"

echo "Copia sorgenti in $tmpdir"
mkdir -p "$tmpdir/$srcdir_name"

# Copia il contenuto di pack/alpine direttamente dentro $tmpdir/$srcdir_name, evitando annidamenti.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude 'build-tmp-*' --exclude 'packages' --exclude '.git' "$PKGDIR/" "$tmpdir/$srcdir_name"
else
  (cd "$PKGDIR" && tar --exclude='build-tmp-*' --exclude='packages' --exclude='.git' -cf - .) | (cd "$tmpdir/$srcdir_name" && tar -xf -)
fi

# Ensure APKBUILD is present in the source root (some setups expect it there)
cp -f "$PKGDIR/APKBUILD" "$tmpdir/$srcdir_name/"

cd "$tmpdir/$srcdir_name"

echo "Avvio build con abuild -r (richiede pacchetti makedepends installati)..."
abuild -r

echo "Build completata. I pacchetti si trovano in $PACKAGES o nella directory configurata da abuild." 
