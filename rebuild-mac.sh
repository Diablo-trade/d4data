#!/usr/bin/env bash
set -e

# Mac-compatible rebuild — local CASC mode using synced D4 install.
# Requires: brew install dotnet, node, curl

D4_PATH="${D4_PATH:-/Users/nextor/windows/games/d4}"

# .NET 6 apphost can't find brew's dotnet 10 by default; point it at brew dir + roll forward.
export DOTNET_ROOT="$(brew --prefix dotnet)/libexec"
export DOTNET_ROLL_FORWARD=LatestMajor

CASC_BIN="$(dirname "$0")/CASCExplorer/CASCConsole/bin/Release/net6.0/CASCConsole"
LOCALE="enUS"
PRODUCT="fenris"

# CascLib pinned in upstream CASCExplorer (d8f76d54) crashes on D4 3.0.x CoreTOC
# parsing. Auto-bump to CascLib master HEAD before building so OverflowException
# in D4RootHandler.CoreTOCParserD4 is fixed.
if [[ ! -f "$CASC_BIN" ]]; then
  echo "Building CASCConsole (with bumped CascLib)..."
  (cd "$(dirname "$0")/CASCExplorer/CascLib" && git fetch origin master --quiet && git checkout origin/master --quiet)
  (cd "$(dirname "$0")/CASCExplorer/CASCConsole" && dotnet publish -c Release -f net6.0 --nologo --verbosity quiet)
fi

echo "Using D4 install: $D4_PATH"

if [[ ! -f "$D4_PATH/.build.info" ]]; then
  echo "error: $D4_PATH/.build.info not found" >&2
  exit 1
fi

echo "Removing old data."
rm -rf data/*

echo "Fetching keys."
curl -s https://d4armory.io/api/keys | node TactKey.js

echo "Fetching data (local CASC)."
"$CASC_BIN" -m Pattern -e "base/*.dat"           -d data/ -l "$LOCALE" -p "$PRODUCT" -s "$D4_PATH"
"$CASC_BIN" -m Pattern -e "Base\\meta\\*"        -d data/ -l "$LOCALE" -p "$PRODUCT" -s "$D4_PATH"
"$CASC_BIN" -m Pattern -e "enUS_Text\\meta\\*"   -d data/ -l "$LOCALE" -p "$PRODUCT" -s "$D4_PATH"
"$CASC_BIN" -m Pattern -e "enUS_Speech\\meta\\*" -d data/ -l "$LOCALE" -p "$PRODUCT" -s "$D4_PATH"

# Match upstream casing convention: data/base/ → data/Base/ → data/base/
if [[ -d data/base ]]; then
  echo "Normalizing directory casing."
  mv data/base data/_base_tmp
  mkdir -p data/Base
  mv data/_base_tmp/* data/Base/ 2>/dev/null || true
  rmdir data/_base_tmp 2>/dev/null || true
  mv data/Base data/base
fi

git checkout data/ || true

echo "Removing old json."
rm -rf json/base/meta json/enUS_Text/meta json/enUS_Speech/meta

echo "Parsing json."
node parse.js data/

echo "Done."
