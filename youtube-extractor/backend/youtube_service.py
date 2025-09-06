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
