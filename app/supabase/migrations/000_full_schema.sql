-- ============================================================
-- HANAGRAM — Tam Veritabanı Şeması
-- Bu dosyayı Supabase SQL Editor'da çalıştırın.
-- 002_crm_reminders.sql ÖNCE bu dosyayı çalıştırın.
-- ============================================================

-- ─── 1. KULLANICILAR ───
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) UNIQUE,
  email TEXT UNIQUE,
  phone TEXT UNIQUE,
  username TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'personal'
    CHECK (account_type IN ('personal', 'business', 'creator')),
  avatar_url TEXT,
  bio TEXT DEFAULT '',
  sector TEXT DEFAULT '',
  referral_code_used TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_auth_id ON users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- ─── 2. REFERANS KODLARI ───
CREATE TABLE IF NOT EXISTS referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  is_used BOOLEAN DEFAULT false,
  used_by UUID REFERENCES users(id),
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_codes_unused ON referral_codes(is_used) WHERE is_used = false;

-- 100 başlangıç kodu üretme fonksiyonu
CREATE OR REPLACE FUNCTION generate_referral_codes(count INT)
RETURNS void AS $$
DECLARE
  i INT;
  new_code TEXT;
BEGIN
  FOR i IN 1..count LOOP
    LOOP
      new_code := upper(substring(md5(random()::text) from 1 for 8));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM referral_codes WHERE code = new_code);
    END LOOP;
    INSERT INTO referral_codes (code) VALUES (new_code);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- İlk 100 kodu üret (sadece tablo boşsa)
DO $$
BEGIN
  IF (SELECT count(*) FROM referral_codes) = 0 THEN
    PERFORM generate_referral_codes(100);
  END IF;
END $$;

-- Otomatik kod yenileme fonksiyonu (90'ın altına düşünce)
CREATE OR REPLACE FUNCTION check_and_refill_codes()
RETURNS trigger AS $$
DECLARE
  available_count INT;
BEGIN
  SELECT count(*) INTO available_count
  FROM referral_codes WHERE is_used = false;

  IF available_count < 90 THEN
    PERFORM generate_referral_codes(100 - available_count);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tetikleyici: kod kullanıldığında otomatik yenile
DROP TRIGGER IF EXISTS trg_refill_codes ON referral_codes;
CREATE TRIGGER trg_refill_codes
  AFTER UPDATE OF is_used ON referral_codes
  FOR EACH ROW
  WHEN (NEW.is_used = true)
  EXECUTE FUNCTION check_and_refill_codes();

-- ─── 3. ARKADAŞLAR / BAĞLANTILAR ───
CREATE TABLE IF NOT EXISTS connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  connected_id UUID REFERENCES users(id) NOT NULL,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  role TEXT DEFAULT 'friend'
    CHECK (role IN ('friend', 'employee', 'employer')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, connected_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_user ON connections(user_id);
CREATE INDEX IF NOT EXISTS idx_connections_connected ON connections(connected_id);

-- ─── 4. İŞLETME GRUPLARI ───
CREATE TABLE IF NOT EXISTS business_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 5. GRUP ÜYELERİ ───
CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES business_groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) NOT NULL,
  role TEXT DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- ─── 6. GÖREVLER ───
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  created_by UUID REFERENCES users(id) NOT NULL,
  assigned_to UUID REFERENCES users(id),
  group_id UUID REFERENCES business_groups(id),
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'rejected')),
  priority TEXT DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date DATE,
  due_time TIME,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);

-- ─── 7. RANDEVULAR ───
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  created_by UUID REFERENCES users(id) NOT NULL,
  attendee_id UUID REFERENCES users(id),
  group_id UUID REFERENCES business_groups(id),
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(date);
CREATE INDEX IF NOT EXISTS idx_appointments_created_by ON appointments(created_by);
CREATE INDEX IF NOT EXISTS idx_appointments_attendee ON appointments(attendee_id);

-- ─── 8. CRM KAYITLARI ───
CREATE TABLE IF NOT EXISTS crm_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('sale', 'appointment')),
  title TEXT NOT NULL,
  amount INTEGER DEFAULT 0,
  customer_name TEXT DEFAULT '',
  customer_phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  status TEXT DEFAULT 'completed',
  date TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_user ON crm_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_crm_date ON crm_entries(date);
CREATE INDEX IF NOT EXISTS idx_crm_customer ON crm_entries(customer_name);

-- Otomatik randevu → CRM kaydı
CREATE OR REPLACE FUNCTION auto_crm_on_appointment()
RETURNS trigger AS $$
BEGIN
  INSERT INTO crm_entries (user_id, type, title, amount, customer_name, customer_phone, status, date)
  VALUES (
    NEW.created_by,
    'appointment',
    NEW.title,
    0,
    '',
    '',
    'pending',
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_crm ON appointments;
CREATE TRIGGER trg_auto_crm
  AFTER INSERT ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION auto_crm_on_appointment();

-- ─── 9. UYGULAMA VERSİYONLARI ───
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL,
  build_number INT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'macos', 'windows', 'web')),
  changelog TEXT DEFAULT '',
  download_url TEXT NOT NULL,
  is_force BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_versions_platform ON app_versions(platform);
CREATE INDEX IF NOT EXISTS idx_versions_active ON app_versions(is_active) WHERE is_active = true;

-- ─── 10. STORAGE BUCKET'LARI ───
INSERT INTO storage.buckets (id, name, public) VALUES
  ('avatars', 'avatars', true),
  ('media', 'media', false)
ON CONFLICT (id) DO NOTHING;

-- Avatar yükleme politikası (herkes okuyabilir, sadece sahibi yazabilir)
CREATE POLICY "Avatar public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Avatar owner upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Medya yükleme politikası
CREATE POLICY "Media owner upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'media' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ─── 11. RLS (ROW LEVEL SECURITY) ───
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Kullanıcılar: herkes profilleri görebilir, sadece kendi profilini düzenler
CREATE POLICY "Users public read" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users update own" ON users
  FOR UPDATE USING (auth.uid() = auth_id);

CREATE POLICY "Users insert own" ON users
  FOR INSERT WITH CHECK (auth.uid() = auth_id);

-- Referans kodları: kullanılmamış olanları herkes görebilir (kayıt için)
CREATE POLICY "Referral codes read unused" ON referral_codes
  FOR SELECT USING (is_used = false);

-- Bağlantılar: kendi bağlantılarını yönet
CREATE POLICY "Connections own" ON connections
  FOR ALL USING (auth.uid() = user_id OR auth.uid() = connected_id);

-- İşletme grupları: sadece sahibi
CREATE POLICY "Groups owner" ON business_groups
  FOR ALL USING (auth.uid() = owner_id);

-- Grup üyeleri: gruba ait olanlar
CREATE POLICY "Group members own" ON group_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM business_groups
      WHERE business_groups.id = group_members.group_id
      AND business_groups.owner_id = auth.uid()
    )
    OR user_id = (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  );

-- Görevler: oluşturan veya atanan kişi görebilir
CREATE POLICY "Tasks own" ON tasks
  FOR ALL USING (
    created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
    OR assigned_to = (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- Randevular: oluşturan veya katılımcı görebilir
CREATE POLICY "Appointments own" ON appointments
  FOR ALL USING (
    created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
    OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- CRM: sadece kendi kayıtları
CREATE POLICY "CRM own" ON crm_entries
  FOR ALL USING (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- Versiyonlar: herkes okuyabilir (güncelleme kontrolü için)
CREATE POLICY "Versions public read" ON app_versions
  FOR SELECT USING (true);

-- ─── 12. YARDIMCI FONKSİYONLAR ───

-- Kullanıcı adı benzersiz mi kontrol et
CREATE OR REPLACE FUNCTION check_username_unique(uname TEXT)
RETURNS boolean AS $$
BEGIN
  RETURN NOT EXISTS (SELECT 1 FROM users WHERE username = uname);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS bypass for admin (service_role key kullanarak admin paneli erişir)
-- Admin paneli service_role key ile bağlandığından RLS otomatik bypass edilir.

-- ─── 13. RANDEVU HATIRLATMA (1 gün önceden) ───

-- Yarınki randevuları bul ve bildirim tablosuna yaz
CREATE OR REPLACE FUNCTION schedule_appointment_reminders()
RETURNS void AS $$
DECLARE
  appt RECORD;
  recipient RECORD;
  tomorrow DATE := CURRENT_DATE + INTERVAL '1 day';
BEGIN
  -- Yarınki randevuları bul
  FOR appt IN
    SELECT a.*, u.full_name as creator_name
    FROM appointments a
    JOIN users u ON u.id = a.created_by
    WHERE a.date = tomorrow
    AND a.status != 'cancelled'
  LOOP
    -- Randevuyu oluşturan kişiye hatırlatma
    INSERT INTO scheduled_reminders (recipient_phone, message, scheduled_for, type, status)
    VALUES (
      '',
      'Yarın ' || appt.start_time || ' saatinde "' || appt.title || '" randevunuz var.',
      NOW(),
      'appointment_reminder',
      'pending'
    );

    -- Katılımcı varsa ona da hatırlatma
    IF appt.attendee_id IS NOT NULL THEN
      INSERT INTO scheduled_reminders (recipient_phone, message, scheduled_for, type, status)
      VALUES (
        '',
        'Yarın ' || appt.start_time || ' saatinde "' || appt.title || '" randevunuz var.',
        NOW(),
        'appointment_reminder',
        'pending'
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- pg_cron: Her gün saat 20:00'de yarınki randevuları kontrol et
-- Not: pg_cron ve net.http_post eklentisi Supabase'de aktiftir
SELECT cron.schedule(
  'daily-appointment-reminder',
  '0 20 * * *',  -- Her gün 20:00
  $$
  SELECT schedule_appointment_reminders();
  $$
);

-- ─── TAMAM ───
-- Bu dosyayı çalıştırın, ardından uygulamayı başlatın.
-- İlk 100 referans kodu otomatik üretilecek.
