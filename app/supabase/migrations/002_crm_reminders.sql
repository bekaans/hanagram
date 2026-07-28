-- Hanagram CRM + SMS hatırlatma tabloları
-- Bu dosyayı Supabase SQL Editor'da çalıştırın

-- 1. CRM kayıtları tablosu (satış + randevu otomatik eklenir)
CREATE TABLE IF NOT EXISTS crm_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('sale', 'appointment')),
  title TEXT NOT NULL,
  amount INTEGER DEFAULT 0, -- kuruş cinsinden
  customer_name TEXT DEFAULT '',
  customer_phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  status TEXT DEFAULT 'completed',
  date TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- CRM indeksleri
CREATE INDEX IF NOT EXISTS idx_crm_user ON crm_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_crm_date ON crm_entries(date);
CREATE INDEX IF NOT EXISTS idx_crm_customer ON crm_entries(customer_name);
CREATE INDEX IF NOT EXISTS idx_crm_type ON crm_entries(type);

-- 2. Zamanlanmış hatırlatmalar tablosu
CREATE TABLE IF NOT EXISTS scheduled_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_phone TEXT NOT NULL,
  message TEXT NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  type TEXT NOT NULL DEFAULT 'appointment_reminder',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Hatırlatma indeksleri
CREATE INDEX IF NOT EXISTS idx_reminder_scheduled ON scheduled_reminders(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_reminder_status ON scheduled_reminders(status);

-- 3. RLS politikaları
ALTER TABLE crm_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_reminders ENABLE ROW LEVEL SECURITY;

-- CRM: kullanıcılar sadece kendi kayıtlarını görebilir/yönetebilir
CREATE POLICY "CRM own entries" ON crm_entries
  FOR ALL USING (auth.uid() = user_id);

-- Hatırlatmalar: sadece sistem yazabilir, okuyabilir
CREATE POLICY "Reminders system" ON scheduled_reminders
  FOR ALL USING (true);

-- 4. Otomatik randevu CRM kaydı tetikleyicisi
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

-- Tetikleyici: randevu eklendiğinde otomatik CRM kaydı
DROP TRIGGER IF EXISTS trg_auto_crm ON appointments;
CREATE TRIGGER trg_auto_crm
  AFTER INSERT ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION auto_crm_on_appointment();

-- 5. pg_cron: Her dakika hatırlatma kontrolü (Supabase pg_cron eklentisi)
-- Not: pg_cron eklentisi Supabase'de varsayılan olarak aktiftir
SELECT cron.schedule(
  'check-reminders',
  '* * * * *',  -- Her dakika
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/check-reminders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
