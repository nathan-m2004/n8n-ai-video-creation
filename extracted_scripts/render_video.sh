=# --- 1. SETUP & TITLE SANITIZATION ---
# !!! TESTING FLAG !!!
TEST_DURATION="" 

BASE_DIR="/tmp_media/PERSONA/Videos"
GAMEPLAY_DIR="/tmp_media/Gameplay"
RAW_TITLE="{{ $('Format Groq').item.json.title }}"

# Clean the title
CLEAN_TITLE=$(echo "$RAW_TITLE" | sed 's/[^a-zA-Z0-9]/_/g' | tr -s '_')

# Fallback
if [ -z "$CLEAN_TITLE" ]; then
    CLEAN_TITLE="PERSONA_$(date +%s)"
fi

# Conditional Output Name
if [ -n "$TEST_DURATION" ]; then
    OUTPUT_FILE="${BASE_DIR}/${CLEAN_TITLE}_TEST.mp4"
else
    OUTPUT_FILE="${BASE_DIR}/${CLEAN_TITLE}.mp4"
fi

# --- 2. DEFINE INPUTS ---

if [ -f "${BASE_DIR}/current_background.mp4" ]; then
    VIDEO_BG="${BASE_DIR}/current_background.mp4"
else
    RAND_BG=$(find "$GAMEPLAY_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) 2>/dev/null | shuf -n 1)
    if [ -n "$RAND_BG" ]; then
        echo "Found new random background: $RAND_BG" >&2
        VIDEO_BG="$RAND_BG"
    else
        echo "No gameplay found. Using static default." >&2
        VIDEO_BG="${BASE_DIR}/background.webm"
    fi
fi

# --- UPDATED: USE SINGLE AUDIO FILE ---
AUDIO_FINAL="${BASE_DIR}/final_audio.mp3" 

IMAGES_LIST="${BASE_DIR}/images_list.txt"
SUBS_FINAL="${BASE_DIR}/final_subs.vtt"
VFX_MAP="${BASE_DIR}/vfx_map.csv"

echo "Rendering using Background: $VIDEO_BG" >&2
echo "Using Audio: $AUDIO_FINAL" >&2

# --- 3. BUILD VFX FILTER CHAIN ---
VFX_CHAIN=""
if [ -f "$VFX_MAP" ]; then
    echo "Processing VFX Map..." >&2
    while IFS=, read -r tag start_ms end_ms || [ -n "$tag" ]; do
        tag=$(echo "$tag" | tr -d '[:space:]')
        start_ms=$(echo "$start_ms" | tr -d '[:space:]')
        end_ms=$(echo "$end_ms" | tr -d '[:space:]')

        START_SEC=$(awk "BEGIN {print $start_ms/1000}")
        END_SEC=$(awk "BEGIN {print $end_ms/1000}")

        case "$tag" in
            "RED") FILTER="eq=gamma_r=2:gamma_g=0.6:gamma_b=0.6:saturation=1.3:enable='between(t,$START_SEC,$END_SEC)'" ;;
            "GLITCH") FILTER="noise=alls=100:allf=t+u:enable='between(t,$START_SEC,$END_SEC)',rgbashift=rh=10:bv=10:enable='between(t,$START_SEC,$END_SEC)'" ;;
            "SHAKE") FILTER="rgbashift=rh=-10:bv=10:gh=0:edge=wrap:enable='between(t,$START_SEC,$END_SEC)'" ;;
            "ZOOM") FILTER="vignette=enable='between(t,$START_SEC,$END_SEC)'" ;;
            *) FILTER="" ;;
        esac

        if [ -n "$FILTER" ]; then
            if [ -z "$VFX_CHAIN" ]; then VFX_CHAIN="$FILTER"; else VFX_CHAIN="$VFX_CHAIN, $FILTER"; fi
        fi
    done < "$VFX_MAP"
else
    echo "No VFX Map found. Skipping effects." >&2
fi

if [ -z "$VFX_CHAIN" ]; then VFX_CHAIN="null"; fi

# --- 4. SMART ANTI-FLAG LOGIC ---
BG_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_BG" | awk '{print int($1)}')
MAX_START=$((BG_DURATION - 90))

if [ "$MAX_START" -gt 0 ]; then RANDOM_START=$(shuf -i 0-"$MAX_START" -n 1); else RANDOM_START=0; fi

DO_FLIP=$(shuf -i 0-1 -n 1)
if [ "$DO_FLIP" -eq 1 ]; then FLIP_FILTER=", hflip"; else FLIP_FILTER=""; fi

rm -f "$OUTPUT_FILE"

# --- 5. RENDER VIDEO (OPTIMIZED) ---

if [ -n "$TEST_DURATION" ]; then
    TIME_LIMIT="-t $TEST_DURATION"
    echo "!!! TEST MODE ENABLED !!!" >&2
else
    TIME_LIMIT=""
fi

# CHANGELOG:
# 1. Replaced '-f concat ...' with simple '-i "$AUDIO_FINAL"'
# 2. Kept '-r 30' and '-threads 3' for VPS optimization

ffmpeg -y -hide_banner -loglevel error \
-ss "$RANDOM_START" \
-stream_loop -1 -i "$VIDEO_BG" \
-i "$AUDIO_FINAL" \
-f concat -safe 0 -i "$IMAGES_LIST" \
-filter_complex "
    [0:v]scale=-2:1920:flags=fast_bilinear,crop=1080:1920${FLIP_FILTER}[bg]; \
    [2:v]scale=2000:-2:flags=fast_bilinear[avatar]; \
    [bg][avatar]overlay=x='(W-w)/2-150':y=H-h[v_raw]; \
    [v_raw]${VFX_CHAIN}[v_vfx]; \
    [v_vfx]subtitles='$SUBS_FINAL':force_style='FontName=Komika Axis,FontSize=20,Alignment=2,MarginV=65'[v_out]
" \
-map "[v_out]" -map 1:a \
-c:v libx264 -preset ultrafast -tune fastdecode -crf 28 \
-r 30 \
-threads 3 \
-pix_fmt yuv420p \
-c:a aac -b:a 128k \
-shortest \
$TIME_LIMIT \
"$OUTPUT_FILE"

# --- 6. OUTPUT ---
echo "$OUTPUT_FILE"