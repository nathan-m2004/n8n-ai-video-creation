=# --- CONFIGURATION ---
BASE_DIR="/tmp_media/PERSONA/Videos"
PERSONA_DIR="/tmp_media/PERSONA/Persona"
SFX_DIR="/tmp_media/SFX"
MUSIC_DIR="/tmp_media/Music"

# WRITE THE OPTIMIZED PYTHON SCRIPT
cat <<EOF > "${BASE_DIR}/generate_dynamic_video.py"
import re
import subprocess
import os
import sys
import random
import traceback
import concurrent.futures
import json
import urllib.request
import base64

# --- PYTHON CONFIG ---
PERSONA_DIR = "${PERSONA_DIR}"
SFX_DIR = "${SFX_DIR}"
MUSIC_DIR = "${MUSIC_DIR}"
OUTPUT_DIR = "${BASE_DIR}"

# --- KOKORO SETTINGS ---
KOKORO_URL = "http://kokoro-tts:8880/v1/audio/speech"
KOKORO_VOICE = "pm_santa(0.8)+am_onyx(0.1)"
KOKORO_SPEED = 1.3       # Speed BEFORE pitch shift (make it faster if pitch shift slows it down too much)
PITCH_SHIFT = "0.9"       # 1.0 = Normal, 0.9 = Deep, 0.8 = Demon (affects speed too)

SFX_MAX_DURATION = 1.5
SFX_VOLUME = 0.18

# --- HELPER FUNCTIONS ---
def get_duration_ms(filepath):
    try:
        res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", filepath], capture_output=True, text=True)
        return int(float(res.stdout.strip()) * 1000)
    except:
        return 500

def fmt_vtt(ms):
    h, r = divmod(ms, 3600000)
    m, r = divmod(r, 60000)
    s, ms = divmod(r, 1000)
    return f"{h:02}:{m:02}:{s:02}.{ms:03}"

def process_segment(job):
    """
    Worker function to generate audio files in parallel.
    """
    i = job['id']
    tag = job['tag']
    text = job['text']
    segment_id = f"seg_{i}"
    
    results = [] 

    is_vfx = tag.startswith("VFX:")
    is_sfx = tag.startswith("SFX:")
    
    # 1. HANDLE SFX GENERATION
    if is_sfx:
        sfx_name = tag.split(":")[1].strip().lower()
        sfx_file_wav = f"{OUTPUT_DIR}/{segment_id}_sfx.wav"
        source_sfx = f"{SFX_DIR}/{sfx_name}.mp3"
        
        # Generate/Convert SFX
        if os.path.exists(source_sfx):
            filter_chain = (f"volume={SFX_VOLUME},areverse,silenceremove=start_periods=1:start_duration=0:start_threshold=-50dB,areverse,afade=t=out:st={SFX_MAX_DURATION-0.2}:d=0.2")
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-nostats", "-i", source_sfx, "-af", filter_chain, "-t", str(SFX_MAX_DURATION), "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", sfx_file_wav], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["ffmpeg", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "0.2", "-c:a", "pcm_s16le", sfx_file_wav, "-y", "-v", "error", "-nostats"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        results.append({
            'type': 'audio',
            'file': sfx_file_wav,
            'duration': get_duration_ms(sfx_file_wav),
            'img': job['emotion'] 
        })

    # 2. HANDLE TTS GENERATION (KOKORO LOCAL)
    has_letters = bool(re.search(r'[a-zA-Z0-9]', text))
    if has_letters:
        temp_mp3 = f"{OUTPUT_DIR}/{segment_id}_temp.mp3"
        tts_file_wav = f"{OUTPUT_DIR}/{segment_id}_tts.wav"

        try:
            # Prepare JSON Payload
            data = {
                "model": "kokoro",
                "input": text,
                "voice": KOKORO_VOICE,
                "speed": KOKORO_SPEED,
                "response_format": "mp3"
            }
            
            # Send Request to Local Container
            req = urllib.request.Request(
                KOKORO_URL, 
                json.dumps(data).encode("utf-8"), 
                {"Content-Type": "application/json"}
            )
            
            # Write Response to File
            with urllib.request.urlopen(req) as response:
                with open(temp_mp3, "wb") as f:
                    f.write(response.read())

            # Convert to WAV with PITCH SHIFT
            # asetrate changes pitch (and speed), atempo fixes the speed back
            filter_complex = f"asetrate=24000*{PITCH_SHIFT},atempo=1/{PITCH_SHIFT},aresample=44100"
            
            subprocess.run([
                "ffmpeg", "-y", "-v", "error", "-nostats", 
                "-i", temp_mp3, 
                "-af", filter_complex, 
                "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", 
                tts_file_wav
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            if os.path.exists(temp_mp3): os.remove(temp_mp3)
            
            # GENERATE MANUAL VTT
            duration_ms = get_duration_ms(tts_file_wav)
            vtt_start = "00:00:00.000"
            vtt_end = fmt_vtt(duration_ms)
            fake_vtt_content = [f"{vtt_start} --> {vtt_end}\n", f"{text}\n"]

            results.append({
                'type': 'tts',
                'file': tts_file_wav,
                'duration': duration_ms,
                'img': job['emotion'],
                'vtt_lines': fake_vtt_content,
                'vfx_to_apply': job.get('pending_vfx')
            })
            
        except Exception as e:
            print(f"Error in TTS {i}: {e}")
            if "Connection refused" in str(e):
                print("CRITICAL: Could not connect to Kokoro. Is the docker container running?")

    return {'id': i, 'items': results}


# --- MAIN EXECUTION ---
try:
    script_path = f"{OUTPUT_DIR}/script.txt"
    if not os.path.exists(script_path):
        print(f"ERROR: Script file not found at {script_path}")
        sys.exit(1)

    with open(script_path, "r") as f:
        full_text = f.read()

    if not full_text.strip().startswith("["):
        full_text = "[NEUTRAL] " + full_text
        
    # --- MUSIC SELECTION ---
    if os.path.exists(MUSIC_DIR):
        music_files = [f for f in os.listdir(MUSIC_DIR) if f.lower().endswith('.mp3')]
        if music_files:
            bg_music_path = os.path.join(MUSIC_DIR, random.choice(music_files))
            try:
                res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", bg_music_path], capture_output=True, text=True)
                dur = float(res.stdout.strip())
                start = random.uniform(0, max(0, dur - 90))
                with open(f"{OUTPUT_DIR}/music_path.txt", "w") as f: f.write(bg_music_path)
                with open(f"{OUTPUT_DIR}/music_start.txt", "w") as f: f.write(str(start))
            except: pass

    # --- JOB PREPARATION ---
    segments = re.split(r'\[(NEUTRAL|SCARED|EVIL|SUSPICIOUS|LAUGHING|SFX:\s*[A-Z_]+|VFX:\s*[A-Z_]+)\]', full_text, flags=re.IGNORECASE)
    
    jobs = []
    last_valid_emotion = "neutral"
    pending_vfx = None

    for i in range(1, len(segments), 2):
        tag = segments[i].upper().strip()
        text = segments[i+1].strip()
        
        is_vfx = tag.startswith("VFX:")
        is_sfx = tag.startswith("SFX:")
        is_emotion = not (is_vfx or is_sfx)

        if is_emotion: last_valid_emotion = tag.lower()
        if is_vfx: pending_vfx = tag.split(":")[1].strip()

        jobs.append({
            'id': i,
            'tag': tag,
            'text': text,
            'emotion': last_valid_emotion,
            'pending_vfx': pending_vfx 
        })
        
        if pending_vfx and bool(re.search(r'[a-zA-Z0-9]', text)):
            pending_vfx = None

    # --- PARALLEL EXECUTION ---
    print(f"Starting parallel generation with {len(jobs)} segments...")
    
    processed_segments = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = {executor.submit(process_segment, job): job for job in jobs}
        for future in concurrent.futures.as_completed(futures):
            try:
                res = future.result()
                processed_segments.append(res)
            except Exception as e:
                print(f"Worker failed: {e}")
                traceback.print_exc()

    processed_segments.sort(key=lambda x: x['id'])

    # --- TIMELINE ASSEMBLY ---
    final_audio_files = []
    concat_image_lines = []
    combined_vtt_lines = ["WEBVTT\n\n"]
    vfx_map_lines = [] 
    current_time_ms = 0
    
    for seg in processed_segments:
        for item in seg['items']:
            final_audio_files.append(item['file'])
            
            dur_sec = item['duration'] / 1000.0
            img = f"{PERSONA_DIR}/{item['img']}.png"
            if not os.path.exists(img): img = f"{PERSONA_DIR}/neutral.png"
            concat_image_lines.append(f"file '{img}'")
            concat_image_lines.append(f"duration {dur_sec}")
            
            if item.get('vfx_to_apply'):
                vfx_map_lines.append(f"{item['vfx_to_apply']},{current_time_ms},{current_time_ms + item['duration']}\n")

            if item.get('vtt_lines'):
                for line in item['vtt_lines']:
                    if "-->" in line:
                        start_str, end_str = line.strip().split(" --> ")
                        def parse_vtt(t):
                            parts = t.replace(',',('.')).split(':')
                            s_parts = parts[-1].split('.')
                            h,m = (int(parts[0]), int(parts[1])) if len(parts)==3 else (0, int(parts[0]))
                            s,ms = int(s_parts[0]), int(s_parts[1])
                            return h*3600000 + m*60000 + s*1000 + ms
                        
                        new_start = fmt_vtt(parse_vtt(start_str) + current_time_ms)
                        new_end = fmt_vtt(parse_vtt(end_str) + current_time_ms)
                        combined_vtt_lines.append(f"{new_start} --> {new_end}\n")
                    elif line.strip() and "WEBVTT" not in line:
                        combined_vtt_lines.append(line)

            current_time_ms += item['duration']

    # --- FINAL WRITES ---
    silence_file_wav = f"{OUTPUT_DIR}/silence_end.wav"
    subprocess.run(["ffmpeg", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "2", "-c:a", "pcm_s16le", silence_file_wav, "-y", "-v", "error", "-nostats"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    final_audio_files.append(silence_file_wav)
    
    if concat_image_lines:
        concat_image_lines.append(concat_image_lines[-2])
        concat_image_lines.append("duration 2")

    with open(f"{OUTPUT_DIR}/audio_list.txt", "w") as f:
        for af in final_audio_files: f.write(f"file '{af}'\n")

    with open(f"{OUTPUT_DIR}/images_list.txt", "w") as f:
        f.write("\n".join(concat_image_lines))

    with open(f"{OUTPUT_DIR}/final_subs.vtt", "w") as f:
        f.writelines(combined_vtt_lines)

    with open(f"{OUTPUT_DIR}/vfx_map.csv", "w") as f:
        f.writelines(vfx_map_lines)
    
    print("Python Generation Complete.")

except Exception as e:
    print("PYTHON CRASHED:")
    traceback.print_exc()
    sys.exit(1)
EOF

# EXECUTE PYTHON
python3 "${BASE_DIR}/generate_dynamic_video.py"