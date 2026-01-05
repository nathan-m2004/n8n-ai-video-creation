=# --- 1. SETUP TITLES & DIRECTORIES ---
RAW_TITLE="{{ $('Format Groq').item.json.title }}"
CLEAN_TITLE=$(echo "$RAW_TITLE" | sed 's/[^a-zA-Z0-9]/_/g' | tr -s '_')

# Define paths
BASE_DIR="/tmp_media/PERSONA/Videos"
PERSONA_DIR="/tmp_media/PERSONA/Persona"
SFX_DIR="/tmp_media/SFX"
MUSIC_DIR="/tmp_media/Music"
GAMEPLAY_DIR="/tmp_media/Gameplay"

mkdir -p "$BASE_DIR"
mkdir -p "$PERSONA_DIR"
mkdir -p "$SFX_DIR"
mkdir -p "$MUSIC_DIR"
mkdir -p "$GAMEPLAY_DIR"

# --- RANDOM BACKGROUND SELECTION ---
# Find all video files (mp4, webm, mkv) in the Gameplay folder
# shuf -n 1 picks one at random
SELECTED_BG=$(find "$GAMEPLAY_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) 2>/dev/null | shuf -n 1)

# Fallback if no gameplay found (Safety Check)
if [ -z "$SELECTED_BG" ]; then
    echo "WARNING: No gameplay found in $GAMEPLAY_DIR. Using default background."
    # Ensure a default exists or copy one manually if needed
    if [ -f "${BASE_DIR}/background.webm" ]; then
        SELECTED_BG="${BASE_DIR}/background.webm"
    else
        echo "ERROR: No default background found at ${BASE_DIR}/background.webm"
        # Create a dummy file just to prevent immediate crash, though render will fail later
        touch "${BASE_DIR}/background.webm"
        SELECTED_BG="${BASE_DIR}/background.webm"
    fi
fi

# Copy selection to a standard path so the Render Node always knows where to look
cp "$SELECTED_BG" "${BASE_DIR}/current_background.mp4"

# Save script text
cat <<EOF > "${BASE_DIR}/script.txt"
{{ $('Format Groq').item.json.script }}
EOF

echo "Setup Complete. Selected Background: $SELECTED_BG"