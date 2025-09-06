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
