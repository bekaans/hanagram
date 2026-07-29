-- Hanagram — Gerçek Zamanlı Mesajlaşma
-- conversations, conversation_members, messages tabloları
-- RLS politikaları + indeksler + trigger

-- ═══════════════════════════════════════════
-- 1. TABLOLAR
-- ═══════════════════════════════════════════

-- Konuşmalar (DM ve grup)
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'dm' CHECK (type IN ('dm', 'group')),
  name TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Konuşma üyeleri
CREATE TABLE IF NOT EXISTS conversation_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ DEFAULT now(),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Mesajlar
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'file')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════
-- 2. İNDEXLER
-- ═══════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON messages(sender_id);

CREATE INDEX IF NOT EXISTS idx_conv_members_user
  ON conversation_members(user_id);

CREATE INDEX IF NOT EXISTS idx_conv_members_conv
  ON conversation_members(conversation_id);

CREATE INDEX IF NOT EXISTS idx_conversations_updated
  ON conversations(updated_at DESC);

-- ═══════════════════════════════════════════
-- 3. RLS POLİTİKALARI
-- ═══════════════════════════════════════════

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Konuşmalar: sadece üye olanlar okuyabilir
CREATE POLICY "conv_select_member" ON conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members
      WHERE conversation_id = id AND user_id = auth.uid()
    )
  );

-- Konuşma oluşturma: auth olan herkes
CREATE POLICY "conv_insert_auth" ON conversations FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Üye listesi: üye olanlar görebilir
CREATE POLICY "conv_member_select" ON conversation_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = conversation_members.conversation_id
        AND cm.user_id = auth.uid()
    )
  );

-- Üye ekleme: konuşmayı oluşturan
CREATE POLICY "conv_member_insert" ON conversation_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = conversation_id AND created_by = auth.uid()
    )
  );

-- Kendi okuma zamanını güncelleme
CREATE POLICY "conv_member_update_own" ON conversation_members FOR UPDATE
  USING (user_id = auth.uid());

-- Mesaj okuma: konuşma üyesi olan
CREATE POLICY "msg_select_member" ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members
      WHERE conversation_id = messages.conversation_id
        AND user_id = auth.uid()
    )
  );

-- Mesaj gönderme: auth olan, sadece kendi adına
CREATE POLICY "msg_insert_auth" ON messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- ═══════════════════════════════════════════
-- 4. TRIGGER — updated_at
-- ═══════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS trigger AS $$
BEGIN
  UPDATE conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_message_timestamp ON messages;
CREATE TRIGGER trg_message_timestamp
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();
