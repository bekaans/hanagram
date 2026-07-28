-- ============================================================
-- HANAGRAM — Doğrulama Sistemi + Takipçiler
-- Bu dosyayı Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- ─── Users tablosuna verified alanı ───
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
-- verified: true = doğrulanmış (işletme → sarı yıldız, kişisel → mavi yıldız)

-- ─── Doğrulama istekleri tablosu ───
CREATE TABLE IF NOT EXISTS verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  request_type TEXT NOT NULL CHECK (request_type IN ('personal', 'business')),
  -- Kişisel doğrulama alanları
  full_name TEXT,
  tc_no TEXT,
  front_image_url TEXT,
  back_image_url TEXT,
  -- İşletme doğrulama alanları
  business_name TEXT,
  tax_no TEXT,
  tax_certificate_url TEXT,
  business_address TEXT,
  -- Durum
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note TEXT,
  reviewed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 month'),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verification_user ON verification_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_status ON verification_requests(status);
CREATE INDEX IF NOT EXISTS idx_verification_expires ON verification_requests(expires_at) WHERE status = 'pending';

-- ─── Takipçiler tablosu ───
CREATE TABLE IF NOT EXISTS followers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS idx_followers_following ON followers(following_id);

-- ─── Takipçi sayısını hesaplayan fonksiyon ───
CREATE OR REPLACE FUNCTION get_follower_count(target_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  cnt INTEGER;
BEGIN
  SELECT count(*) INTO cnt FROM followers WHERE following_id = target_user_id;
  RETURN cnt;
END;
$$ LANGUAGE plpgsql STABLE;

-- ─── Takipçi sayısını views'e ekle (performans için) ───
ALTER TABLE users ADD COLUMN IF NOT EXISTS follower_count INTEGER DEFAULT 0;

-- ─── Takipçi eklendiğinde/silindiğinde sayacı güncelle ───
CREATE OR REPLACE FUNCTION update_follower_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE users SET follower_count = follower_count + 1 WHERE id = NEW.following_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE users SET follower_count = GREATEST(follower_count - 1, 0) WHERE id = OLD.following_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_follower_count ON followers;
CREATE TRIGGER trg_follower_count
  AFTER INSERT OR DELETE ON followers
  FOR EACH ROW
  EXECUTE FUNCTION update_follower_count();

-- ─── Süresi dolmuş istekleri otomatik silen fonksiyon (pg_cron ile) ───
CREATE OR REPLACE FUNCTION cleanup_expired_verifications()
RETURNS void AS $$
BEGIN
  -- 1 ay dolmuş ve hâlâ pending olan istekleri sil
  DELETE FROM verification_requests
  WHERE status = 'pending' AND expires_at < now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── Storage bucket'ları ───
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification', 'verification', false)
ON CONFLICT (id) DO NOTHING;

-- ─── RLS Politikaları ───

-- Doğrulama istekleri: herkes kendi isteklerini okuyabilir
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Own verification requests" ON verification_requests
  FOR SELECT USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Insert own verification" ON verification_requests
  FOR INSERT WITH CHECK (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Takipçiler: herkes okuyabilir, herkes takip edebilir
ALTER TABLE followers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public follow list" ON followers
  FOR SELECT USING (true);

CREATE POLICY "Follow user" ON followers
  FOR INSERT WITH CHECK (follower_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Unfollow user" ON followers
  FOR DELETE USING (follower_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Verification storage: kullanıcılar kendi dosyalarını yükleyebilir
-- (admin service_role key ile okur)
