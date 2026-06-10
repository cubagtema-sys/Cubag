import sys
from config.db import get_db
from werkzeug.security import generate_password_hash

try:
    conn = get_db()
    cursor = conn.cursor()
    # explicitly specify pbkdf2 since scrypt is missing in this python build
    hashed_pw = generate_password_hash('password123', method='pbkdf2:sha256')
    cursor.execute('UPDATE members SET password_hash = %s WHERE email = %s', (hashed_pw, 'admin@cubag.com'))
    conn.commit()
    print("Password for admin@cubag.com updated to 'password123'")
except Exception as e:
    print(f"Error: {e}")
finally:
    if 'cursor' in locals():
        cursor.close()
    if 'conn' in locals():
        conn.close()
