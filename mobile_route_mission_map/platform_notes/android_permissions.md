# Android Location Permissions

After running `flutter create . --platforms=android,ios`, add these permissions to:

`android/app/src/main/AndroidManifest.xml`

Place them directly under the root `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

The app label can be set inside the `<application>` tag:

```xml
android:label="Rota Görev Haritası"
```
