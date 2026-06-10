from config.db import get_db
import sys

def check():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check payments that are paid but user has no license_expiry_date
            cursor.execute("""
                SELECT p.id, p.description, p.status, m.id, m.name, m.email, m.status, m.license_expiry_date
                FROM payments p
                JOIN members m ON p.member_id = m.id
                WHERE LOWER(p.status) = 'paid'
                ORDER BY p.id DESC LIMIT 10
            """)
            for row in cursor.fetchall():
                print(dict(row))
    finally:
        conn.close()

if __name__ == '__main__':
    check()
