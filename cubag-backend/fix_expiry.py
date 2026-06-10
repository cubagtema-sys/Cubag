from config.db import get_db
import datetime

def fix():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Find paid payments related to license that didn't set expiry
            cursor.execute("""
                SELECT p.id, p.member_id, p.description, m.license_expiry_date
                FROM payments p
                JOIN members m ON p.member_id = m.id
                WHERE LOWER(p.status) = 'paid'
                  AND (LOWER(p.description) LIKE '%license%' OR LOWER(p.description) LIKE '%renewal%')
                  AND m.license_expiry_date IS NULL
            """)
            rows = cursor.fetchall()
            print(f"Found {len(rows)} users who paid but have no expiry.")
            
            for r in rows:
                print("Fixing member", r['member_id'], "payment", r['id'], "desc:", r['description'])
                now = datetime.datetime.now()
                expiry_date = now + datetime.timedelta(days=365)
                cursor.execute("""
                    UPDATE members 
                    SET license_expiry_date = %s, status = 'active'
                    WHERE id = %s
                """, (expiry_date.date(), r['member_id']))
        conn.commit()
        print("Fixed!")
    finally:
        conn.close()

if __name__ == '__main__':
    fix()
