from config.db import get_db

def check():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT name, email, status, license_number, license_expiry_date FROM members WHERE email = 'admin@cubag.com'")
            user = cursor.fetchone()
            print(user)
    finally:
        conn.close()

if __name__ == "__main__":
    check()
