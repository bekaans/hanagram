-- ============================================================
-- HANAGRAM — Profil İstatistikleri & Hızlı Yanıt Rozeti
-- Bu dosyayı Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- ─── Users tablosuna yeni alanlar ───
ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_stat TEXT DEFAULT 'appointments'
  CHECK (display_stat IN ('appointments', 'sales'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS avg_response_minutes INTEGER DEFAULT -1;
-- avg_response_minutes: -1 = henüz hesaplanmadı, >0 = ortalama yanıt süresi (dakika)

-- ─── Hızlı yanıt süresini hesaplayan fonksiyon ───
-- Randevu oluşturulma zamanı ile onaylanma arasındaki süre
CREATE OR REPLACE FUNCTION calculate_avg_response_time(target_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  avg_minutes INTEGER;
BEGIN
  SELECT COALESCE(
    AVG(
      EXTRACT(EPOCH FROM (
        -- onaylanan randevular için: updated_at - created_at
        COALESCE(updated_at, created_at) - created_at
      )) / 60
    )::INTEGER,
    -1
  ) INTO avg_minutes
  FROM appointments
  WHERE (created_by = target_user_id OR attendee_id = target_user_id)
    AND status = 'confirmed'
    AND updated_at IS NOT NULL;

  RETURN COALESCE(avg_minutes, -1);
END;
$$ LANGUAGE plpgsql;

-- ─── Randevu onaylandığında otomatik hesapla trigger ───
CREATE OR REPLACE FUNCTION update_avg_response_on_confirm()
RETURNS trigger AS $$
DECLARE
  target_user_id UUID;
  new_avg INTEGER;
BEGIN
  -- Sadece status confirmed olduğunda çalışsın
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    -- Hem creator hem attendee'nin response süresini güncelle
    FOR target_user_id IN SELECT unnest(ARRAY[NEW.created_by, NEW.attendee_id]) LOOP
      IF target_user_id IS NOT NULL THEN
        new_avg := calculate_avg_response_time(target_user_id);
        UPDATE users SET avg_response_minutes = new_avg WHERE auth_id = target_user_id;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_response_time ON appointments;
CREATE TRIGGER trg_update_response_time
  AFTER UPDATE OF status ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION update_avg_response_on_confirm();

-- ─── Display tercihini güncelleme fonksiyonu ───
CREATE OR REPLACE FUNCTION set_display_stat(stat_type TEXT)
RETURNS void AS $$
BEGIN
  UPDATE users SET display_stat = stat_type WHERE auth_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── RLS: Kullanıcılar kendi display_stat'ini güncelleyebilir ───
-- (mevcut Own policy zaten UPDATE izni veriyor)
