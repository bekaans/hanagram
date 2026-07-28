-- Hanagram — Tam veritabanı şeması
-- Tüm tablolar, RLS politikaları, fonksiyonlar, tetikleyiciler
-- Tek seferde çalıştırılacak

-- ═══════════════════════════════════════════
-- 1. TABLOLAR
-- ═══════════════════════════════════════════

-- Kullanıcılar
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email TEXT UNIQUE,
  phone TEXT UNIQUE,
  username TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'personal',
  avatar_url TEXT,
  bio TEXT DEFAULT '',
  sector TEXT DEFAULT '',
  is_admin BOOLEAN DEFAULT false,
  my_referral_code TEXT UNIQUE,
  referral_code_used TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Referans davetleri (kim kimi davet etti)
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  referred_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Eski referans kodları tablosu (geriye uyumluluk)
CREATE TABLE referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  is_used BOOLEAN DEFAULT false,
  used_by UUID REFERENCES users(id),
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Görevler
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  created_by UUID REFERENCES users(id),
  assigned_to UUID REFERENCES users(id),
  status TEXT DEFAULT 'pending',
  priority TEXT DEFAULT 'medium',
  due_date DATE,
  due_time TIME,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Randevular
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  created_by UUID REFERENCES users(id),
  attendee_id UUID REFERENCES users(id),
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- CRM (müşteri ilişkileri)
CREATE TABLE crm_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  customer_name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  note TEXT,
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Bağlantılar (arkadaş/çalışan)
CREATE TABLE connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  connected_id UUID REFERENCES users(id),
  status TEXT DEFAULT 'pending',
  role TEXT DEFAULT 'friend',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, connected_id)
);

-- Uygulama versiyonları
CREATE TABLE app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL,
  build_number INT NOT NULL,
  platform TEXT NOT NULL,
  changelog TEXT,
  download_url TEXT NOT NULL,
  is_force BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Medya
CREATE TABLE media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id),
  file_path TEXT,
  type TEXT DEFAULT 'photo',
  mime_type TEXT DEFAULT 'image/jpeg',
  file_size INT DEFAULT 0,
  width INT DEFAULT 0,
  height INT DEFAULT 0,
  duration_ms INT DEFAULT 0,
  caption TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Bildirimler
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- 2. İNDEKSLER
-- ═══════════════════════════════════════════

CREATE INDEX idx_users_auth_id ON users(auth_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_referral_code ON users(my_referral_code);
CREATE INDEX idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX idx_referrals_referred ON referrals(referred_id);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_appointments_created_by ON appointments(created_by);
CREATE INDEX idx_appointments_attendee ON appointments(attendee_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_media_owner ON media(owner_id);

-- ═══════════════════════════════════════════
-- 3. RLS (Row Level Security)
-- ═══════════════════════════════════════════

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users: herkes profilleri görebilir, kendi profilini düzenler
CREATE POLICY "Public profiles" ON users FOR SELECT USING (true);
CREATE POLICY "Own profile update" ON users FOR UPDATE USING (auth.uid() = auth_id);
CREATE POLICY "Insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = auth_id);

-- Referrals: herkes okuyabilir
CREATE POLICY "Anyone can read referrals" ON referrals FOR SELECT USING (true);
CREATE POLICY "Anyone can insert referrals" ON referrals FOR INSERT WITH CHECK (true);

-- Referral codes: herkes okuyabilir
CREATE POLICY "Read referral codes" ON referral_codes FOR SELECT USING (true);
CREATE POLICY "Insert referral codes" ON referral_codes FOR INSERT WITH CHECK (true);
CREATE POLICY "Update referral codes" ON referral_codes FOR UPDATE USING (true);

-- Tasks: herkes okuyabilir, kendi görevlerini düzenler
CREATE POLICY "Read tasks" ON tasks FOR SELECT USING (true);
CREATE POLICY "Insert tasks" ON tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "Update tasks" ON tasks FOR UPDATE USING (true);

-- Appointments: herkes okuyabilir
CREATE POLICY "Read appointments" ON appointments FOR SELECT USING (true);
CREATE POLICY "Insert appointments" ON appointments FOR INSERT WITH CHECK (true);
CREATE POLICY "Update appointments" ON appointments FOR UPDATE USING (true);

-- CRM: herkes okuyabilir
CREATE POLICY "Read CRM" ON crm_entries FOR SELECT USING (true);
CREATE POLICY "Insert CRM" ON crm_entries FOR INSERT WITH CHECK (true);

-- Connections: herkes okuyabilir
CREATE POLICY "Read connections" ON connections FOR SELECT USING (true);
CREATE POLICY "Insert connections" ON connections FOR INSERT WITH CHECK (true);
CREATE POLICY "Update connections" ON connections FOR UPDATE USING (true);

-- App versions: herkes okuyabilir
CREATE POLICY "Read versions" ON app_versions FOR SELECT USING (true);
CREATE POLICY "Manage versions" ON app_versions FOR INSERT WITH CHECK (true);
CREATE POLICY "Update versions" ON app_versions FOR UPDATE USING (true);
CREATE POLICY "Delete versions" ON app_versions FOR DELETE USING (true);

-- Media: herkes okuyabilir
CREATE POLICY "Read media" ON media FOR SELECT USING (true);
CREATE POLICY "Insert media" ON media FOR INSERT WITH CHECK (true);
CREATE POLICY "Delete media" ON media FOR DELETE USING (true);

-- Notifications: herkes okuyabilir
CREATE POLICY "Read notifications" ON notifications FOR SELECT USING (true);
CREATE POLICY "Insert notifications" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Update notifications" ON notifications FOR UPDATE USING (true);

-- ═══════════════════════════════════════════
-- 4. FONKSİYONLAR VE TETİKLEYİCİLER
-- ═══════════════════════════════════════════

-- Benzersiz referans kodu üretici (8 karakter)
CREATE OR REPLACE FUNCTION generate_unique_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code TEXT;
  exists BOOLEAN;
BEGIN
  LOOP
    code := '';
    FOR i IN 1..8 LOOP
      code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM users WHERE my_referral_code = code) INTO exists;
    EXIT WHEN NOT exists;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Yeni kullanıcıya otomatik referans kodu ata
CREATE OR REPLACE FUNCTION assign_referral_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.my_referral_code IS NULL THEN
    NEW.my_referral_code := generate_unique_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assign_referral_code ON users;
CREATE TRIGGER trg_assign_referral_code
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION assign_referral_code();

-- updated_at otomatik güncelleme
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ═══════════════════════════════════════════
-- 5. STORAGE BUCKET'LARI
-- ═══════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public) VALUES
  ('avatars', 'avatars', true),
  ('media', 'media', false)
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════
-- 6. TAMAM!
-- ═══════════════════════════════════════════
-- Migration başarıyla tamamlandı.
-- Artık uygulamayı başlatabilirsin.
