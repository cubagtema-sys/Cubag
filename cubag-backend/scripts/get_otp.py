import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

def get_otp(email):
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        port=os.getenv('DB_PORT'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        dbname=os.getenv('DB_NAME')
    )
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT code FROM otp_codes WHERE LOWER(email) = LOWER(%s)", (email,))
            row = cursor.fetchone()
            if row:
                print(f"OTP for {email}: {row[0]}")
            else:
                print(f"No OTP found for {email}")
    finally:
        conn.close()

if __name__ == "__main__":
    get_otp("bright.whitsunday@whitsun.io")
