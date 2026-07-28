---
yaz: app/lib/features/messages/messages_screen.dart
oku: app/lib/design/tokens.dart, app/lib/widgets/brand.dart, app/lib/features/feed/feed_screen.dart
dogrula: cd app && dart analyze lib
basari: No issues found
deneme: 4
---

Flutter mesajlaşma ekranını yaz. Şu an yerine geçici bir "yakında" ekranı var,
onu gerçek sohbet listesiyle değiştir.

EKRAN YAPISI

1. Üst başlık: "Mesajlar" (HgText.title)
2. Sohbet listesi — her satırda:
   - Avatar(name: otherName)
   - Karşı tarafın adı (HgText.bodyStrong)
   - Son mesaj metni, tek satır, taşarsa üç nokta (HgText.small, textMuted)
   - Sağda: göreli zaman ("az önce", "5 dk", "3 saat", "2 gün")
   - Okunmamışsa: adın yanında dolu nokta + satır hafif vurgulu
3. Liste boşsa EmptyState:
   ikon Icons.forum_outlined, başlık "Henüz mesajın yok",
   mesaj "Bir işletmeye ya da içerik üreticisine yazarak başla."

VERİ

Çekirdekten gelir. AppScope.of(context) ile AppState'e ulaş.
AppState'te henüz mesaj metodu YOK — sen ekleme, çağrı yapma.
Bunun yerine ekran şimdilik boş liste gösterir: `const threads = <ThreadRow>[];`
ThreadRow'u bu dosyanın içinde tanımla:

    class ThreadRow {
      final String threadId, otherName, lastText;
      final int lastAt;
      final bool unread;
      const ThreadRow({required this.threadId, required this.otherName,
                       required this.lastText, required this.lastAt,
                       required this.unread});
    }

Böylece veri bağlandığında ekran değişmeden çalışır.

KURALLAR

- Ham renk kodu YASAK. Renk yalnızca HgTheme.of(context) üzerinden gelir
  (c.text, c.textMuted, c.surface, c.border, c.violet, c.coral ...).
- Boşluk/yarıçap için HgSpace ve HgRadius sabitlerini kullan, çıplak sayı yazma.
- Yazı stilleri HgText.* üzerinden.
- Avatar, HgCard, HgChip, EmptyState bileşenleri widgets/brand.dart içinde hazır.
- Göreli zaman için dosya içinde küçük bir yardımcı fonksiyon yaz (Türkçe).
- Sınıf adı MessagesScreen olarak KALSIN (shell/app_shell.dart onu çağırıyor).
- Yorumlar Türkçe, tanımlayıcılar İngilizce.
