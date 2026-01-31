#!/usr/bin/env bash
set -euo pipefail

moon check --target js --deny-warn
moon build --target js

rm -rf dist
mkdir -p dist
sed 's#_build/js/release/build/cmd/main/main.js#main.js#' index.html > dist/index.html
cp _build/js/release/build/cmd/main/main.js dist/main.js
