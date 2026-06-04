import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

def check():
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
            cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public';")
            tables = cursor.fetchall()
            print("Tables in database:")
            for t in tables:
                print(f" - {t[0]}")
                
            # Check row count for support_tickets
            try:
                cursor.execute("SELECT COUNT(*) FROM support_tickets;")
                count = cursor.fetchone()[0]
                print(f"support_tickets row count: {count}")
            except Exception as e:
                print(f"Error querying support_tickets: {e}")
                conn.rollback()

            # Check schema of support_tickets
            try:
                cursor.execute("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'support_tickets';")
                cols = cursor.fetchall()
                print("support_tickets columns:")
                for col in cols:
                    print(f"  {col[0]}: {col[1]}")
            except Exception as e:
                print(f"Error querying support_tickets columns: {e}")
                conn.rollback()

            # Let's check ticket_replies as well
            try:
                cursor.execute("SELECT COUNT(*) FROM ticket_replies;")
                count = cursor.fetchone()[0]
                print(f"ticket_replies row count: {count}")
            except Exception as e:
                print(f"Error querying ticket_replies: {e}")
                conn.rollback()
                
    except Exception as e:
        print(f"Database error: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    check()
