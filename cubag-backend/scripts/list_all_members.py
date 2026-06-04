from config.db import get_db

def list_members():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, email, role, status, license_number FROM members")
            members = cursor.fetchall()
            print(f"Total members in DB: {len(members)}")
            for m in members:
                print(f"ID: {m['id']}, Name: {m['name']}, Email: {m['email']}, Role: {m['role']}, Status: {m['status']}, License: {m['license_number']}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    list_members()
