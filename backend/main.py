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
