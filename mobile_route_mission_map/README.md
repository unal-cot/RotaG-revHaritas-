# 🗺️ Rota Görev Haritası Mobile

Flutter ile hazırlanmış Android/iOS uygulama sürümüdür.

## Özellikler

- 📍 Cihaz konumu isteme
- 🗺️ OpenStreetMap tabanlı harita
- 🎯 Konum çevresinde görev noktaları oluşturma
- 🚶 Rota çizimi
- ✅ Kontrol noktası tamamlanma takibi
- 📊 Yüzde, mesafe, süre ve GPS doğruluğu
- 🧪 Demo yürüyüş modu
- 📱 Android ve iOS hedefi

## Kurulum

Bu makinede Flutter kurulu olmadığı için native iskelet burada üretilemedi. Flutter kurulduktan sonra bu klasörde şu komutları çalıştır:

```bash
flutter create . --platforms=android,ios
flutter pub get
flutter run
```

`flutter create .` komutu Android/iOS native dosyalarını tamamlar. Bu klasördeki `lib/main.dart` ve `pubspec.yaml` uygulama mantığını hazır taşır.

## Android İzinleri

`flutter create` sonrasında `android/app/src/main/AndroidManifest.xml` içine şu izinler eklenmeli:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

## iOS İzinleri

`flutter create` sonrasında `ios/Runner/Info.plist` içine konum açıklamaları eklenmeli:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

Hazır kopyalanabilir örnekler `platform_notes/` klasöründe bulunur.

## Not

Gerçek cihazda test önerilir. Emülatör/simülatörde konum test etmek için sanal konum atamak gerekir.
