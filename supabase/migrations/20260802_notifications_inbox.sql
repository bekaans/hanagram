-- Hanagram — Bildirimler gelen kutusu
--
-- Kaan'ın istediği "Bildirimler" sekmesi için: gerçek bir bildirim geçmişi.
-- Önceki sistem sadece uygulama açıkken anlık SnackBar gösteriyordu, hiçbir
-- kayıt tutmuyordu. Bu tablo, gönderen tarafın (task/appointment/connection
-- aksiyonları) doğrudan yazdığı kalıcı kayıtları tutar — alıcının uygulaması
-- kapalı olsa bile kayıt oluşur, sonra açtığında geçmişi görür.

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, -- 'task' | 'connection_request' | 'connection_accepted' | 'appointment'
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications FOR SELECT USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Herkes başka bir kullanıcı için bildirim OLUŞTURABİLİR (ör. sana bağlantı
-- isteği gönderen kişi, senin adına bir bildirim satırı yazar) — ama sadece
-- SAHİBİ (is_read güncellemesi için) günceller/siler.
DROP POLICY IF EXISTS "notifications_insert_any" ON notifications;
CREATE POLICY "notifications_insert_any" ON notifications FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own" ON notifications FOR UPDATE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own" ON notifications FOR DELETE USING (
  user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
