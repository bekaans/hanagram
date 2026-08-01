-- Hanagram — Takip sistemi (followers tablosu)
-- 2026-08-01
--
-- 🔴 Bu tablo HİÇ YOKTU ama kod ona yazıyordu.
-- `verification_service.dart`:
--   - `follow()`/`unfollow()` → `_db.from('followers').upsert(...)` çağırıyordu,
--     tablo olmadığı için her çağrı exception fırlatıp `catch (_)` tarafından
--     sessizce yutuluyordu — TAKİP ETME ÖZELLİĞİ HİÇ ÇALIŞMIYORDU.
--   - `getFollowerCount()` ise hiç var olmayan `users.follower_count` kolonunu
--     okuyordu — HER ZAMAN 0 dönüyordu.
-- İkisi de sessiz başarısızlıktı, hiçbir yerde hata görünmüyordu.
--
-- Idempotent: tekrar çalıştırılabilir.

CREATE TABLE IF NOT EXISTS followers (
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  -- Kişi kendini takip edemez (uygulama katmanında da kontrol var, burada da
  -- veritabanı seviyesinde garanti altına alınıyor).
  CHECK (follower_id <> following_id)
);

CREATE INDEX IF NOT EXISTS idx_followers_follower ON followers(follower_id);
CREATE INDEX IF NOT EXISTS idx_followers_following ON followers(following_id);

ALTER TABLE followers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "followers_select" ON followers;
DROP POLICY IF EXISTS "followers_insert_own" ON followers;
DROP POLICY IF EXISTS "followers_delete_own" ON followers;

-- Takipçi/takip sayıları herkese açık (profilde gösteriliyor).
CREATE POLICY "followers_select" ON followers FOR SELECT USING (true);

-- Kişi yalnızca KENDİ adına takip edebilir/bırakabilir.
CREATE POLICY "followers_insert_own" ON followers FOR INSERT WITH CHECK (
  follower_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "followers_delete_own" ON followers FOR DELETE USING (
  follower_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
