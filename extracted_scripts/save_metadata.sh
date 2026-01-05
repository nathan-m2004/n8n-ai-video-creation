=# --- SAVE METADATA TO FILE ---

# 1. Get Data from Groq Node
RAW_TITLE="{{ $json.title }}"
RAW_DESC="{{ $json.description }}"
BASE_DIR="/tmp_media/PERSONA/Videos"

# 2. Clean Title for Filename (Remove emojis/spaces)
CLEAN_TITLE=$(echo "$RAW_TITLE" | sed 's/[^a-zA-Z0-9]/_/g' | tr -s '_')

# 3. Create the Text File
# Example: /tmp_media/PERSONA/Videos/THE_ZOMBIE_TOOTHBRUSH.txt
cat <<EOF > "${BASE_DIR}/${CLEAN_TITLE}.txt"
$RAW_TITLE

$RAW_DESC
EOF

echo "${BASE_DIR}/${CLEAN_TITLE}.txt"