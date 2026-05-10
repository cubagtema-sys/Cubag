from config.db import get_db

def clean_surveys():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check length of cover_image and options to see if they are massive
            cursor.execute("SELECT id, title, length(cover_image) as cover_len, length(options) as opts_len FROM surveys")
            rows = cursor.fetchall()
            for r in rows:
                print(f"Survey {r['id']} ({r['title']}): cover_image length = {r['cover_len']}, options length = {r['opts_len']}")
            
            print("Clearing huge Base64 values...")
            cursor.execute("UPDATE surveys SET cover_image = NULL WHERE length(cover_image) > 500")
            cursor.execute("UPDATE surveys SET options = '[]' WHERE length(options) > 20000")
            conn.commit()
            print("Done cleaning surveys.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    clean_surveys()
