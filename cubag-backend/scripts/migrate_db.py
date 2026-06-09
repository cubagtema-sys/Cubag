from config.db import init_db

if __name__ == "__main__":
    print("Running database migration...")
    init_db()
    print("Migration complete.")
