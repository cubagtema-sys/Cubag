from config.db import get_db
from werkzeug.security import generate_password_hash

def reset_admin_password():
    email = 'admin@cubag.com'
    new_password = 'admin_password_123'
    pw_hash = generate_password_hash(new_password)

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE members SET password_hash = %s WHERE email = %s", (pw_hash, email))
            if cursor.rowcount > 0:
                conn.commit()
                print(f"Password for {email} has been reset to: {new_password}")
            else:
                print(f"User with email {email} not found.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    reset_admin_password()
