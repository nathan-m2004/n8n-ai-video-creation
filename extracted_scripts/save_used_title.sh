=BASE_DIR="/tmp_media/PERSONA"
TRACKING_FILE="${BASE_DIR}/used_stories.txt"

# Get the title from the workflow context
TITLE="{{ $('Get Selected Story').item.json.winner.title }}"

# Clean formatting and append to file
echo "$TITLE" | sed 's/^[ \t]*//;s/[ \t]*$//' >> "$TRACKING_FILE"