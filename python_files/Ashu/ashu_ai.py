from fastapi import FastAPI
from pydantic import BaseModel
import ollama

app = FastAPI()

# Read system prompt once
with open("/Users/ayush/Ashu/ashu.ml", "r") as f:
    system_prompt = f.read()

# Define request model
class ChatRequest(BaseModel):
    message: str

@app.post("/chat")
def chat_endpoint(req: ChatRequest):
    # Create Ollama client
    client = ollama.Client()

    # Prepare messages
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": req.message}
    ]

    # Get response
    response = client.chat(model="llama3", messages=messages)

    # Extract content from response object
    reply = response.message.content if hasattr(response, "message") else "Sorry, no reply."
    return {"reply": reply}
