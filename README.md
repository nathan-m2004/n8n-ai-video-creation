# 🎬 AI-Driven Headless Video Pipeline

An autonomous, event-driven content engine that monitors Reddit, filters stories using LLM analysis, and generates localized video content with dynamic TTS and visual effects.

Designed to operate fully headless on a VPS using **n8n**, **Docker**, and **Python**.

## 🏗 Architecture

The system follows a linear ETL (Extract, Transform, Load) pattern:

1.  **Ingestion:** Monitors RSS feeds from subreddits like `r/nosleep` and `r/RelatosDoReddit`.
2.  **Curation (Agentic AI):** A "Gatekeeper" LLM (Llama 3.1 8B) analyzes narrative structure to reject low-quality or "drama" posts, maintaining a strict quality threshold.
3.  **Transformation:**
    -   **Scripting:** Generates engagement-optimized scripts using **Llama 3 70B** via Groq.
    -   **Audio Synthesis:** Uses **Kokoro-TTS** (Local Container) with custom pitch-shifting for character voices.
    -   **Visual Assembly:** A Python wrapper orchestrates **FFmpeg** to render 1080p video with burn-in subtitles and sentiment-based VFX (glitch, shake, zoom).
4.  **Deployment:** Automatically uploads final assets to Google Drive.

## 🛠 Tech Stack

-   **Orchestration:** n8n (Self-Hosted)
-   **Core Logic:** Python 3.10 & Bash
-   **Media Processing:** FFmpeg (Complex Filter Chains)
-   **AI/LLM:** Groq API (Llama 3-70B-Versatile)
-   **TTS:** Kokoro-TTS (Dockerized)
-   **Infrastructure:** Docker Compose running on Ubuntu VPS

## ⚡ Engineering Highlights

### 1. "Gatekeeper" Logic

To prevent API waste, the pipeline uses a two-stage filtering process. First, stories are deduplicated against a local `used_stories.txt` database. Then, a smaller, faster model (Llama 3.1 8B) classifies the remaining stories, rejecting "relationship drama" or "spam" before the expensive scripting phase begins.

### 2. Parallel Asset Generation

The Python rendering engine (`generate_resources.py`) utilizes `concurrent.futures.ThreadPoolExecutor` to synthesize audio segments and align subtitles in parallel, significantly reducing render times compared to serial processing.

### 3. Dynamic Visual Effects System

The script generation step outputs "Sentiment Tags" (e.g., `[SCARED]`, `[VFX:GLITCH]`). The rendering engine parses these tags to map specific FFmpeg filters (`rgbashift`, `noise`) to exact timestamps in the final video timeline.

## 🚀 How to Run

1.  **Clone the Repo**

    ```bash
    git clone https://github.com/nathan-m2004/n8n-ai-video-creation.git
    cd n8n-ai-video-creation
    ```

2.  **Start Services (Zero Config)**
    The stack includes n8n, Postgres, and Kokoro-TTS.

    ```bash
    docker compose up -d
    ```

3.  **Import Workflow**
    Import `workflows/main_pipeline.json` into your n8n dashboard.

4.  **Asset Configuration**
    The system requires raw media files to function and a prompt customization. Populate the `media/` directory with your background gameplay, music, and SFX as described in the **Asset Configuration** section below.

## 📂 Project Structure

```text
├── extracted_scripts/    # Python & Bash logic extracted from n8n nodes (for reference/dev)
├── media/                # Mount point for raw assets (Gameplay, Music, SFX)
├── workflows/            # The n8n pipeline JSON export
├── docker-compose.yml    # Zero-config infrastructure definition
├── Dockerfile            # Custom n8n image with FFmpeg, Python, and fonts
└── extract_scripts.py    # Utility to auto-extract code from the workflow JSON
```

## 📁 Asset Configuration

The system is designed to be "Asset Agnostic," meaning you must provide the raw media files.
Before running the container, use the `media/` folder in the root directory (owner 1000:1000) and populate it with the following structure:

### Required Folder Structure

```text
media/
├── Gameplay/           # Background videos (MP4, MKV, WEBM)
│   ├── minecraft_parkour.mp4
│   └── subway_surfers.mp4
│
├── Music/             # Background ambient music (MP3)
│   ├── dark_ambient.mp3
│   └── creepy_piano.mp3
│
├── SFX/               # Sound Effects triggered by LLM tags (MP3)
│   ├── vine_boom.mp3
│   ├── metal_pipe.mp3
│   ├── scream.mp3
│   └── bruh.mp3
│
└── PERSONA/
    └── Persona/       # Avatar states (PNG) - Matches emotion tags
        ├── neutral.png
        ├── scared.png
        ├── evil.png
        └── suspicious.png
```

## 🧠 Advanced Customization (Required)

This pipeline is provided as a **Generic Template**. You **must** configure the following 4 nodes to define your channel's niche (e.g., Tech News, History Facts, True Crime, Cooking).

### 1. The Narrator Persona (`Generate Script Groq`)

-   **What it does:** Writes the video script based on your niche.
-   **How to edit:**
    -   Find the node named **`Generate Script Groq`**.
    -   Edit the **Prompt** field.
    -   Replace `[INSERT PERSONA NAME]` and `[INSERT NICHE]` with your specific details.
    -   Define the **Vocabulary Rules** (e.g., "Use simple English," "Use slang," "Be formal").

### 2. The Clickbait Engine (`Generate Title and Description`)

-   **What it does:** Generates the Title, Description, and Hashtags for your upload.
-   **How to edit:**
    -   Find the node named **`Generate Title and Description`**.
    -   Define your **Title Logic**: Replace `[INSERT THEME]` with triggers relevant to your content (e.g., _If "Spicy Food" -> Title: "TOO HOT! 🌶️"_).
    -   Set your **Mandatory Hashtags** (e.g., `#tech #news` instead of placeholders).

### 3. The Content Sources (`Subreddits`)

-   **What it does:** Defines where the bot looks for content.
-   **How to edit:**
    -   Find the node named **`Subreddits`**.
    -   This is a **Code Node**. Look for the line `const subreddits = [ ... ];`.
    -   Replace the example URLs with the RSS feeds for your target subreddits.
    -   _Tip:_ Add `.rss` or `/top.rss?t=day` to any Subreddit URL.

### 4. The Gatekeeper (`Select Story Groq`)

-   **What it does:** Filters incoming posts to select only the "Winner."
-   **How to edit:**
    -   Find the node named **`Select Story Groq`**.
    -   Update the **Selection Criteria**: Tell the AI exactly what makes a post a "Winner" for your audience.
    -   Update the **Trash Criteria**: Tell the AI what topics to strictly avoid (e.g., "Politics," "Low Effort," "Ads").





Screenshots
-
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/8e2f50b8-5652-474a-8fbd-cfbbcb7ccaa5" />
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/3e16b451-e671-40c9-b961-42f9f0151c9b" />
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/d566a264-73b0-43e3-9cdc-1f4ed77d69f7" />
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/aa2ca150-b919-4e21-ad65-51ef1ff0286b" />
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/3c0c4ff9-b618-4c55-81a8-334581ace9a2" />
<img width="1563" height="1008" alt="image" src="https://github.com/user-attachments/assets/861b5a2e-2803-4a58-8d22-04cb8e92260e" />




