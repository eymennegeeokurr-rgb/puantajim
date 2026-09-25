@echo off
chcp 65001 >nul
echo ============================================
echo   Puantajim - APK ve Web derleme
echo ============================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo HATA: Flutter bulunamadi. README.md dosyasindaki adimlari uygulayin.
  pause
  exit /b 1
)

if not exist android (
  echo [1/5] Android klasoru olusturuluyor...
  call flutter create --platforms=android,web --org com.santiye --project-name puantajim .
  powershell -Command "(Get-Content android\app\src\main\AndroidManifest.xml -Encoding UTF8) -replace 'android:label=\"puantajim\"','android:label=\"Puantajım\"' | Set-Content android\app\src\main\AndroidManifest.xml -Encoding UTF8"
  xcopy /E /Y /Q android_ikon\* android\app\src\main\res\ >nul
)

if not exist "%USERPROFILE%\.android\debug.keystore" (
  mkdir "%USERPROFILE%\.android" 2>nul
  copy /Y android_imza\debug.keystore "%USERPROFILE%\.android\debug.keystore" >nul
)
echo [2/5] Bagimliliklar indiriliyor...
call flutter pub get

echo [3/5] APK derleniyor (ilk seferde 5-10 dk surebilir)...
call flutter build apk --release
if errorlevel 1 (
  echo HATA: APK derlenemedi.
  pause
  exit /b 1
)

echo [4/5] Web uygulamasi derleniyor (iPhone icin)...
call flutter build web --release --no-web-resources-cdn
call dart run tool/pwa_hazirla.dart

echo [5/5] Tamamlandi!
echo APK : build\app\outputs\flutter-apk\app-release.apk
echo Web : build\web  (bu klasoru Netlify Drop'a surukleyip yayinlayabilirsiniz)
explorer build\app\outputs\flutter-apk
pause
