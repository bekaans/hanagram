-- Hanagram — RLS id-tipi düzeltmesi + eksik tablolar
-- Bu dosyayı Supabase SQL Editor'da çalıştırın (tek seferlik, idempotent).
--
-- BAĞLAM: iki ayrı migration seti (app/supabase/migrations/*.sql ve bu klasördeki
-- 20260729_*.sql) birbirinden habersiz yazılmış. İkisi de connections/business_groups/
-- conversations/conversation_members/messages/media için "auth.uid()" değerini
-- doğrudan "users.id" tipindeki kolonlarla (user_id, owner_id, created_by, sender_id)
-- karşılaştırıyor — bu ikisi FARKLI UUID'ler (auth.uid() = users.auth_id, asla
-- users.id değil). Sonuç: Dart tarafı düzeltilse bile RLS her insert/select'i
-- sessizce reddediyordu (ya da 20260729 setindeki "USING (true)" politikalarında
-- HERKES HERKESİN verisini görebildiği bir gizlilik açığı vardı).
--
-- Hangi migration setinin canlı projede uygulandığı repodan belli değil, bu yüzden
-- bu dosya ikisinden BAĞIMSIZ çalışacak şekilde yazıldı: önce (0) her iki settaki
-- tabloların + Faz 2'nin yeni tablolarının + crm_entries/conversations'ın yeni
-- kolonlarının var olduğunu garanti eder (hepsi RLS politikalarından ÖNCE —
-- bir kolon/tablo yoksa onu kullanan CREATE POLICY hata verir), sonra (1-5) olası
-- politika adlarını DROP IF EXISTS ile temizleyip TEK doğru politikayı kurar,
-- son olarak (6) hâlâ eksik olan bağımsız tabloları (accounting/products/reviews/
-- posts/likes/comments) ekler.

-- ═══════════════════════════════════════════
-- 0. Önkoşul tablolar + kolonlar — RLS politikalarından ÖNCE, hangi lineage
--    uygulanmış olursa olsun garanti et. Sıra önemli: customers, crm_entries'in
--    customer_id FK'si için ondan ÖNCE var olmalı.
-- ═══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS business_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES business_groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) NOT NULL,
  role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'dm' CHECK (type IN ('dm', 'group')),
  name TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS conversation_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ DEFAULT now(),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'file')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS media (
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

-- Müşteri dizini (crm_entries = ziyaret/işlem geçmişi, customers = kişi kartı)
-- — crm_entries.customer_id bunu referans alacağı için crm_entries'ten ÖNCE.
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) NOT NULL,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  email TEXT DEFAULT '',
  note TEXT DEFAULT '',
  tags TEXT[] DEFAULT '{}',
  linked_user_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_customers_owner ON customers(owner_id);
-- Aynı telefonla aynı işletmede iki kez eklenmesin (Kaan'ın CRM dedup isteği)
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_owner_phone
  ON customers(owner_id, phone) WHERE phone <> '';

-- crm_entries: satış ekranının + ekip paylaşımının ihtiyaç duyduğu ek alanlar.
-- RLS politikalarından ÖNCE eklenmeli (aşağıdaki crm_entries_select group_id kullanıyor).
ALTER TABLE crm_entries ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE crm_entries ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';
ALTER TABLE crm_entries ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'direct';
ALTER TABLE crm_entries ADD COLUMN IF NOT EXISTS line_items JSONB DEFAULT '[]'::jsonb;
ALTER TABLE crm_entries ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES business_groups(id) ON DELETE SET NULL;

-- conversations: ekip sohbetini ekibe bağla (bir ekip = bir grup konuşma)
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES business_groups(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_conversations_team ON conversations(team_id);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_conv_members_conv ON conversation_members(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);

ALTER TABLE business_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS trigger AS $$
BEGIN
  UPDATE conversations SET updated_at = now() WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_message_timestamp ON messages;
CREATE TRIGGER trg_message_timestamp
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();

DROP POLICY IF EXISTS "customers_scoped" ON customers;
CREATE POLICY "customers_scoped" ON customers FOR ALL USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
) WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 1. connections — düzeltme
-- ═══════════════════════════════════════════
DROP POLICY IF EXISTS "Connections own" ON connections;
DROP POLICY IF EXISTS "Read connections" ON connections;
DROP POLICY IF EXISTS "Insert connections" ON connections;
DROP POLICY IF EXISTS "Update connections" ON connections;

CREATE POLICY "connections_select_own" ON connections FOR SELECT USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR connected_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "connections_insert_own" ON connections FOR INSERT WITH CHECK (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "connections_update_own" ON connections FOR UPDATE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR connected_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "connections_delete_own" ON connections FOR DELETE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR connected_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 2. business_groups + group_members — düzeltme
-- ═══════════════════════════════════════════
DROP POLICY IF EXISTS "Groups owner" ON business_groups;

CREATE POLICY "business_groups_select" ON business_groups FOR SELECT USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR id IN (
    SELECT group_id FROM group_members
    WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "business_groups_insert_own" ON business_groups FOR INSERT WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "business_groups_update_own" ON business_groups FOR UPDATE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "business_groups_delete_own" ON business_groups FOR DELETE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "Group members own" ON group_members;

CREATE POLICY "group_members_all" ON group_members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM business_groups
    WHERE business_groups.id = group_members.group_id
    AND business_groups.owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
  OR user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 3. tasks / appointments / crm_entries — canlıda hangi set aktifse
--    (000 doğru scoped, 20260729 tamamen açıktı) ikisini de temizleyip
--    tek doğru hâli garanti et.
-- ═══════════════════════════════════════════
DROP POLICY IF EXISTS "Tasks own" ON tasks;
DROP POLICY IF EXISTS "Read tasks" ON tasks;
DROP POLICY IF EXISTS "Insert tasks" ON tasks;
DROP POLICY IF EXISTS "Update tasks" ON tasks;

CREATE POLICY "tasks_scoped" ON tasks FOR ALL USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR assigned_to = (SELECT id FROM users WHERE auth_id = auth.uid())
) WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "Appointments own" ON appointments;
DROP POLICY IF EXISTS "Read appointments" ON appointments;
DROP POLICY IF EXISTS "Insert appointments" ON appointments;
DROP POLICY IF EXISTS "Update appointments" ON appointments;

CREATE POLICY "appointments_scoped" ON appointments FOR ALL USING (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR attendee_id = (SELECT id FROM users WHERE auth_id = auth.uid())
) WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "CRM own" ON crm_entries;
DROP POLICY IF EXISTS "Read CRM" ON crm_entries;
DROP POLICY IF EXISTS "Insert CRM" ON crm_entries;
DROP POLICY IF EXISTS "crm_entries_scoped" ON crm_entries;

-- Kendi kaydın + (varsa) group_id ile paylaşıldığı ekibin üyesiysen görebilirsin.
-- Yazma/silme sadece kaydın sahibine ait.
CREATE POLICY "crm_entries_select" ON crm_entries FOR SELECT USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR (
    group_id IS NOT NULL
    AND group_id IN (
      SELECT group_id FROM group_members
      WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    )
  )
);
CREATE POLICY "crm_entries_insert_own" ON crm_entries FOR INSERT WITH CHECK (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "crm_entries_update_own" ON crm_entries FOR UPDATE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "crm_entries_delete_own" ON crm_entries FOR DELETE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 4. Mesajlaşma — düzeltme (conversations / conversation_members / messages)
-- ═══════════════════════════════════════════
DROP POLICY IF EXISTS "conv_select_member" ON conversations;
DROP POLICY IF EXISTS "conv_insert_auth" ON conversations;

CREATE POLICY "conv_select_member" ON conversations FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = conversations.id
    AND user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "conv_insert_auth" ON conversations FOR INSERT WITH CHECK (
  created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "conv_member_select" ON conversation_members;
DROP POLICY IF EXISTS "conv_member_insert" ON conversation_members;
DROP POLICY IF EXISTS "conv_member_update_own" ON conversation_members;

CREATE POLICY "conv_member_select" ON conversation_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members cm
    WHERE cm.conversation_id = conversation_members.conversation_id
    AND cm.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "conv_member_insert" ON conversation_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversations
    WHERE id = conversation_id
    AND created_by = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "conv_member_update_own" ON conversation_members FOR UPDATE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "msg_select_member" ON messages;
DROP POLICY IF EXISTS "msg_insert_auth" ON messages;

CREATE POLICY "msg_select_member" ON messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = messages.conversation_id
    AND user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "msg_insert_auth" ON messages FOR INSERT WITH CHECK (
  sender_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 5. media — herkes görebilir (portfolyo public), ama sadece sahibi yükler/siler
-- ═══════════════════════════════════════════
DROP POLICY IF EXISTS "Read media" ON media;
DROP POLICY IF EXISTS "Insert media" ON media;
DROP POLICY IF EXISTS "Delete media" ON media;

CREATE POLICY "media_select_all" ON media FOR SELECT USING (true);
CREATE POLICY "media_insert_own" ON media FOR INSERT WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "media_delete_own" ON media FOR DELETE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- ═══════════════════════════════════════════
-- 6. YENİ TABLOLAR — Faz 2 (eksik özellikler, sıra bağımsız)
-- ═══════════════════════════════════════════

-- Muhasebe: accounting_service.dart zaten kodda vardı ama bu tablo hiç yoktu.
CREATE TABLE IF NOT EXISTS accounting_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  title TEXT NOT NULL,
  amount INTEGER NOT NULL DEFAULT 0,
  category TEXT DEFAULT '',
  description TEXT DEFAULT '',
  customer_name TEXT DEFAULT '',
  crm_entry_id UUID REFERENCES crm_entries(id) ON DELETE SET NULL,
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_accounting_entries_user_date ON accounting_entries(user_id, date DESC);

ALTER TABLE accounting_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "accounting_entries_scoped" ON accounting_entries;
CREATE POLICY "accounting_entries_scoped" ON accounting_entries FOR ALL USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
) WITH CHECK (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Ürün kataloğu
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) NOT NULL,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  description TEXT DEFAULT '',
  category TEXT DEFAULT '',
  image_url TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_products_owner ON products(owner_id);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "products_select" ON products;
DROP POLICY IF EXISTS "products_insert_own" ON products;
DROP POLICY IF EXISTS "products_update_own" ON products;
DROP POLICY IF EXISTS "products_delete_own" ON products;

CREATE POLICY "products_select" ON products FOR SELECT USING (true);
CREATE POLICY "products_insert_own" ON products FOR INSERT WITH CHECK (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "products_update_own" ON products FOR UPDATE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "products_delete_own" ON products FOR DELETE USING (
  owner_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Yorum + yıldız (işletme değerlendirmesi)
-- reviewer_id NULL olabilir: işletme sahibinin uygulama dışında (telefon/WhatsApp)
-- aldığı bir değerlendirmeyi reviewer_name ile elle kaydettiği durum için.
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES users(id) NOT NULL,
  reviewer_id UUID REFERENCES users(id),
  reviewer_name TEXT DEFAULT '',
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(business_id, reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_reviews_business ON reviews(business_id);
ALTER TABLE reviews ALTER COLUMN reviewer_id DROP NOT NULL;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewer_name TEXT DEFAULT '';

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reviews_select" ON reviews;
DROP POLICY IF EXISTS "reviews_insert_own" ON reviews;
DROP POLICY IF EXISTS "reviews_update_own" ON reviews;
DROP POLICY IF EXISTS "reviews_delete_own" ON reviews;

CREATE POLICY "reviews_select" ON reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert_own" ON reviews FOR INSERT WITH CHECK (
  (
    reviewer_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    AND reviewer_id <> business_id
  )
  OR (
    reviewer_id IS NULL
    AND business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  )
);
CREATE POLICY "reviews_update_own" ON reviews FOR UPDATE USING (
  reviewer_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "reviews_delete_own" ON reviews FOR DELETE USING (
  reviewer_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  OR business_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Feed / portfolyo gönderileri
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES users(id) NOT NULL,
  media_id UUID REFERENCES media(id) ON DELETE SET NULL,
  caption TEXT DEFAULT '',
  topic TEXT DEFAULT '',
  is_portfolio BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "posts_select" ON posts;
DROP POLICY IF EXISTS "posts_insert_own" ON posts;
DROP POLICY IF EXISTS "posts_update_own" ON posts;
DROP POLICY IF EXISTS "posts_delete_own" ON posts;

CREATE POLICY "posts_select" ON posts FOR SELECT USING (true);
CREATE POLICY "posts_insert_own" ON posts FOR INSERT WITH CHECK (
  author_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "posts_update_own" ON posts FOR UPDATE USING (
  author_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "posts_delete_own" ON posts FOR DELETE USING (
  author_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "post_likes_select" ON post_likes;
DROP POLICY IF EXISTS "post_likes_insert_own" ON post_likes;
DROP POLICY IF EXISTS "post_likes_delete_own" ON post_likes;

CREATE POLICY "post_likes_select" ON post_likes FOR SELECT USING (true);
CREATE POLICY "post_likes_insert_own" ON post_likes FOR INSERT WITH CHECK (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "post_likes_delete_own" ON post_likes FOR DELETE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

CREATE TABLE IF NOT EXISTS post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  author_id UUID REFERENCES users(id) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_post_comments_post ON post_comments(post_id);

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "post_comments_select" ON post_comments;
DROP POLICY IF EXISTS "post_comments_insert_own" ON post_comments;
DROP POLICY IF EXISTS "post_comments_delete_own" ON post_comments;

CREATE POLICY "post_comments_select" ON post_comments FOR SELECT USING (true);
CREATE POLICY "post_comments_insert_own" ON post_comments FOR INSERT WITH CHECK (
  author_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "post_comments_delete_own" ON post_comments FOR DELETE USING (
  author_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
