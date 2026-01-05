import re
import math
import sys
import os

# --- CONFIGURATION ---
FILENAME = "${SUBS_FILE}"
WORDS_PER_BLOCK = 2 
BUFFER_MS = 0       # Gap between subs to prevent flicker
TIME_OFFSET_MS = -650 # <--- ADJUST THIS: Negative = Earlier, Positive = Later

def parse_time(t):
    t = t.replace(',', '.')
    parts = t.strip().split(':')
    if len(parts) == 2:
        h, m, s_ms = 0, int(parts[0]), parts[1]
    elif len(parts) == 3:
        h, m, s_ms = int(parts[0]), int(parts[1]), parts[2]
    else: return 0

    if '.' in s_ms: 
        s, ms = s_ms.split('.')
        if len(ms) > 3: ms = ms[:3]
    else: 
        s, ms = s_ms, 0
    return h * 3600000 + m * 60000 + int(s) * 1000 + int(ms)

def format_time(ms):
    h, r = divmod(ms, 3600000)
    m, r = divmod(r, 60000)
    s, ms = divmod(r, 1000)
    return f"{h:02}:{m:02}:{s:02}.{ms:03}"

def clean_text(text):
    text = text.upper()
    text = re.sub(r'[^\w\s\']', '', text)
    return text

try:
    with open(FILENAME, 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print(f"Error: File {FILENAME} not found.")
    sys.exit(1)

output = ["WEBVTT\n\n"]
i = 0

while i < len(lines):
    line = lines[i].strip()
    
    if '-->' in line:
        try:
            times = line.split(' --> ')
            
            # PARSE RAW TIMES
            raw_start = parse_time(times[0])
            raw_end = parse_time(times[1])
            
            # APPLY OFFSET
            start_ms = raw_start + TIME_OFFSET_MS
            end_ms = raw_end + TIME_OFFSET_MS
            
            # Safety Checks
            if start_ms < 0: start_ms = 0
            if end_ms <= start_ms: end_ms = start_ms + 100
            
            duration = end_ms - start_ms
            
            text_line_index = i + 1
            if text_line_index < len(lines):
                raw_text = lines[text_line_index].strip()
                clean_line = clean_text(raw_text)
                words = clean_line.split()
            else:
                words = []
            
            if not words: 
                i+=1; continue

            # SPLIT LOGIC
            chunk_size = WORDS_PER_BLOCK
            chunks = [words[j:j + chunk_size] for j in range(0, len(words), chunk_size)]
            
            if len(chunks) == 0:
                time_per_chunk = 0
            else:
                time_per_chunk = duration / len(chunks)
            
            curr = start_ms
            for chunk in chunks:
                math_end = curr + time_per_chunk
                visual_end = math_end - BUFFER_MS
                
                if visual_end <= curr: visual_end = math_end - 1
                
                output.append(f"{format_time(int(curr))} --> {format_time(int(visual_end))}\n")
                output.append(" ".join(chunk) + "\n\n")
                
                curr = math_end
            
            i += 2
        except Exception as e:
            print(f"Error parsing line {i}: {e}")
            i += 1
    else:
        if line and not line.isdigit() and "WEBVTT" not in line:
             pass
        i += 1

with open(FILENAME, 'w') as f:
    f.writelines(output)

print(f"Successfully split subtitles in: {FILENAME}")