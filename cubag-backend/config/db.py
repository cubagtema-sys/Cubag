import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

def get_db():
    """Get a new database connection, supporting DATABASE_URL or individual params."""
    db_url = os.getenv('DATABASE_URL')
    if db_url:
        return psycopg2.connect(db_url, cursor_factory=RealDictCursor)

    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=int(os.getenv('DB_PORT', 5432)),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', ''),
        dbname=os.getenv('DB_NAME', 'Customs'),
        cursor_factory=RealDictCursor
    )

def init_db():
    """Initialize the database tables if they don't exist."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Members / Users table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS members (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(150) NOT NULL,
                    email VARCHAR(150) UNIQUE NOT NULL,
                    phone VARCHAR(30),
                    company VARCHAR(200),
                    license_number VARCHAR(100),
                    agency_code VARCHAR(100),
                    port_of_operation VARCHAR(100) DEFAULT 'Tema Port',
                    member_type VARCHAR(50) DEFAULT 'Individual Broker',
                    password_hash VARCHAR(255) NOT NULL,
                    status VARCHAR(20) DEFAULT 'pending',
                    email_verified BOOLEAN DEFAULT FALSE,
                    verification_token VARCHAR(255),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Ensure columns exist if table was already created
            cursor.execute("""
                ALTER TABLE members 
                ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS verification_token VARCHAR(255),
                ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255),
                ADD COLUMN IF NOT EXISTS license_expiry_date DATE;
            """)

            # OTP Codes table for pre-registration verification
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS otp_codes (
                    email VARCHAR(150) PRIMARY KEY,
                    code VARCHAR(10) NOT NULL,
                    type VARCHAR(50) DEFAULT 'email_verification',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'email_verification';
            """)

            # Announcements
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS announcements (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    body TEXT,
                    category VARCHAR(100) DEFAULT 'General',
                    posted_by VARCHAR(150),
                    deleted_at TIMESTAMP DEFAULT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                ALTER TABLE announcements ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP DEFAULT NULL;
            """)

            # Tasks / Compliance
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    member_id INT,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    due_date DATE,
                    done BOOLEAN DEFAULT FALSE,
                    priority VARCHAR(20) DEFAULT 'medium',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (member_id) REFERENCES members(id)
                )
            """)

            # Events
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    date DATE,
                    time VARCHAR(50),
                    location VARCHAR(255),
                    capacity INT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            cursor.execute("""
                ALTER TABLE events ADD COLUMN IF NOT EXISTS capacity INT;
            """)

            # Payments / Dues
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS payments (
                    id SERIAL PRIMARY KEY,
                    member_id INT,
                    amount DECIMAL(10,2),
                    description VARCHAR(255),
                    status VARCHAR(20) DEFAULT 'pending',
                    due_date DATE,
                    paid_at TIMESTAMP NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (member_id) REFERENCES members(id)
                )
            """)

            # Surveys
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS surveys (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    type VARCHAR(20) DEFAULT 'Survey',
                    expiry DATE,
                    active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                ALTER TABLE surveys
                ADD COLUMN IF NOT EXISTS deadline DATE,
                ADD COLUMN IF NOT EXISTS options TEXT,
                ADD COLUMN IF NOT EXISTS cover_image TEXT;
            """)

            # Survey Responses
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS survey_responses (
                    id SERIAL PRIMARY KEY,
                    survey_id INT NOT NULL,
                    member_id INT NOT NULL,
                    answers TEXT,
                    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE (survey_id, member_id),
                    FOREIGN KEY (survey_id) REFERENCES surveys(id),
                    FOREIGN KEY (member_id) REFERENCES members(id)
                )
            """)

            # Schedules
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS schedules (
                    id SERIAL PRIMARY KEY,
                    type VARCHAR(50) NOT NULL,
                    container VARCHAR(100),
                    vessel VARCHAR(150),
                    cargo VARCHAR(150),
                    date VARCHAR(100),
                    port VARCHAR(150),
                    status VARCHAR(50) DEFAULT 'Scheduled',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Add transaction info, role and profile photo to members if not exists
            cursor.execute("""
                ALTER TABLE members 
                ADD COLUMN IF NOT EXISTS payment_ref VARCHAR(255),
                ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'member',
                ADD COLUMN IF NOT EXISTS profile_photo TEXT,
                ADD COLUMN IF NOT EXISTS fcm_token TEXT;
            """)

            # Add movement-specific columns to schedules if not exists
            cursor.execute("""
                ALTER TABLE schedules
                ADD COLUMN IF NOT EXISTS origin VARCHAR(150),
                ADD COLUMN IF NOT EXISTS destination VARCHAR(150),
                ADD COLUMN IF NOT EXISTS progress INT DEFAULT 0;
            """)

            # Add soft-delete to support tickets (table may not exist yet)
            try:
                cursor.execute("""
                    ALTER TABLE support_tickets
                    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL;
                """)
            except Exception:
                conn.rollback()  # rollback just this failed ALTER

            # Task submission tracking
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS task_submissions (
                    id SERIAL PRIMARY KEY,
                    task_id INT NOT NULL,
                    member_id INT NOT NULL,
                    completion_note TEXT,
                    admin_verified BOOLEAN DEFAULT FALSE,
                    admin_verified_at TIMESTAMP NULL,
                    admin_notes TEXT,
                    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (task_id) REFERENCES tasks(id),
                    FOREIGN KEY (member_id) REFERENCES members(id)
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS task_submission_files (
                    id SERIAL PRIMARY KEY,
                    submission_id INT NOT NULL,
                    filename VARCHAR(255),
                    original_name VARCHAR(255),
                    file_type VARCHAR(100),
                    file_size INT,
                    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (submission_id) REFERENCES task_submissions(id)
                )
            """)

            # News / Blog
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS news_blog (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    category VARCHAR(100) DEFAULT 'General',
                    content TEXT,
                    image_url TEXT,
                    author VARCHAR(100) DEFAULT 'CUBAG Admin',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

        conn.commit()
        print("[OK] Database tables initialised successfully.")
    except Exception as e:
        print(f"[ERROR] DB init error: {e}")
    finally:
        conn.close()
