---
yaz: app/lib/features/profile/widgets/profile_stats.dart,
      app/lib/features/profile/widgets/stat_detail_sheet.dart
oku: app/lib/design/tokens.dart, app/lib/widgets/brand.dart, app/lib/core/utils.dart
dogrula: cd app && dart analyze lib/features/profile/widgets/profile_stats.dart lib/features/profile/widgets/stat_detail_sheet.dart
basari: No issues found
deneme: 4
---

# Görev: Profil İstatistiklerine "Favoriler" Ekle

## Sözleşme

### profile_stats.dart
Mevcut `_items` listesine yeni eleman ekle:
```dart
_StatData(key: 'favoriler', label: 'Favoriler', value: 342)
```
Liste artık 6 elemanlı olacak. Row → Expanded yapısı değişmeyecek.

### stat_detail_sheet.dart
1. `_titleFor` switch'ine ekle:
```dart
case 'favoriler': return 'Favori Detayları';
```

2. `_sampleData` map'ine ekle:
```dart
'favoriler': [
  {'name': 'Elif Demir', 'detail': 'Lazer epilasyon', 'date': 'Favorilere eklendi'},
  {'name': 'Ayşe Yılmaz', 'detail': 'Cilt bakımı', 'date': 'Favorilere eklendi'},
  {'name': 'Zeynep Kaya', 'detail': 'Saç botoksu', 'date': 'Favorilere eklendi'},
],
```

## Kurallar
- Ham renk kodu kullanma
- const constructor koru
- Mevcut kod desenini bozma
- Tanımlayıcılar İngilizce
