import 'package:flutter/material.dart';

import '../services/app_mode_controller.dart';

/// Yönetici hesabı ilk kez açıldığında bir kere sorulur: hangi modda çalışılsın?
bool _soruluyor = false;

Future<void> modSecimiGerekirseSor(BuildContext context) async {
  final m = AppModeController.instance;
  if (_soruluyor || m.secildi || !m.patronKullanilabilir) return;
  _soruluyor = true;
  final secim = await showModalBottomSheet<AppMode>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => const _ModSecimPaneli(),
  );
  _soruluyor = false;
  await m.ayarla(secim ?? AppMode.bireysel);
}

class _ModSecimPaneli extends StatelessWidget {
  const _ModSecimPaneli();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Uygulamayı nasıl kullanacaksınız?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Daha sonra Profil > Uygulama modu bölümünden değiştirebilirsiniz.',
                style: TextStyle(
                    fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            for (final m in AppMode.values) ...[
              _ModKutusu(
                mod: m,
                secili: false,
                onTap: () => Navigator.pop(context, m),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Profil sayfasında: Bireysel / Patron modu seçimi
class ModSeciciKarti extends StatelessWidget {
  const ModSeciciKarti({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppModeController.instance;
    final renk = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: m.dinleyici,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final mod in AppMode.values) ...[
                _ModKutusu(
                  mod: mod,
                  secili: m.etkinMod == mod,
                  pasif: mod == AppMode.patron && !m.patronKullanilabilir,
                  onTap: () => m.ayarla(mod),
                ),
                if (mod != AppMode.values.last) const SizedBox(height: 8),
              ],
              if (!m.patronKullanilabilir) ...[
                const SizedBox(height: 8),
                Text(
                  'Patron modu yönetici hesaplarında açılır. Ekip kuracaksanız yöneticinizle görüşün.',
                  style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModKutusu extends StatelessWidget {
  final AppMode mod;
  final bool secili;
  final bool pasif;
  final VoidCallback onTap;

  const _ModKutusu({
    required this.mod,
    required this.secili,
    required this.onTap,
    this.pasif = false,
  });

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final ikon = mod == AppMode.bireysel ? Icons.person_outline : Icons.groups_outlined;
    return Opacity(
      opacity: pasif ? 0.45 : 1,
      child: Material(
        color: secili ? renk.primaryContainer : renk.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: pasif || secili ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(ikon, color: secili ? renk.onPrimaryContainer : renk.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mod.etiket} Mod',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: secili ? renk.onPrimaryContainer : null)),
                    const SizedBox(height: 2),
                    Text(mod.aciklama,
                        style: TextStyle(
                            fontSize: 12,
                            color: secili ? renk.onPrimaryContainer : renk.onSurfaceVariant)),
                  ],
                ),
              ),
              if (secili) Icon(Icons.check_circle, color: renk.onPrimaryContainer),
            ]),
          ),
        ),
      ),
    );
  }
}
