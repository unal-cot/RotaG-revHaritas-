# iOS Location Permissions

After running `flutter create . --platforms=android,ios`, add these keys to:

`ios/Runner/Info.plist`

Place them inside the root `<dict>`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Görev noktalarını ve rotanı haritada göstermek için konumuna ihtiyaç var.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Görev rotanı takip etmek için konum izni gerekir.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Görev rotanı takip etmek için konum izni gerekir.</string>
```
