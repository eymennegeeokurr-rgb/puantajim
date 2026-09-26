import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../kvkk_metni.dart';
import '../services/bulut.dart';

/// Giriş / Kayıt ekranı (Firebase açıksa ilk açılışta gösterilir).
class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({super.key});

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  bool _kayit = false; // false: giriş, true: kayıt ol

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: renk.primaryContainer,
                  child: Icon(Icons.edit_calendar,
                      size: 34, color: renk.onPrimaryContainer),
                ),
                const SizedBox(height: 14),
                Text('Puantajım',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  _kayit
                      ? 'Yeni hesap oluşturun'
                      : 'Telefon numaranız ve şifrenizle giriş yapın',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: renk.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Giriş Yap'), icon: Icon(Icons.login)),
                    ButtonSegment(value: true, label: Text('Kayıt Ol'), icon: Icon(Icons.person_add)),
                  ],
                  selected: {_kayit},
                  onSelectionChanged: (s) => setState(() => _kayit = s.first),
                ),
                const SizedBox(height: 20),
                if (_kayit) const _KayitFormu() else const _GirisFormu(),
                const SizedBox(height: 20),
                Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: renk.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Telefon numaranız hiçbir yerde saklanmaz ve kimseyle paylaşılmaz; '
                      'sadece giriş için geri çevrilemez bir özeti kullanılır.',
                      style: TextStyle(fontSize: 11.5, color: renk.outline),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Ortak alanlar
// ============================================================================

InputDecoration _telefonAlani() => const InputDecoration(
      labelText: 'Cep telefonu',
      hintText: '05XX XXX XX XX',
      prefixIcon: Icon(Icons.phone_android),
    );

String? _telefonKontrol(String? v) =>
    Bulut.telefonDuzelt(v ?? '') == null ? 'Geçerli bir cep numarası girin' : null;

void _hataGoster(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(e is BulutHatasi ? e.mesaj : 'Hata: $e'),
    duration: const Duration(seconds: 5),
  ));
}

// ============================================================================
// GİRİŞ
// ============================================================================

class _GirisFormu extends StatefulWidget {
  const _GirisFormu();

  @override
  State<_GirisFormu> createState() => _GirisFormuState();
}

class _GirisFormuState extends State<_GirisFormu> {
  final _form = GlobalKey<FormState>();
  final _tel = TextEditingController();
  final _sifre = TextEditingController();
  bool _gizli = true;
  bool _bekle = false;

  @override
  void dispose() {
    _tel.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _giris() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _bekle = true);
    try {
      await Bulut.girisYap(telefon: _tel.text, sifre: _sifre.text);
    } catch (e) {
      if (mounted) _hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  Future<void> _sifremiUnuttum() async {
    if (Bulut.telefonDuzelt(_tel.text) == null) {
      _hataGoster(context, const BulutHatasi('Önce telefon numaranızı yazın'));
      return;
    }
    try {
      await Bulut.sifreSifirla(_tel.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Şifre sıfırlama bağlantısı e-postanıza gönderildi')));
      }
    } catch (e) {
      if (mounted) _hataGoster(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
            decoration: _telefonAlani(),
            validator: _telefonKontrol,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _sifre,
            obscureText: _gizli,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_gizli ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _gizli = !_gizli),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Şifrenizi girin' : null,
            onFieldSubmitted: (_) => _giris(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _bekle ? null : _sifremiUnuttum,
              child: const Text('Şifremi unuttum'),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _bekle ? null : _giris,
            icon: _bekle
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: const Text('Giriş Yap'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KAYIT
// ============================================================================

class _KayitFormu extends StatefulWidget {
  const _KayitFormu();

  @override
  State<_KayitFormu> createState() => _KayitFormuState();
}

class _KayitFormuState extends State<_KayitFormu> {
  final _form = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _tel = TextEditingController();
  final _sifre = TextEditingController();
  final _sifre2 = TextEditingController();
  final _eposta = TextEditingController();
  bool _gizli = true;
  bool _riza1 = false;
  bool _riza2 = false;
  bool _bekle = false;

  @override
  void dispose() {
    for (final c in [_ad, _tel, _sifre, _sifre2, _eposta]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kvkkGoster() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(KvkkMetni.baslik),
          content: const SingleChildScrollView(
            child: Text(KvkkMetni.aydinlatma, style: TextStyle(fontSize: 13)),
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Okudum')),
          ],
        ),
      );

  Future<void> _kayitOl() async {
    if (!_form.currentState!.validate()) return;
    if (!_riza1 || !_riza2) {
      _hataGoster(context,
          const BulutHatasi('Devam etmek için KVKK onay kutularını işaretleyin'));
      return;
    }
    setState(() => _bekle = true);
    try {
      await Bulut.kayitOl(
        adSoyad: _ad.text,
        telefon: _tel.text,
        sifre: _sifre.text,
        eposta: _eposta.text,
      );
    } catch (e) {
      if (mounted) _hataGoster(context, e);
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    const bosluk = SizedBox(height: 14);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ad,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Adınız Soyadınız',
              prefixIcon: Icon(Icons.person),
              helperText: 'Yöneticiniz sizi bu isimle görür',
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 5 || !t.contains(' ')) return 'Ad ve soyadınızı yazın';
              return null;
            },
          ),
          bosluk,
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
            textInputAction: TextInputAction.next,
            decoration: _telefonAlani(),
            validator: _telefonKontrol,
          ),
          bosluk,
          TextFormField(
            controller: _sifre,
            obscureText: _gizli,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Şifre (en az 6 karakter)',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_gizli ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _gizli = !_gizli),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
          ),
          bosluk,
          TextFormField(
            controller: _sifre2,
            obscureText: _gizli,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Şifre (tekrar)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => v != _sifre.text ? 'Şifreler aynı değil' : null,
          ),
          bosluk,
          TextFormField(
            controller: _eposta,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta (isteğe bağlı)',
              prefixIcon: Icon(Icons.alternate_email),
              helperText: 'Sadece şifrenizi unutursanız sıfırlamak için kullanılır',
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                  ? null
                  : 'E-posta adresi geçersiz';
            },
          ),
          const SizedBox(height: 18),

          // ---- KVKK
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border.all(color: renk.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton.icon(
                    onPressed: _kvkkGoster,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('KVKK Aydınlatma Metnini oku'),
                  ),
                ),
                CheckboxListTile(
                  value: _riza1,
                  onChanged: (v) => setState(() => _riza1 = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text(KvkkMetni.riza1, style: TextStyle(fontSize: 12.5)),
                ),
                CheckboxListTile(
                  value: _riza2,
                  onChanged: (v) => setState(() => _riza2 = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text(KvkkMetni.riza2, style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _bekle ? null : _kayitOl,
            icon: _bekle
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add),
            label: const Text('Kayıt Ol'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}
