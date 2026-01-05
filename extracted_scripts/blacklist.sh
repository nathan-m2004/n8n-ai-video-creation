=BASE_DIR="/tmp_media/PERSONA"
TRACKING_FILE="${BASE_DIR}/used_stories.txt"

# 1. GET THE BLOCK OF TITLES
# Note: We use the 'blacklist.titles' variable here.
# We wrap it in quotes to preserve newlines.
TITLES_TO_BAN="{{ $json.blacklist.titles }}"

# 2. APPEND TO FILE
# Only run if there is actually text to save
if [ ! -z "$TITLES_TO_BAN" ]; then
    echo "$TITLES_TO_BAN" | sed 's/^[ \t]*//;s/[ \t]*$//' >> "$TRACKING_FILE"
fi