# 🗺️ Rota Görev Haritası / Route Mission Map

## 🇹🇷 Türkçe

**Rota Görev Haritası**, cihaz konumunu kullanarak harita üzerinde görev odaklı rota takibi yapan bir web uygulaması prototipidir. Kullanıcı harita üzerindeki kontrol noktalarına yaklaştıkça uygulama bu noktaları tamamlanmış sayar ve ilerlemeyi yüzde olarak gösterir.

Bu proje ileride mobil uygulamaya dönüştürülebilecek şekilde hazırlanmıştır. PWA manifest ve service worker temeli eklenmiştir.

### ✨ Özellikler

- 📍 Cihazın mevcut konumunu isteme ve haritayı o konuma taşıma
- 🗺️ OpenStreetMap harita katmanı
- 🔎 Haritayı yakınlaştırma / uzaklaştırma
- 🧭 Standart, açık ve topografik harita görünümü seçenekleri
- 🎯 Konuma göre otomatik görev / kontrol noktası oluşturma
- 🚶 Geçilen rotayı harita üzerinde çizme
- ✅ Kontrol noktasına yaklaşıldığında otomatik tamamlandı işaretleme
- 📊 Tamamlanma yüzdesi, mesafe, süre ve konum doğruluğu gösterimi
- 🧪 Fiziksel konum olmadan test için “Demo Yürüyüş” modu
- 📱 Mobil ekranlara uyumlu arayüz
- 💾 Görev durumunu tarayıcıda saklama
- ⚡ PWA başlangıç yapısı

### 🚀 Nasıl Çalıştırılır?

Bu proje bağımlılıksız, sade bir HTML/CSS/JavaScript uygulamasıdır.

```bash
node dev-server.mjs
```

Sonra tarayıcıda aç:

```text
http://localhost:5173
```

### 📍 Konum İzni

Uygulama açıldığında “Konumunu güncelleyelim mi?” sorusu çıkar. **Konumu Güncelle** butonuna basıldığında tarayıcı cihaz konumu için izin ister. İzin verilirse harita gerçek konuma taşınır ve görev noktaları o bölgeye göre üretilir.

> Not: Tarayıcılar gerçek konum erişimi için genellikle `localhost` veya HTTPS ister.

### 🧭 Görev Mantığı

1. Kullanıcı konumunu günceller veya görevi başlatır.
2. Uygulama mevcut konum çevresinde kontrol noktaları oluşturur.
3. Kullanıcı hareket ettikçe rota çizilir.
4. Bir kontrol noktasının yaklaşık 38 metre yakınına gelindiğinde nokta tamamlandı sayılır.
5. Tamamlanan noktalar toplam göreve oranlanır ve yüzde olarak gösterilir.

### 📱 Mobil Hedef

Bu prototip web üzerinde hazırlanmıştır; sonraki aşamada mobil için:

- React Native / Expo uyarlaması
- Arka planda konum takibi
- Görev geçmişi
- Kullanıcı hesabı
- Gerçek görev senaryoları
- Harita sağlayıcı seçimi

eklenebilir.

---

## 🇬🇧 English

**Route Mission Map** is a web app prototype for task-based route tracking on a map using the device’s location. As the user approaches mission checkpoints, the app marks them as completed and displays progress as a percentage.

The project is designed as a starting point for a future mobile app. A basic PWA manifest and service worker are already included.

### ✨ Features

- 📍 Request the device’s current location and center the map on it
- 🗺️ OpenStreetMap tile layer
- 🔎 Zoom in / zoom out controls
- 🧭 Standard, light, and topographic map style options
- 🎯 Automatically generate mission checkpoints around the current location
- 🚶 Draw the traveled route on the map
- ✅ Mark checkpoints as completed when the user gets close
- 📊 Show completion percentage, distance, duration, and GPS accuracy
- 🧪 “Demo Walk” mode for testing without moving physically
- 📱 Responsive layout for mobile screens
- 💾 Persist mission state in the browser
- ⚡ Basic PWA-ready structure

### 🚀 Run Locally

This is a dependency-free HTML/CSS/JavaScript app.

```bash
node dev-server.mjs
```

Then open:

```text
http://localhost:5173
```

### 📍 Location Permission

When the app opens, it asks whether you want to update your location. Pressing **Konumu Güncelle** triggers the browser’s location permission flow. If permission is granted, the map moves to the real device location and mission checkpoints are generated around that area.

> Note: Browsers usually require `localhost` or HTTPS for real geolocation access.

### 🧭 Mission Logic

1. The user updates their location or starts a mission.
2. The app creates checkpoints around the current location.
3. As the user moves, the route is drawn on the map.
4. When the user gets within roughly 38 meters of a checkpoint, it is marked as completed.
5. Completed checkpoints are converted into a progress percentage.

### 📱 Mobile Roadmap

This prototype currently runs on the web. Future mobile-focused improvements may include:

- React Native / Expo version
- Background location tracking
- Mission history
- User accounts
- Real-world mission scenarios
- Configurable map provider

---

## 🛠️ Tech Stack

- HTML
- CSS
- Vanilla JavaScript
- OpenStreetMap tiles
- Browser Geolocation API
- PWA manifest + service worker

## 📄 License

This project is currently a prototype. Add a license before using it in production.
