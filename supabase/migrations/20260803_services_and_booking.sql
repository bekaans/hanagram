-- Hanagram — Hizmetler + Randevu Alma Altyapısı
-- 2026-08-01
--
-- Bu migration ÜÇ boşluğu kapatır:
--   1. `services` tablosu HİÇ YOKTU — profildeki hizmet listesi `service_model.dart`
--      içindeki hardcoded `sampleCategories`'den geliyordu (her işletme aynı sahte
--      "Lazer Epilasyon/Cilt Bakımı/Saç Bakımı" listesini gösteriyordu).
--   2. `working_hours` tablosu YOKTU — "en yakın boş saat" hesaplanamıyordu.
--   3. `appointments` tablosunda randevu TÜRÜ (ön görüşme / işlem) ayrımı yoktu.
--
-- Ayrıca mevcut bir RLS hatasını düzeltir (aşağıda 5. bölüm).
--
-- Idempotent: tekrar çalıştırılabilir.

-- ─── 1. Hizmetler ───
-- Tek seviye: her hizmet kendi satırı (Kaan'ın tarifi: "işlemler alt alta
-- bölümlensin"). `category` alanı ileride gruplama istenirse şema değişikliği
-- gerektirmesin diye şimdiden var, şu an kullanılmıyor.

CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price INT DEFAULT 0,                -- kuruş cinsinden (accounting_entries ile tutarlı)
  duration_minutes INT DEFAULT 30,    -- randevu slot hesabı bunu kullanır
  category TEXT DEFAULT '',
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_services_business ON services(business_id);

ALTER TABLE services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "services_select" ON services;
DROP POLICY IF EXISTS "services_insert_own" ON services;
DROP POLICY IF EXISTS "services_update_own" ON services;
DROP POLICY IF EXISTS "services_delete_own" ON services;

-- Herkes okuyabilir: hizmetler profilde herkese açık gösteriliyor.
CREATE POLICY "services_select" ON services FOR SELECT USING (true);
CREATE POLICY "services_insert_own" ON services FOR INSERT WITH CHECK (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "services_update_own" ON services FOR UPDATE USING (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "services_delete_own" ON services FOR DELETE USING (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ─── 2. Hizmet medyası ───
-- Ayrı tablo AÇILMADI: mevcut `media` tablosu (yükleme/storage hattı zaten
-- `media_service.dart`'ta çalışıyor) yeniden kullanılıyor, sadece hangi hizmete
-- ait olduğunu söyleyen bir kolon ekleniyor. NULL = hizmete bağlı olmayan
-- normal medya (mevcut davranış bozulmuyor).

ALTER TABLE media ADD COLUMN IF NOT EXISTS service_id UUID
  REFERENCES services(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_media_service ON media(service_id);

-- ─── 3. Çalışma saatleri ───
-- weekday: 0=Pazar, 1=Pazartesi ... 6=Cumartesi (Dart'ın DateTime.weekday'i
-- 1=Pzt..7=Paz olduğu için servis katmanında çevrilecek — orada belgelenecek).
-- Kaydı OLMAYAN işletme için varsayılan saat UYDURULMAZ: randevu ekranı dürüstçe
-- "bu işletme çalışma saatlerini belirlememiş" der (projenin "sahte veriye
-- düşülmez" ilkesi).

CREATE TABLE IF NOT EXISTS working_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  open_time TIME NOT NULL DEFAULT '09:00',
  close_time TIME NOT NULL DEFAULT '18:00',
  is_closed BOOLEAN DEFAULT false,
  UNIQUE(business_id, weekday)
);

CREATE INDEX IF NOT EXISTS idx_working_hours_business ON working_hours(business_id);

ALTER TABLE working_hours ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "working_hours_select" ON working_hours;
DROP POLICY IF EXISTS "working_hours_insert_own" ON working_hours;
DROP POLICY IF EXISTS "working_hours_update_own" ON working_hours;
DROP POLICY IF EXISTS "working_hours_delete_own" ON working_hours;

-- Herkes okuyabilir: müşteri boş saatleri görebilmek için buna ihtiyaç duyar.
CREATE POLICY "working_hours_select" ON working_hours FOR SELECT USING (true);
CREATE POLICY "working_hours_insert_own" ON working_hours FOR INSERT WITH CHECK (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "working_hours_update_own" ON working_hours FOR UPDATE USING (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "working_hours_delete_own" ON working_hours FOR DELETE USING (
  business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ─── 4. Randevu türü ve ilişkileri ───
-- 'consultation' = ön görüşme (müşterinin kendisi talep edebildiği TEK tür)
-- 'procedure'    = işlem randevusu (ön görüşmeden sonra işletme oluşturur)
-- Varsayılan 'procedure': mevcut kayıtların hepsi işletme tarafından
-- oluşturulmuştu, anlamları korunuyor.

ALTER TABLE appointments ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'procedure';
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS service_id UUID
  REFERENCES services(id) ON DELETE SET NULL;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS note TEXT DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_appointments_service ON appointments(service_id);

-- ─── 5. 🔴 RLS DÜZELTMESİ — mevcut gizli hata ───
-- Mevcut politika `FOR ALL ... WITH CHECK (created_by = ben)` şeklindeydi.
-- WITH CHECK, UPDATE'te YENİ satıra da uygulandığı için: bir MÜŞTERİ randevu
-- oluşturduğunda (created_by = müşteri), İŞLETME o randevuyu onaylayamıyordu —
-- UPDATE sessizce reddediliyordu. Bugün fark edilmiyor çünkü randevuları
-- yalnızca işletmeler oluşturuyor, ama randevu alma akışı açılır açılmaz tüm
-- özellik çalışmaz hale gelirdi.
--
-- Çözüm: tek `FOR ALL` politikası yerine ayrı politikalar —
--   INSERT sıkı kalır (yalnızca kendi adına oluşturabilirsin),
--   UPDATE/SELECT/DELETE her iki tarafa da açılır.

DROP POLICY IF EXISTS "appointments_scoped" ON appointments;
DROP POLICY IF EXISTS "appointments_select" ON appointments;
DROP POLICY IF EXISTS "appointments_insert" ON appointments;
DROP POLICY IF EXISTS "appointments_update" ON appointments;
DROP POLICY IF EXISTS "appointments_delete" ON appointments;

CREATE POLICY "appointments_select" ON appointments FOR SELECT USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
);

CREATE POLICY "appointments_insert" ON appointments FOR INSERT WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

CREATE POLICY "appointments_update" ON appointments FOR UPDATE USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
) WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
);

CREATE POLICY "appointments_delete" ON appointments FOR DELETE USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
);
