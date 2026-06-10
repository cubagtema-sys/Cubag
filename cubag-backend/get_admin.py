from config.db import get_db

conn = get_db()
with conn.cursor() as cursor:
    cursor.execute("SELECT email, role FROM members WHERE role IN ('admin', 'sub_admin') LIMIT 1")
    print(cursor.fetchone())
conn.close()
