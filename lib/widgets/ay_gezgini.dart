import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../services/bicim.dart';

/// "‹ 📅 Kasım 2026 ›" ay seçici (beyaz hap). Tüm sekmelerde aynı ay seçili kalır.
/// Ay adına dokununca bu aya döner.
class AyGezgini extends StatelessWidget {
  const AyGezgini({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final secili = Depo.instance.seciliAy;
    return ValueListenableBuilder<DateTime>(
      valueListenable: secili,
      builder: (context, ay, _) {
        final simdi = DateTime.now();
        final buAy = ay.year == simdi.year && ay.month == simdi.month;
        final ad = Bicim.ay(ay);
        final baslik = ad.isEmpty ? ad : ad[0].toUpperCase() + ad.substring(1);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          decoration: BoxDecoration(
            color: renk.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: renk.outlineVariant),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Önceki ay',
                icon: const Icon(Icons.chevron_left),
                color: renk.onSurface,
                onPressed: () => secili.value = DateTime(ay.year, ay.month - 1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: buAy ? null : () => secili.value = DateTime(simdi.year, simdi.month),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 20, color: renk.onSurface),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            baslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: renk.onSurface,
                            ),
                          ),
                        ),
                        if (!buAy) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.undo, size: 15, color: renk.onSurfaceVariant),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sonraki ay',
                icon: const Icon(Icons.chevron_right),
                color: renk.onSurface,
                onPressed: () => secili.value = DateTime(ay.year, ay.month + 1),
              ),
            ],
          ),
        );
      },
    );
  }
}
