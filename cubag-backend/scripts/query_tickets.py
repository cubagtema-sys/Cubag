import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

def query():
    db_url = os.getenv('DATABASE_URL')
    if db_url:
        conn = psycopg2.connect(db_url)
    else:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', 5432)),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            dbname=os.getenv('DB_NAME', 'Customs')
        )
    
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, email, role, status FROM members;")
            members = cursor.fetchall()
            print("Members in database:")
            for m in members:
                print(f" - ID: {m[0]}, Name: {m[1]}, Email: {m[2]}, Role: {m[3]}, Status: {m[4]}")
                
            cursor.execute("SELECT t.id, t.member_id, t.subject, t.status, t.deleted_at, m.name FROM support_tickets t LEFT JOIN members m ON t.member_id = m.id;")
            tickets = cursor.fetchall()
            print("\nSupport Tickets in database:")
            for t in tickets:
                print(f" - ID: {t[0]}, MemberID: {t[1]} ({t[5]}), Subject: {t[2]}, Status: {t[3]}, DeletedAt: {t[4]}")
                
            cursor.execute("SELECT id, ticket_id, author, message FROM ticket_replies;")
            replies = cursor.fetchall()
            print("\nReplies in database:")
            for r in replies:
                print(f" - ID: {r[0]}, TicketID: {r[1]}, Author: {r[2]}, Message: {r[3]}")
                
    except Exception as e:
        print(f"Database error: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    query()
