import os
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import ThreadedConnectionPool
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

load_dotenv()

# Connection pool instance
_pool = None

class PooledConnection:
    """A simple wrapper to return connections to the pool when close() is called."""
    def __init__(self, conn, pool):
        self._conn = conn
        self._pool = pool

    def __getattr__(self, name):
        return getattr(self._conn, name)

    def close(self):
        if self._pool:
            try:
                self._pool.putconn(self._conn)
            except Exception as e:
                logger.warning(f"Error returning connection to pool: {e}")
        else:
            self._conn.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

def get_db():
    """Get a database connection from the pool."""
    global _pool
    if _pool is None:
        db_url = os.getenv('DATABASE_URL')
        if db_url:
            _pool = ThreadedConnectionPool(1, 20, db_url, cursor_factory=RealDictCursor)
        else:
            _pool = ThreadedConnectionPool(
                1, 20,
                host=os.getenv('DB_HOST', 'localhost'),
                port=int(os.getenv('DB_PORT', 5432)),
                user=os.getenv('DB_USER', 'postgres'),
                password=os.getenv('DB_PASSWORD', ''),
                dbname=os.getenv('DB_NAME', 'Customs'),
                sslmode='require',
                cursor_factory=RealDictCursor
            )

    return PooledConnection(_pool.getconn(), _pool)

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
                    password_hash TEXT NOT NULL,
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
                    payment_ref VARCHAR(255),
                    due_date DATE,
                    paid_at TIMESTAMP NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (member_id) REFERENCES members(id)
                )
            """)

            # Ensure payment_ref column exists on older databases
            cursor.execute("""
                ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_ref VARCHAR(255);
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
                ADD COLUMN IF NOT EXISTS fcm_token TEXT,
                ADD COLUMN IF NOT EXISTS compliance_score INT DEFAULT 100,
                ADD COLUMN IF NOT EXISTS star_rating DECIMAL(3,2) DEFAULT 5.0,
                ADD COLUMN IF NOT EXISTS manual_review_score INT DEFAULT 10;
            """)

            # Add movement-specific columns to schedules if not exists
            cursor.execute("""
                ALTER TABLE schedules
                ADD COLUMN IF NOT EXISTS origin VARCHAR(150),
                ADD COLUMN IF NOT EXISTS destination VARCHAR(150),
                ADD COLUMN IF NOT EXISTS progress INT DEFAULT 0;
            """)

            # Support tickets table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS support_tickets (
                    id VARCHAR(50) PRIMARY KEY,
                    member_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    subject VARCHAR(255) NOT NULL,
                    message TEXT,
                    status VARCHAR(50) DEFAULT 'open',
                    priority VARCHAR(50) DEFAULT 'medium',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    deleted_at TIMESTAMP NULL
                )
            """)

            # Ticket replies table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS ticket_replies (
                    id SERIAL PRIMARY KEY,
                    ticket_id VARCHAR(50) NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
                    author VARCHAR(150) NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # License renewal/expiry history tracking
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS license_history (
                    id SERIAL PRIMARY KEY,
                    member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    license_number VARCHAR(100),
                    start_date DATE,
                    expiry_date DATE,
                    duration_label VARCHAR(50),
                    archived_at TIMESTAMP DEFAULT NOW()
                )
            """)

            # Add soft-delete to support tickets (table may not exist yet)
            try:
                cursor.execute("""
                    ALTER TABLE support_tickets
                    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL,
                    ADD COLUMN IF NOT EXISTS priority VARCHAR(50) DEFAULT 'medium';
                """)
            except Exception as e:
                logger.exception("Failed to alter support_tickets: %s", e)
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

            # Tracking which user has read which announcement (Cross-device sync)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS announcement_reads (
                    member_id INT NOT NULL,
                    announcement_id INT NOT NULL,
                    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (member_id, announcement_id),
                    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
                    FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE
                )
            """)

            # Rating history tracking table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS member_rating_history (
                    id SERIAL PRIMARY KEY,
                    member_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    compliance_score INT NOT NULL,
                    star_rating DECIMAL(3,2) NOT NULL,
                    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Support personal member-specific notifications inside the announcements table
            cursor.execute("""
                ALTER TABLE announcements ADD COLUMN IF NOT EXISTS member_id INT DEFAULT NULL REFERENCES members(id) ON DELETE CASCADE;
            """)

            # Audit log for tracking admin actions (Make admin_id nullable to avoid FK issues on deletion)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS audit_log (
                    id SERIAL PRIMARY KEY,
                    admin_id INT REFERENCES members(id) ON DELETE SET NULL,
                    action VARCHAR(100) NOT NULL,
                    target_type VARCHAR(50),
                    target_id INT,
                    target_name VARCHAR(255),
                    details TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Ensure it's nullable if already exists
            cursor.execute("ALTER TABLE audit_log ALTER COLUMN admin_id DROP NOT NULL")

            # Platform-wide configuration (fees, bank accounts, payment settings, etc.)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS platform_settings (
                    id SERIAL PRIMARY KEY,
                    config_key VARCHAR(100) UNIQUE NOT NULL,
                    config_value JSONB,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Sub-admin permissions — one row per (sub_admin, module) pair
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sub_admin_permissions (
                    id SERIAL PRIMARY KEY,
                    sub_admin_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    permission_key VARCHAR(60) NOT NULL,
                    granted BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE (sub_admin_id, permission_key)
                )
            """)

            # Messaging table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS messages (
                    id SERIAL PRIMARY KEY,
                    sender_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    receiver_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # ── Performance Indexes ──────────────────────────────────────────
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_members_status ON members(status)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_members_role ON members(role)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_payments_member_id ON payments(member_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_announcements_deleted_at ON announcements(deleted_at) WHERE deleted_at IS NULL")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id)")

        conn.commit()
        logger.info("[OK] Database tables initialised successfully.")
    except Exception as e:
        logger.exception("[ERROR] DB init error: %s", e)
    finally:
        conn.close()
