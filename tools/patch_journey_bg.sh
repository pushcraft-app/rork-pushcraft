#!/bin/bash
# Erases the painted "START HERE / Stonewatch" plaque from onboarding_journey_bg
# (both platforms) so the native StartHereBadge (center 0.299/0.798 of the
# 853x1844 artwork, width 0.36) is the only name shown. The plaque occupied
# ~(108,1426)-(398,1526); it is replaced with a feathered, mirrored clone of
# the rocky terrain to its right.
set -euo pipefail
SRC="${1:?usage: patch_journey_bg.sh <input.webp> <out.webp> <out.png>}"
OUT_WEBP="${2:?}"
OUT_PNG="${3:?}"
TMP="$(mktemp -d)"
ffmpeg -y -loglevel error -i "$SRC" -filter_complex \
  "[0:v]crop=310:120:410:1414,hflip,format=yuva420p,geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)':a='255*min(1\, min(min(X\,Y)\, min(W-1-X\,H-1-Y))/22)'[clean];[0:v][clean]overlay=x=100:y=1414" \
  -frames:v 1 "$TMP/patched.png"
ffmpeg -y -loglevel error -i "$TMP/patched.png" -c:v libwebp -quality 92 "$OUT_WEBP"
cp "$TMP/patched.png" "$OUT_PNG"
echo "patched: $OUT_WEBP $OUT_PNG"
