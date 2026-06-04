from config.db import get_db
import datetime

def fix_active_licenses():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Find active members with no license number
            cursor.execute("SELECT id, name FROM members WHERE status = 'active' AND (license_number IS NULL OR license_number = 'pending')")
            members = cursor.fetchall()

            for member in members:
                year = datetime.datetime.now().year
                new_license = f"CUBAG-LIC-{year}-{member['id']:04d}"
                cursor.execute(
                    "UPDATE members SET license_number = %s WHERE id = %s",
                    (new_license, member['id'])
                )
                print(f"Updated {member['name']} with license {new_license}")
            conn.commit()
            print("Done updating licenses.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    fix_active_licenses()
