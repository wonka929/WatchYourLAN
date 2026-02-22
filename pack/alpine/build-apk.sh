#!/usr/bin/env sh
set -e
# Simple helper to build the APK using abuild.
# NOTE: abuild must be run on an Alpine system (or in an Alpine chroot/container)
# and NOT as root. See the README below for setup notes.

HERE=$(cd "$(dirname "$0")" && pwd)
PKGDIR=$(cd "$HERE" && pwd)

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
# Create a temporary build directory inside pack/alpine to avoid permission/path issues
# Use a unique name with timestamp, pid and random suffix
tmpdir="$PKGDIR/build-tmp-$(date +%s)-$$-$RANDOM"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT

echo "Copia sorgenti in $tmpdir"
# copy repository into a folder named watchyourlan-<ver> as expected by abuild
# use recursive copy without preserving ownership to avoid "Operation not permitted"
mkdir -p "$tmpdir/watchyourlan-2.4.1"
cp -r "$PKGDIR/../." "$tmpdir/watchyourlan-2.4.1"
cp "$PKGDIR/APKBUILD" "$tmpdir/watchyourlan-2.4.1/"

cd "$tmpdir/watchyourlan-2.4.1"

echo "Avvio build con abuild -r (richiede pacchetti makedepends installati)..."
abuild -r

echo "Build completata. I pacchetti si trovano in ~/packages/ o nella directory configurata da abuild." 
