from config.db import get_db

def check_admins():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, email, role FROM members WHERE role = 'admin'")
            admins = cursor.fetchall()
            if not admins:
                print("No admin users found in the database.")
            else:
                for admin in admins:
                    print(f"Admin Found: ID: {admin['id']}, Name: {admin['name']}, Email: {admin['email']}, Role: {admin['role']}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    check_admins()
