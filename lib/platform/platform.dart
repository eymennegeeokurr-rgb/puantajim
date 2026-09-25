/// Platforma göre değişen işlemler.
/// Android/iOS derlemesinde platform_mobil.dart, web derlemesinde platform_web.dart kullanılır.
library;

export 'platform_mobil.dart' if (dart.library.js_interop) 'platform_web.dart';
