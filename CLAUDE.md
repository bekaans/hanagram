# Hanagram — Proje Kuralları

## HER TURN'DE ZORUNLU İLK İŞ
1. **DURUM.md genome'unu oku** — `DURUM.md` dosyasını oku, genome'a göre devam et
2. **Dosya okuma yasak** — genome'dan bilgi al, dosyaları doğrudan okuma (istisna: smart_outline)
3. **Arkadyum Code v2** — tüm sprint kurallarına harfiyen uy

## Mimari
- Flutter sunum katmanı + C++ FFI çekirdeği
- Supabase: auth, database, storage
- 5 platform: Android, iOS, macOS, Windows, Web
- Web'de dart:ffi ve dart:io KULLANILMAZ

## Güvenlik (guvenli-kod)
- guvenli-kod skill'indeki 12 kural istisnasız uygulanır
- Tüm girdiler sunucu tarafında doğrulanır
- Secret'lar SADECE .env'de

## Dil
- Türkçe yanıt ver (kaan-uslubu kurallarına uy)
- Tüm yorumlar ve değişken isimleri İngilizce
