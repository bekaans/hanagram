-- Hanagram — admin erişimi (is_admin RLS bypass)
-- Bu dosyayı Supabase SQL Editor'da çalıştırın (tek seferlik, idempotent).
--
-- Admin paneli, normal uygulamayla AYNI anon key + RLS altında çalışıyor —
-- yani admin hesabı da, RLS "sadece kendi verin" dediği için, BAŞKA hiçbir
-- kullanıcının görev/randevu/CRM/mesaj/bağlantı kaydını göremiyordu. Bu dosya
-- users.is_admin bayrağını ekliyor ve ilgili tüm SELECT politikalarına
-- "ya da admin isen" şartını ekliyor — admin artık gerçekten her şeyi görebilir.

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_admin = true
  );
$$;

-- tasks
DROP POLICY IF EXISTS "tasks_scoped" ON tasks;
CREATE POLICY "tasks_scoped" ON tasks FOR ALL USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR assigned_to = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
) WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- appointments
DROP POLICY IF EXISTS "appointments_scoped" ON appointments;
CREATE POLICY "appointments_scoped" ON appointments FOR ALL USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
) WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- crm_entries
DROP POLICY IF EXISTS "crm_entries_select" ON crm_entries;
CREATE POLICY "crm_entries_select" ON crm_entries FOR SELECT USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR (
    group_id IS NOT NULL
    AND group_id IN (
      SELECT group_id FROM group_members
      WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    )
  )
  OR is_admin()
);

-- connections
DROP POLICY IF EXISTS "connections_select_own" ON connections;
CREATE POLICY "connections_select_own" ON connections FOR SELECT USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR connected_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
);

-- conversations
DROP POLICY IF EXISTS "conv_select_member" ON conversations;
CREATE POLICY "conv_select_member" ON conversations FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = conversations.id
    AND user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR is_admin()
);

-- conversation_members
DROP POLICY IF EXISTS "conv_member_select" ON conversation_members;
CREATE POLICY "conv_member_select" ON conversation_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members cm
    WHERE cm.conversation_id = conversation_members.conversation_id
    AND cm.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR is_admin()
);

-- messages
DROP POLICY IF EXISTS "msg_select_member" ON messages;
CREATE POLICY "msg_select_member" ON messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = messages.conversation_id
    AND user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR is_admin()
);

-- business_groups
DROP POLICY IF EXISTS "business_groups_select" ON business_groups;
CREATE POLICY "business_groups_select" ON business_groups FOR SELECT USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR id IN (
    SELECT group_id FROM group_members
    WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR is_admin()
);

-- group_members
DROP POLICY IF EXISTS "group_members_all" ON group_members;
CREATE POLICY "group_members_all" ON group_members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM business_groups
    WHERE business_groups.id = group_members.group_id
    AND business_groups.owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
);

-- customers
DROP POLICY IF EXISTS "customers_scoped" ON customers;
CREATE POLICY "customers_scoped" ON customers FOR ALL USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
) WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- accounting_entries
DROP POLICY IF EXISTS "accounting_entries_scoped" ON accounting_entries;
CREATE POLICY "accounting_entries_scoped" ON accounting_entries FOR ALL USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR is_admin()
) WITH CHECK (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- verification_requests (varsa — admin onay akışı için gerekli)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'verification_requests') THEN
    EXECUTE 'DROP POLICY IF EXISTS "Own verification requests" ON verification_requests';
    EXECUTE 'CREATE POLICY "verification_requests_select" ON verification_requests FOR SELECT USING (
      user_id = (SELECT id FROM users WHERE auth_id = auth.uid()) OR is_admin()
    )';
    EXECUTE 'DROP POLICY IF EXISTS "verification_requests_update_admin" ON verification_requests';
    EXECUTE 'CREATE POLICY "verification_requests_update_admin" ON verification_requests FOR UPDATE USING (is_admin())';
  END IF;
END $$;

-- Reklam kampanyaları (ad_screen.dart) — CRUD gerçek, sunum/tıklama takibi
-- henüz yok (feed'e reklam enjekte eden bir sistem kurulmadı) — bu yüzden
-- impressions/clicks kolonları gerçek ama şimdilik hep 0 kalacak, sahte
-- sayı üretilmiyor.
CREATE TABLE IF NOT EXISTS ads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  image_url TEXT DEFAULT '',
  target_topics TEXT[] DEFAULT '{}',
  daily_budget_kurus INTEGER DEFAULT 0,
  bid NUMERIC(10,2) DEFAULT 1.0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'expired', 'draft')),
  impressions INTEGER DEFAULT 0,
  clicks INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ads_owner ON ads(owner_id);

ALTER TABLE ads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ads_select_own" ON ads;
DROP POLICY IF EXISTS "ads_insert_own" ON ads;
DROP POLICY IF EXISTS "ads_update_own" ON ads;
DROP POLICY IF EXISTS "ads_delete_own" ON ads;

CREATE POLICY "ads_select_own" ON ads FOR SELECT USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid()) OR is_admin()
);
CREATE POLICY "ads_insert_own" ON ads FOR INSERT WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "ads_update_own" ON ads FOR UPDATE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "ads_delete_own" ON ads FOR DELETE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Admin hesabının auth.users kaydı zaten var (signup API ile oluşturuldu) ama
-- normal kayıt akışından geçmediği için public.users'ta hiç satırı yok — is_admin()
-- bu satıra bakıyor, o yüzden burada oluşturuluyor.
INSERT INTO users (auth_id, username, full_name, account_type, is_admin, email)
SELECT au.id, 'admin', 'Yönetici', 'personal', true, au.email
FROM auth.users au
WHERE au.email = 'bekaans+hanagramadmin@icloud.com'
ON CONFLICT (auth_id) DO UPDATE SET is_admin = true;
