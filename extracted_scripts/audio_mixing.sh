BASE_DIR="/tmp_media/PERSONA/Videos"
MUSIC_VOLUME="1.0"    # Slightly lowered music to make room for voice
VOICE_VOLUME="4.0"     # 3.0 = 300% volume (Boosts the quiet AI voice)

# 1. CONCATENATE VOICE TRACK
if [ -f "${BASE_DIR}/audio_list.txt" ]; then
    ffmpeg -f concat -safe 0 -i "${BASE_DIR}/audio_list.txt" \
    -c:a pcm_s16le "${BASE_DIR}/voice_track.wav" \
    -y -v error -nostats > /dev/null 2>&1
else
    echo "CRITICAL ERROR: audio_list.txt was not generated."
    exit 1
fi

# 2. CALCULATE EXACT DURATION
VOICE_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${BASE_DIR}/voice_track.wav")
echo "Voice Duration: $VOICE_DURATION seconds"

# 3. MIX BACKGROUND MUSIC WITH BOOSTED VOICE
if [ -f "${BASE_DIR}/music_path.txt" ]; then
    BG_MUSIC=$(cat "${BASE_DIR}/music_path.txt")
    START_TIME=0
    if [ -f "${BASE_DIR}/music_start.txt" ]; then START_TIME=$(cat "${BASE_DIR}/music_start.txt"); fi
    
    echo "Mixing music with Boosted Voice & Ducking..."
    
    # EXPLANATION OF CHANGES:
    # [1:a]volume=${VOICE_VOLUME} -> We boost the voice IMMEDIATELY.
    # We then split the boosted voice so it drives the sidechain (ducking) harder too.
    
    ffmpeg -ss "$START_TIME" -stream_loop -1 -i "$BG_MUSIC" -i "${BASE_DIR}/voice_track.wav" \
    -t "$VOICE_DURATION" \
    -filter_complex "
        [1:a]volume=${VOICE_VOLUME},asplit=2[sc][voice_out];
        [0:a]volume=${MUSIC_VOLUME}[music];
        [music][sc]sidechaincompress=threshold=0.05:ratio=2:attack=50:release=300[ducked_music];
        [ducked_music][voice_out]amix=inputs=2:duration=shortest:dropout_transition=2[out]
    " \
    -map "[out]" -c:a libmp3lame -q:a 2 "${BASE_DIR}/final_audio.mp3" -y -v error -nostats > /dev/null 2>&1

else
    echo "No music found. Using boosted voice only."
    # We still apply the volume boost even if there is no music
    ffmpeg -i "${BASE_DIR}/voice_track.wav" -af "volume=${VOICE_VOLUME}" -c:a libmp3lame -q:a 2 "${BASE_DIR}/final_audio.mp3" -y -v error -nostats > /dev/null 2>&1
fi

# Cleanup
rm "${BASE_DIR}/voice_track.wav"