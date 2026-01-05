BASE_DIR="/tmp_media/PERSONA/Videos"

# PERMISSIONS
[ -f "${BASE_DIR}/final_audio.mp3" ] && chmod 666 "${BASE_DIR}/final_audio.mp3"
[ -f "${BASE_DIR}/final_subs.vtt" ] && chmod 666 "${BASE_DIR}/final_subs.vtt"
[ -f "${BASE_DIR}/images_list.txt" ] && chmod 666 "${BASE_DIR}/images_list.txt"
[ -f "${BASE_DIR}/vfx_map.csv" ] && chmod 666 "${BASE_DIR}/vfx_map.csv"

# CLEANUP
# Keep final_audio, final_subs, images_list, vfx_map. Delete the rest.
[ -f "${BASE_DIR}/audio_list.txt" ] && rm "${BASE_DIR}/audio_list.txt"
[ -f "${BASE_DIR}/voice_track.mp3" ] && rm "${BASE_DIR}/voice_track.mp3"
[ -f "${BASE_DIR}/music_start.txt" ] && rm "${BASE_DIR}/music_start.txt"
[ -f "${BASE_DIR}/music_path.txt" ] && rm "${BASE_DIR}/music_path.txt"
rm -f "${BASE_DIR}"/seg_*

echo "Audio Generation & Cleanup Complete."