import 'package:flutter/material.dart';

import '../services/app_mode_controller.dart';

/// Patron moduna geçmeden önce kısa açıklama + onay ("Patron ol").
/// Onaylanırsa modu Patron yapar.
Future<void> patronOl(BuildContext context) async {
  final m = AppModeController.instance;
  if (m.patronAcildi) {
    await m.ayarla(AppMode.patron);
    return;
  }
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.groups_outlined, size: 32),
      title: const Text('Patron moduna geçilsin mi?'),
      content: const Text(
        'Patron modunda ekibinizi kurar, her gün yoklama alırsınız. Hakediş sizin '
        'girdiğiniz günlere göre hesaplanır.\n\n'
        'Elemanı eklemek için onun kullanıcı kodunu girersiniz; eleman kendi '
        'telefonundan onaylamadan puantajını göremezsiniz.\n\n'
        'Kendi puantajınız silinmez, istediğiniz zaman Bireysel moda dönebilirsiniz.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Patron Ol')),
      ],
    ),
  );
  if (onay == true) await m.ayarla(AppMode.patron);
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
              _ModKutusu(
                mod: AppMode.bireysel,
                secili: m.etkinMod == AppMode.bireysel,
                onTap: () => m.ayarla(AppMode.bireysel),
              ),
              const SizedBox(height: 8),
              _ModKutusu(
                mod: AppMode.patron,
                secili: m.etkinMod == AppMode.patron,
                pasif: !m.patronKullanilabilir,
                onTap: () => patronOl(context),
              ),
              if (!m.patronKullanilabilir) ...[
                const SizedBox(height: 8),
                Text(
                  'Patron modu için hesapla giriş yapmış olmanız gerekir.',
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
        color: secili
            ? renk.primaryContainer
            : renk.surfaceContainerHighest.withValues(alpha: 0.5),
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
