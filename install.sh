#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# FFmetric installer for FFmpeg/libx264
#
# Usage:
#   ./install.sh /path/to/ffmpeg
#
# This script:
#   1. Checks required files
#   2. Copies ffmetric.c, ffmetric.h, ffmetric_xgb_model.h
#      into FFmpeg's libavcodec/
#   3. Backs up libx264.c and libavcodec/Makefile
#   4. Patches libx264.c with minimal FFmetric hooks
#   5. Patches libavcodec/Makefile to compile ffmetric.o
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo "  $0 /path/to/ffmpeg"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required by this installer."
    echo
    echo "Install it with one of the following:"
    echo "  macOS:   brew install python"
    echo "  Ubuntu:  sudo apt install python3"
    echo "  Fedora:  sudo dnf install python3"
    echo
    exit 1
fi

FFMPEG_DIR="$1"
LIBAVCODEC_DIR="$FFMPEG_DIR/libavcodec"
LIBX264_C="$LIBAVCODEC_DIR/libx264.c"
MAKEFILE="$LIBAVCODEC_DIR/Makefile"

echo "=========================================="
echo " FFmetric installer"
echo "=========================================="
echo "FFmetric directory: $SCRIPT_DIR"
echo "FFmpeg directory:   $FFMPEG_DIR"
echo

# ------------------------------------------------------------
# Validate FFmpeg tree
# ------------------------------------------------------------

if [[ ! -d "$FFMPEG_DIR" ]]; then
    echo "ERROR: FFmpeg directory does not exist:"
    echo "  $FFMPEG_DIR"
    exit 1
fi

if [[ ! -d "$LIBAVCODEC_DIR" ]]; then
    echo "ERROR: Missing FFmpeg libavcodec directory:"
    echo "  $LIBAVCODEC_DIR"
    exit 1
fi

if [[ ! -f "$LIBX264_C" ]]; then
    echo "ERROR: Missing libx264.c:"
    echo "  $LIBX264_C"
    exit 1
fi

if [[ ! -f "$MAKEFILE" ]]; then
    echo "ERROR: Missing libavcodec Makefile:"
    echo "  $MAKEFILE"
    exit 1
fi

# ------------------------------------------------------------
# Validate FFmetric files
# ------------------------------------------------------------

REQUIRED_FILES=(
    "$SCRIPT_DIR/ffmetric.c"
    "$SCRIPT_DIR/ffmetric.h"
    "$SCRIPT_DIR/ffmetric_xgb_model.h"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Missing required FFmetric file:"
        echo "  $file"
        exit 1
    fi
done

# ------------------------------------------------------------
# Backup files
# ------------------------------------------------------------

timestamp="$(date +%Y%m%d_%H%M%S)"

cp "$LIBX264_C" "$LIBX264_C.bak.$timestamp"
cp "$MAKEFILE" "$MAKEFILE.bak.$timestamp"

for old_backup in "$LIBX264_C".bak.*; do
    if [[ "$old_backup" != "$LIBX264_C.bak.$timestamp" ]]; then
        rm -f -- "$old_backup"
    fi
done

for old_backup in "$MAKEFILE".bak.*; do
    if [[ "$old_backup" != "$MAKEFILE.bak.$timestamp" ]]; then
        rm -f -- "$old_backup"
    fi
done

echo "Backups created:"
echo "  $LIBX264_C.bak.$timestamp"
echo "  $MAKEFILE.bak.$timestamp"
echo "How to restore:"
echo "  cp \"$LIBX264_C.bak.$timestamp\" \"$LIBX264_C\""
echo "  cp \"$MAKEFILE.bak.$timestamp\" \"$MAKEFILE\""
echo

# ------------------------------------------------------------
# Copy FFmetric files
# ------------------------------------------------------------

cp "$SCRIPT_DIR/ffmetric.c" "$LIBAVCODEC_DIR/"
cp "$SCRIPT_DIR/ffmetric.h" "$LIBAVCODEC_DIR/"
cp "$SCRIPT_DIR/ffmetric_xgb_model.h" "$LIBAVCODEC_DIR/"

echo "Copied FFmetric files:"
echo "  libavcodec/ffmetric.c"
echo "  libavcodec/ffmetric.h"
echo "  libavcodec/ffmetric_xgb_model.h"
echo

# ------------------------------------------------------------
# Patch libx264.c
# ------------------------------------------------------------

python3 - "$LIBX264_C" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

def fail(message):
    print(f"ERROR: {message}")
    sys.exit(1)

def patch_message(message):
    print(f"Patched: {message}")

# ------------------------------------------------------------
# 1. Add #include "ffmetric.h"
# ------------------------------------------------------------

if '#include "ffmetric.h"' in text:
    pass
else:
    if '#include "ffmetric_xgb_model.h"' in text:
        text = text.replace(
            '#include "ffmetric_xgb_model.h"',
            '#include "ffmetric.h"\n#include "ffmetric_xgb_model.h"',
            1
        )
        patch_message('inserted ffmetric.h include before ffmetric_xgb_model.h')
    elif '#include "golomb.h"\n' in text:
        text = text.replace(
            '#include "golomb.h"\n',
            '#include "golomb.h"\n#include "ffmetric.h"\n',
            1
        )
        patch_message('added ffmetric.h include')
    else:
        fail('could not find include insertion point near #include "golomb.h"')

# ------------------------------------------------------------
# 2. Add int ffmetric and FFMetricContext ffmetric_ctx
# ------------------------------------------------------------

if 'FFMetricContext ffmetric_ctx;' in text:
    pass
else:
    if '    int ffmetric;\n' in text:
        text = text.replace(
            '    int ffmetric;\n',
            '    int ffmetric;\n    FFMetricContext ffmetric_ctx;\n',
            1
        )
        patch_message('added FFMetricContext ffmetric_ctx after existing int ffmetric')
    elif '    int udu_sei;\n' in text:
        text = text.replace(
            '    int udu_sei;\n',
            '    int udu_sei;\n    int ffmetric;\n    FFMetricContext ffmetric_ctx;\n',
            1
        )
        patch_message('added int ffmetric and FFMetricContext ffmetric_ctx')
    else:
        fail('could not find X264Context insertion point near int udu_sei')

# ------------------------------------------------------------
# 3. Replace X264_log()
# ------------------------------------------------------------

new_x264_log = r'''static void X264_log(void *p, int level, const char *fmt, va_list args)
{
    static const int level_map[] = {
        [X264_LOG_ERROR]   = AV_LOG_ERROR,
        [X264_LOG_WARNING] = AV_LOG_WARNING,
        [X264_LOG_INFO]    = AV_LOG_INFO,
        [X264_LOG_DEBUG]   = AV_LOG_DEBUG
    };

    AVCodecContext *avctx = p;
    X264Context *x4 = avctx ? avctx->priv_data : NULL;

    if (level < 0 || level > X264_LOG_DEBUG)
        return;

    if (x4 && x4->ffmetric) {
        char line[1024];
        va_list args2;

        va_copy(args2, args);
        vsnprintf(line, sizeof(line), fmt, args2);
        va_end(args2);

        ffmetric_parse_x264_log(&x4->ffmetric_ctx, line);
    }

    av_vlog(p, level_map[level], fmt, args);
}
'''

if 'ffmetric_parse_x264_log(&x4->ffmetric_ctx, line);' in text:
    pass
else:
    start = text.find('static void X264_log(void *p, int level, const char *fmt, va_list args)')
    if start == -1:
        fail('could not find X264_log function')

    brace_start = text.find('{', start)
    if brace_start == -1:
        fail('could not find opening brace of X264_log')

    depth = 0
    end = None

    for i in range(brace_start, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    if end is None:
        fail('could not find end of X264_log function')

    text = text[:start] + new_x264_log + text[end:]
    patch_message('replaced X264_log with FFmetric hook version')

# ------------------------------------------------------------
# 4. Add ffmetric_reset() in X264_init()
# ------------------------------------------------------------

if 'ffmetric_reset(&x4->ffmetric_ctx);' in text:
    pass
else:
    pattern = (
        r'(static av_cold int X264_init\(AVCodecContext \*avctx\)\n'
        r'\{\n'
        r'\s*X264Context \*x4 = avctx->priv_data;\n'
        r'(?:\s*AVCPBProperties \*cpb_props;\n)?'
        r'(?:\s*int sw,\s*sh;\n|\s*int sw,sh;\n)?'
        r'(?:\s*int ret;\n)?)'
    )

    match = re.search(pattern, text)
    if not match:
        fail('could not find start of X264_init')

    insert_at = match.end()
    text = text[:insert_at] + '\n    ffmetric_reset(&x4->ffmetric_ctx);\n' + text[insert_at:]
    patch_message('added ffmetric_reset in X264_init after declarations')

# ------------------------------------------------------------
# 5. Make x264 log level conditional on -ffmetric
# ------------------------------------------------------------

conditional_log_line_spaced = (
    'x4->params.i_log_level          = x4->ffmetric ? X264_LOG_DEBUG : X264_LOG_INFO;'
)
conditional_log_line_plain = (
    'x4->params.i_log_level = x4->ffmetric ? X264_LOG_DEBUG : X264_LOG_INFO;'
)

if conditional_log_line_spaced in text or conditional_log_line_plain in text:
    pass
else:
    old_lines = [
        'x4->params.i_log_level          = X264_LOG_DEBUG;',
        'x4->params.i_log_level = X264_LOG_DEBUG;',
        'x4->params.i_log_level          = X264_LOG_INFO;',
        'x4->params.i_log_level = X264_LOG_INFO;',
    ]

    replaced = False
    for old in old_lines:
        if old in text:
            if '          ' in old:
                new = conditional_log_line_spaced
            else:
                new = conditional_log_line_plain

            text = text.replace(old, new, 1)
            replaced = True
            patch_message('made x264 log level depend on ffmetric option')
            break

    if not replaced:
        print('Warning: could not find x4->params.i_log_level assignment; please check manually')

# ------------------------------------------------------------
# 6. Add -ffmetric AVOption
# ------------------------------------------------------------

if re.search(r'\{\s*"ffmetric"\s*,', text):
    pass
else:
    option_line = (
        '    { "ffmetric",      "Enable FFmetric perceptual quality prediction", '
        'OFFSET(ffmetric),      AV_OPT_TYPE_BOOL,   { .i64 = 0 }, 0, 1, VE },\n'
    )

    pattern = r'(\s*\{\s*"x264opts"\s*,.*?\},\n)'
    match = re.search(pattern, text)

    if match:
        text = text[:match.end()] + option_line + text[match.end():]
        patch_message('added ffmetric AVOption after x264opts')
    else:
        fail('could not find x264opts option to insert ffmetric AVOption')

# ------------------------------------------------------------
# 7. Add prediction AFTER x264_encoder_close(x4->enc)
# ------------------------------------------------------------

if 'ffmetric_predict(&x4->ffmetric_ctx)' in text:
    pass
else:
    close_fn_start = text.find('static av_cold int X264_close(AVCodecContext *avctx)')
    if close_fn_start == -1:
        fail('could not find X264_close function')

    close_fn_brace_start = text.find('{', close_fn_start)
    if close_fn_brace_start == -1:
        fail('could not find opening brace of X264_close')

    depth = 0
    close_fn_end = None
    for i in range(close_fn_brace_start, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                close_fn_end = i + 1
                break

    if close_fn_end is None:
        fail('could not find end of X264_close function')

    close_fn_text = text[close_fn_start:close_fn_end]

    close_call_pos = close_fn_text.find('x264_encoder_close(x4->enc);')
    if close_call_pos == -1:
        fail('could not find x264_encoder_close(x4->enc) in X264_close')

    if_start = close_fn_text.rfind('if (x4->enc)', 0, close_call_pos)
    if if_start == -1:
        fail('could not find if (x4->enc) block in X264_close')

    block_brace_start = close_fn_text.find('{', if_start)
    if block_brace_start == -1:
        fail('could not find opening brace of if (x4->enc) block in X264_close')

    depth = 0
    block_end = None
    for i in range(block_brace_start, len(close_fn_text)):
        if close_fn_text[i] == '{':
            depth += 1
        elif close_fn_text[i] == '}':
            depth -= 1
            if depth == 0:
                block_end = i + 1
                break

    if block_end is None:
        fail('could not find end of if (x4->enc) block in X264_close')

    prediction_snippet = '''

    if (x4->ffmetric) {
        double ffmetric_score = ffmetric_predict(&x4->ffmetric_ctx);

        av_log(avctx, AV_LOG_INFO,
               "FFmetric: %.2f\\n",
               ffmetric_score);
    }
'''

    close_fn_text = close_fn_text[:block_end] + prediction_snippet + close_fn_text[block_end:]
    text = text[:close_fn_start] + close_fn_text + text[close_fn_end:]
    patch_message('added FFmetric prediction after x264_encoder_close')

# ------------------------------------------------------------
# Write patched file
# ------------------------------------------------------------

path.write_text(text)
PY

echo

# ------------------------------------------------------------
# Patch libavcodec/Makefile
# ------------------------------------------------------------

python3 - "$MAKEFILE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

def patch_obj_line(text, config_name, required=False):
    pattern = rf'^(OBJS-\$\({config_name}\)\s*\+=\s*)(.*libx264\.o.*)$'

    def repl(match):
        prefix = match.group(1)
        objects = match.group(2).rstrip()

        if 'ffmetric.o' in objects:
            return match.group(0)

        print(f"Patched: added ffmetric.o to {config_name}")
        return prefix + objects + ' ffmetric.o'

    new_text, count = re.subn(pattern, repl, text, flags=re.M)

    if required and count == 0:
        print(f"Warning: did not find Makefile object line for {config_name}")

    return new_text

text = patch_obj_line(text, 'CONFIG_LIBX264_ENCODER', required=True)
text = patch_obj_line(text, 'CONFIG_LIBX264RGB_ENCODER', required=False)

path.write_text(text)
PY

echo
echo "=========================================="
echo " FFmetric installation patch completed"
echo "=========================================="
echo
echo "Next:"
echo "  cd \"$FFMPEG_DIR\""
echo "  ./configure --enable-libx264 --enable-gpl"
echo "  make -j"
echo
echo "Test:"
echo "  ./ffmpeg  -i input.mp4 -c:v libx264 -crf 28 -ffmetric 1 output.mp4"
echo