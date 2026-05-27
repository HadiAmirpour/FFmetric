#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_LIBAVCODEC="$SCRIPT_DIR"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/ffmpeg"
    exit 1
fi

FFMPEG_DIR="$1"
TARGET_LIBAVCODEC="$FFMPEG_DIR/libavcodec"

# Validate FFmpeg directory
if [[ ! -d "$FFMPEG_DIR" ]]; then
    echo "ERROR: FFmpeg directory does not exist:"
    echo "  $FFMPEG_DIR"
    exit 1
fi

if [[ ! -d "$TARGET_LIBAVCODEC" ]]; then
    echo "ERROR: Missing directory:"
    echo "  $TARGET_LIBAVCODEC"
    exit 1
fi

# Validate source files
REQUIRED_FILES=(
    "$SOURCE_LIBAVCODEC/libx264.c"
    "$SOURCE_LIBAVCODEC/ffmetric_xgb_model.h"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Missing source file:"
        echo "  $file"
        exit 1
    fi
done

# Backup original libx264.c
if [[ -f "$TARGET_LIBAVCODEC/libx264.c" ]]; then
    cp "$TARGET_LIBAVCODEC/libx264.c" \
       "$TARGET_LIBAVCODEC/libx264.c.bak"

    echo "Backup created:"
    echo "  libavcodec/libx264.c.bak"
fi

# Replace libx264.c
cp "$SOURCE_LIBAVCODEC/libx264.c" \
   "$TARGET_LIBAVCODEC/"

echo "Replaced:"
echo "  libavcodec/libx264.c"

# Copy ffmetric_xgb_model.h
cp "$SOURCE_LIBAVCODEC/ffmetric_xgb_model.h" \
   "$TARGET_LIBAVCODEC/"

echo "Copied:"
echo "  libavcodec/ffmetric_xgb_model.h"

echo
echo "FFmetric x264 installation completed successfully."