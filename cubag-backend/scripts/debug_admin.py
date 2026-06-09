from config.db import get_db

def debug_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, email, role, member_type FROM members WHERE email = 'admin@cubag.com'")
            admin = cursor.fetchone()
            if admin:
                print(f"DEBUG: id={admin['id']}, name={admin['name']}, email={admin['email']}, role={admin['role']}, member_type={admin['member_type']}")
            else:
                print("Admin user not found")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    debug_admin()
