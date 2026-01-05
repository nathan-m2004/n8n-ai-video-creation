import json
import os
import re
import sys

# --- CONFIGURATION ---
INPUT_FILE = "workflows/main_pipeline.json"  # Path to your n8n export
OUTPUT_DIR = "extracted_scripts"             # Where to save the files

def clean_filename(name):
    """Sanitizes node names to be valid filenames."""
    # Replace non-alphanumeric with underscores, lower case
    clean = re.sub(r'[^a-zA-Z0-9]', '_', name).lower()
    # Remove duplicate underscores
    return re.sub(r'_+', '_', clean).strip('_')

def extract_scripts():
    # 1. Load the Workflow JSON
    try:
        with open(INPUT_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: Could not find '{INPUT_FILE}'. Export your workflow first!")
        sys.exit(1)

    # Create output directory
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"📂 Created directory: {OUTPUT_DIR}")

    nodes = data.get('nodes', [])
    count = 0

    print(f"🔍 Scanning {len(nodes)} nodes...")

    for node in nodes:
        node_type = node.get('type')
        node_name = node.get('name')
        
        # We only care about "Execute Command" nodes
        if node_type == "n8n-nodes-base.executeCommand":
            params = node.get('parameters', {})
            command = params.get('command', '')

            if not command:
                continue

            safe_name = clean_filename(node_name)
            
            # --- LOGIC 1: DETECT EMBEDDED PYTHON (Your 'Generate Resources' pattern) ---
            # Looks for: cat <<EOF > "filename.py" ... content ... EOF
            python_match = re.search(r'cat\s*<<EOF\s*>\s*"?([^"]+\.py)"?(.*?)EOF', command, re.DOTALL)
            
            if python_match:
                # We found a hidden Python script!
                py_filename_full = python_match.group(1) # e.g. /tmp/script.py
                py_content = python_match.group(2).strip()
                
                # Get just the name (script.py) not the full path
                py_filename = os.path.basename(py_filename_full)
                
                # Save the Python file
                py_path = os.path.join(OUTPUT_DIR, py_filename)
                with open(py_path, 'w', encoding='utf-8') as f:
                    f.write(py_content)
                
                print(f"   🐍 Extracted Python: {py_filename} (from '{node_name}')")
                
                # We also save the shell wrapper, just in case
                sh_path = os.path.join(OUTPUT_DIR, f"{safe_name}_wrapper.sh")
                with open(sh_path, 'w', encoding='utf-8') as f:
                    f.write(command)
                    
            # --- LOGIC 2: STANDARD SHELL SCRIPT ---
            else:
                # It's just a normal bash script
                sh_path = os.path.join(OUTPUT_DIR, f"{safe_name}.sh")
                with open(sh_path, 'w', encoding='utf-8') as f:
                    f.write(command)
                print(f"   TB Extracted Shell:  {safe_name}.sh")

            count += 1

    print(f"\n✅ Success! Extracted {count} scripts to '/{OUTPUT_DIR}'")

if __name__ == "__main__":
    extract_scripts()