#!/bin/bash
# Compila e monta MsCleaner.app em dist/. Uso: Scripts/bundle.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/MsCleaner.app"

cd "$ROOT"
# Universal (Apple Silicon + Intel) quando possível; senão, só o arco nativo.
ARCHS=(--arch arm64 --arch x86_64)
if ! swift build -c "$CONFIG" "${ARCHS[@]}" >/dev/null 2>&1; then
  ARCHS=()
  swift build -c "$CONFIG"
fi

BIN="$(swift build -c "$CONFIG" "${ARCHS[@]+"${ARCHS[@]}"}" --show-bin-path)/MsCleaner"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MsCleaner"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"

# Assinatura ad-hoc: suficiente para rodar localmente e para o macOS lembrar
# das permissões de disco concedidas ao app.
codesign --force --sign - --identifier dev.mesquita.MsCleaner "$APP" >/dev/null

echo "Pronto: $APP"
