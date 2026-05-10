from config.db import get_db

def check_materials():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, title, file_url FROM public_materials")
            rows = cursor.fetchall()
            print(f"Found {len(rows)} materials:")
            for row in rows:
                print(f"ID: {row['id']} | Title: {row['title']}")
                print(f"URL: '{row['file_url']}'")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    check_materials()
