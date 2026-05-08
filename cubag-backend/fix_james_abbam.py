from config.db import get_db

def fix_james():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Search for James Abbam
            cursor.execute("SELECT id, name, status, license_number FROM members WHERE name ILIKE %s", ('%James Abbam%',))
            member = cursor.fetchone()

            if member:
                print(f"Found member: {member['name']} (ID: {member['id']})")
                print(f"Current Status: {member['status']}, License: {member['license_number']}")

                # Update status to pending and clear license number if not paid
                cursor.execute("""
                    UPDATE members
                    SET status = 'pending', license_number = NULL
                    WHERE id = %s
                """, (member['id'],))
                conn.commit()
                print("Successfully updated status to 'pending' and cleared license number.")
            else:
                print("Member 'James Abbam' not found.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    fix_james()
