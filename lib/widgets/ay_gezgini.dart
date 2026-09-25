import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../services/bicim.dart';

/// "‹ Eylül 2026 ›" ay değiştirici. Tüm sekmelerde aynı ay seçili kalır.
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
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          decoration: BoxDecoration(
            color: renk.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Önceki ay',
                icon: const Icon(Icons.chevron_left),
                color: renk.onPrimaryContainer,
                onPressed: () => secili.value = DateTime(ay.year, ay.month - 1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: buAy
                      ? null
                      : () => secili.value = DateTime(simdi.year, simdi.month),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Text(
                          Bicim.ay(ay),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: renk.onPrimaryContainer,
                          ),
                        ),
                        if (!buAy)
                          Text('Bu aya dönmek için dokunun',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: renk.onPrimaryContainer
                                      .withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sonraki ay',
                icon: const Icon(Icons.chevron_right),
                color: renk.onPrimaryContainer,
                onPressed: () => secili.value = DateTime(ay.year, ay.month + 1),
              ),
            ],
          ),
        );
      },
    );
  }
}
