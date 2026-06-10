import requests

BASE_URL = "https://cubag-backend.onrender.com/api"

# Let's get the list of events first to find a valid event_id
try:
    # This might require auth. Wait, is events list public or admin only?
    # Let's try hitting a public endpoint, or we can use admin token if we have one.
    pass
except Exception as e:
    print(e)
