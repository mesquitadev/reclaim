#!/bin/bash
# Compila e monta Reclaim.app em dist/. Uso: Scripts/bundle.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Reclaim.app"

cd "$ROOT"
# Universal (Apple Silicon + Intel) quando possível; senão, só o arco nativo.
ARCHS=(--arch arm64 --arch x86_64)
if ! swift build -c "$CONFIG" "${ARCHS[@]}" >/dev/null 2>&1; then
  ARCHS=()
  swift build -c "$CONFIG"
fi

BIN="$(swift build -c "$CONFIG" "${ARCHS[@]+"${ARCHS[@]}"}" --show-bin-path)/Reclaim"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Reclaim"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"

# O ícone é desenhado por código (Scripts/icon/main.swift) em vez de versionado
# como binário: qualquer ajuste vira um diff revisável e as dez resoluções saem
# sempre coerentes entre si.
ICONSET="$(mktemp -d)/Reclaim.iconset"
swiftc -swift-version 5 -O "$ROOT/Scripts/icon/main.swift" -o "$(dirname "$ICONSET")/gen" >/dev/null
"$(dirname "$ICONSET")/gen" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Reclaim.icns"

# Assinatura ad-hoc: suficiente para rodar localmente e para o macOS lembrar
# das permissões de disco concedidas ao app.
codesign --force --sign - --identifier dev.mesquita.Reclaim "$APP" >/dev/null

echo "Pronto: $APP"
