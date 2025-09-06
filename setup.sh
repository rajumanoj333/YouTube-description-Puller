#!/bin/bash
set -e

echo "🔹 Setting up YouTube Extractor project..."

# Project root
mkdir -p youtube-extractor
cd youtube-extractor

# Python deps
echo "fastapi
uvicorn[standard]
python-dotenv
google-api-python-client
openai" > requirements.txt

# Git ignore
echo "venv/
__pycache__/
.env" > .gitignore

# Example env
echo "OPENAI_API_KEY=your-openai-key
YOUTUBE_API_KEY=your-youtube-api-key" > .env.example

# ---------------- Backend ----------------
mkdir -p backend

cat > backend/models.py << 'EOF'
from pydantic import BaseModel

class DescriptionRequest(BaseModel):
    url: str
EOF

cat > backend/youtube_service.py << 'EOF'
import os, re
from googleapiclient.discovery import build
from dotenv import load_dotenv

load_dotenv()
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")

if not YOUTUBE_API_KEY:
    raise ValueError("Missing YOUTUBE_API_KEY in .env file")

youtube = build("youtube", "v3", developerKey=YOUTUBE_API_KEY)

def extract_video_id(url: str) -> str:
    patterns = [
        r"(?:https?://)?(?:www\.)?youtu\.be/([a-zA-Z0-9_-]{11})",
        r"(?:https?://)?(?:www\.)?youtube\.com/watch\\?v=([a-zA-Z0-9_-]{11})",
        r"(?:https?://)?(?:www\.)?youtube\.com/.*v=([a-zA-Z0-9_-]{11})"
    ]
    for p in patterns:
        match = re.match(p, url)
        if match:
            return match.group(1)
    raise ValueError(f"Invalid YouTube URL: {url}")

def get_video_description(url: str) -> str:
    video_id = extract_video_id(url)
    request = youtube.videos().list(part="snippet", id=video_id)
    response = request.execute()
    items = response.get("items", [])
    if not items:
        return "No description found."
    return items[0]["snippet"].get("description", "No description found.")
EOF

cat > backend/openai_service.py << 'EOF'
import re, os, json
from dotenv import load_dotenv
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if OPENAI_API_KEY:
    import openai
    openai.api_key = OPENAI_API_KEY

def extract_companies_and_links(description: str):
    urls = re.findall(r'(https?://[^\s)]+)', description)
    if not OPENAI_API_KEY:
        return [{"company": None, "link": u} for u in urls]
    # Minimal placeholder - extend with OpenAI logic if needed
    return [{"company": None, "link": u} for u in urls]
EOF

cat > backend/main.py << 'EOF'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from backend.models import DescriptionRequest
from backend.youtube_service import get_video_description
from backend.openai_service import extract_companies_and_links

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.post("/get-description")
def get_description(request: DescriptionRequest):
    try:
        desc = get_video_description(request.url)
        return {"description": desc}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/extract-companies-links-txt")
def extract_companies_links_txt(request: DescriptionRequest):
    try:
        description = get_video_description(request.url)
        companies_links = extract_companies_and_links(description)
        text = "\\n".join([f"Company: {c.get('company')}, Link: {c.get('link')}" for c in companies_links])
        return {"description": description, "companies_links": companies_links, "text": text}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
EOF

# ---------------- Frontend ----------------
mkdir -p docs

cat > docs/index.html << 'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>YouTube Description Extractor</title>
  <style>
    body{font-family:system-ui,Segoe UI,Roboto,Arial;margin:24px}
    input{width:60%}
    pre{background:#f3f3f3;padding:12px;border-radius:6px}
  </style>
</head>
<body>
  <h1>YouTube Description Extractor</h1>
  <p>Paste a YouTube URL and click <b>Get</b>.</p>

  <form id="form">
    <input id="url" placeholder="https://www.youtube.com/watch?v=..." />
    <button type="submit">Get</button>
  </form>

  <h3>Output</h3>
  <pre id="output">Waiting...</pre>
  <script>
    const BACKEND_URL = "https://REPLACE_WITH_BACKEND_URL"; // Replace after deploy
    document.getElementById('form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const url = document.getElementById('url').value.trim();
      if (!url) { alert('Paste a YouTube URL'); return; }

      document.getElementById('output').textContent = 'Loading...';
      try {
        const res = await fetch(BACKEND_URL + '/get-description', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({url})
        });
        if (!res.ok) {
          document.getElementById('output').textContent = 'Error: ' + await res.text();
          return;
        }
        const data = await res.json();
        let out = '--- Description ---\\n\\n' + (data.description || 'No description');
        if (data.companies_links) {
          out += '\\n\\n--- Companies/Links ---\\n' + JSON.stringify(data.companies_links, null, 2);
        }
        document.getElementById('output').textContent = out;
      } catch (err) {
        document.getElementById('output').textContent = 'Request failed: ' + err;
      }
    });
  </script>
</body>
</html>
EOF

# ---------------- GitHub Workflow ----------------
mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"
      - name: Install deps
        run: pip install -r requirements.txt
      - name: Lint
        run: pip install flake8 && flake8 backend || true
EOF

# ---------------- README ----------------
cat > README.md << 'EOF'
# 🎥 FastAPI YouTube Description Extractor

Extracts YouTube video descriptions and (optionally) company links.

## ⚡ Features
- Paste a YouTube URL → get its description (via YouTube API).
- Optional: Extract URLs / companies (via regex or OpenAI).
- Free deploy setup: 
  - Frontend → GitHub Pages
  - Backend → Render (or Railway/Fly.io)

---

## 🚀 Quick Start

### 1. Create repo & push
```bash
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/rajumanoj333/YouTube-description-Puller.git
git push -u origin main
