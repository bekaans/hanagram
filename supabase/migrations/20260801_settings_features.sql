-- Hanagram — Ayarlar ekranındaki "Çevrimiçi görünürlük" ve "Okundu bilgisi"
-- anahtarlarını gerçek özelliğe bağlamak için gereken alanlar.
--
-- Bu iki tercih BAŞKA kullanıcıların istemcisi tarafından okunacak (biri
-- profilime baktığında çevrimiçi olup olmadığımı görecek, biri bana mesaj
-- attığında okundu bilgimi görecek) — bu yüzden yerel SharedPreferences
-- yetmez, users tablosunda saklanmalı. "Public profiles" politikası zaten
-- users tablosunu herkese açık okunur yaptığı için (USING (true)) ek bir
-- SELECT politikası gerekmiyor; UPDATE zaten "Own profile update" ile
-- sahibine kısıtlı.

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE users ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS show_read_receipts BOOLEAN DEFAULT true;
