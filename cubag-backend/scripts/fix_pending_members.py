from config.db import get_db

conn = get_db()
cur = conn.cursor()
cur.execute("UPDATE members SET status='active' WHERE status='pending'")
conn.commit()
print(f"Updated {cur.rowcount} members from pending to active")
conn.close()
