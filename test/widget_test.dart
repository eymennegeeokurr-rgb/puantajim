import 'package:flutter_test/flutter_test.dart';
import 'package:puantajim/models/profil.dart';

// Not: Asıl hesap testleri hesaplama_test.dart dosyasındadır.
void main() {
  test('Aylık maaşta günlük ücret maaş / 30', () {
    expect(const Profil(adSoyad: 'A', ucret: 30000).gunlukUcret, 1000);
  });
}
