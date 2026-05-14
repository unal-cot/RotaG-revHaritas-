# 🗺️ Rota Görev Haritası Mobile

Flutter ile hazırlanmış, **Android, iOS ve Web** platformlarında çalışan uygulamadır.

## Özellikler

- 📍 Cihaz konumu isteme
- 🗺️ OpenStreetMap tabanlı harita
- 🔎 Yakınlaştırma / uzaklaştırma kontrolleri
- 🧭 Standart, açık ve topografik harita görünümleri
- 🎯 Konum çevresinde görev noktaları oluşturma
- 🚶 Rota çizimi
- ✅ Kontrol noktası tamamlanma takibi
- 📊 Yüzde, mesafe, süre ve GPS doğruluğu
- 🧪 Demo yürüyüş modu
- 💾 Görev durumunu kaydetme (localStorage / SharedPreferences)
- 📱 Android, iOS ve Web hedefi (tek kod tabanı)

## Kurulum

Flutter kurulu bir makinede:

```bash
cd mobile_route_mission_map
flutter pub get
```

### Web'de çalıştırma

```bash
flutter run -d chrome
```

### Web build

```bash
flutter build web
```

Çıktı `build/web/` dizinindedir.

### Mobilde çalıştırma

```bash
flutter run        # bağlı cihazda
flutter build apk  # Android APK
flutter build ios  # iOS (macOS gerekir)
```

## Android İzinleri

`android/app/src/main/AndroidManifest.xml` içinde şu izinler bulunmalı:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

## iOS İzinleri

`ios/Runner/Info.plist` içinde konum açıklamaları bulunmalı:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

Hazır kopyalanabilir örnekler `platform_notes/` klasöründe bulunur.

## Not

Gerçek cihazda test önerilir. Emülatör/simülatörde konum test etmek için sanal konum atamak gerekir.
