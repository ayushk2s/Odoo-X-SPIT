from fastapi import FastAPI
from pydantic import BaseModel
import ollama

app = FastAPI()



# Define request model
class ChatRequest(BaseModel):
    message: str

@app.post("/chat")
def chat_endpoint(req: ChatRequest):
    client = ollama.Client()

    messages = [
        {"role": "user", "content": req.message}
    ]

    response = client.chat(model="ashu", messages=messages)

    reply = response.message.content if hasattr(response, "message") else "Sorry, no reply."
    return {"reply": reply}

# If you want to run this on the local server 
# install fastapi with uvicorn package and write the code in the terminal
# but path should be of this file
# uvicorn ashu_ai:app --reload --host 0.0.0.0 --port 8000

# you can change host and post if not free in your device 🤪
# if you want to run on cloudflared than do by your self 😂