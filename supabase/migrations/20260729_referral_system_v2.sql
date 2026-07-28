-- Hanagram — Referans sistemi v2
--
-- Her kullanıcıya 1 benzersiz referans kodu (sınırsız kullanım)
-- Kullanıcı adları benzersiz (UNIQUE constraint)
-- referrals tablosu: kim kimi davet etti
-- Bildirim tetikleyici

-- 1. Kullanıcı tablosuna my_referral_code ekle
ALTER TABLE users ADD COLUMN IF NOT EXISTS my_referral_code TEXT UNIQUE;

-- 1b. Admin flag ekle (yoksa)
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 2. Username'i gerçekten benzersiz yap (eğer yoksa)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_username_unique'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT users_username_unique UNIQUE (username);
  END IF;
END $$;

-- 3. Benzersiz referans kodu üreten fonksiyon (8 karakter, O/I/L yok)
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

-- 4. Yeni kullanıcı oluşturulduğunda otomatik referans kodu ata
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

-- 5. Mevcut kullanıcılar için referans kodu üret (boş olanlara)
UPDATE users
SET my_referral_code = generate_unique_code()
WHERE my_referral_code IS NULL;

-- 6. referrals tablosu: kim kimi davet etti
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  referred_id UUID REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(referred_id)
);

-- 7. RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- Herkes kendi davet ettiklerini görebilir
CREATE POLICY "Referrer sees own referrals" ON referrals
  FOR SELECT USING (
    referrer_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- Admin her şeyi görebilir
CREATE POLICY "Admin full access" ON referrals
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_admin = true)
  );

-- 8. Kullanıcı kendi referral'ını inserted edebilir (kayıt sırasında)
CREATE POLICY "Insert own referral" ON referrals
  FOR INSERT WITH CHECK (true);

-- 9. referral_codes tablosu artık kullanılmıyor — eski sistemi koru ama devre dışı bırak
-- Yeni sistem: users.my_referral_code + referrals tablosu
