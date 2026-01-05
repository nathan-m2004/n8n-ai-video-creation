BASE_DIR="/tmp_media/PERSONA"
TRACKING_FILE="${BASE_DIR}/used_stories.txt"

# 1. Create the file if it doesn't exist (prevents crashes)
if [ ! -f "$TRACKING_FILE" ]; then
    mkdir -p "$BASE_DIR"
    touch "$TRACKING_FILE"
fi

# 2. Output the file content
cat "$TRACKING_FILE"