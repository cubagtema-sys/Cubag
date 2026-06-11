-- ==========================================
-- CUBAG SUPABASE PERFORMANCE INDEXES
-- Run these in the Supabase SQL Editor
-- ==========================================

-- 1. Members Table
-- Accelerates filtering by status (active, pending, suspended, etc.)
CREATE INDEX IF NOT EXISTS idx_members_status ON members(status);
-- Accelerates login lookups
CREATE INDEX IF NOT EXISTS idx_members_email ON members(email);
-- Accelerates member type filtering
CREATE INDEX IF NOT EXISTS idx_members_type ON members(member_type);



-- 3. Payments Table
-- Accelerates dashboard payment status filtering
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
-- Accelerates queries mapping payments to specific members
CREATE INDEX IF NOT EXISTS idx_payments_member_id ON payments(member_id);
-- Accelerates transaction lookup
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments(payment_ref);

-- 4. Support Tickets Table
-- Accelerates support ticket dashboard filtering
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
-- Accelerates fetching tickets for a specific user
CREATE INDEX IF NOT EXISTS idx_support_tickets_member_id ON support_tickets(member_id);



-- 6. Announcements
-- Accelerates fetching active announcements by date
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON announcements(created_at DESC);

-- 7. Audit Logs
-- Accelerates filtering audit logs by actor (admin_id) and date
CREATE INDEX IF NOT EXISTS idx_audit_log_admin_id ON audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);
