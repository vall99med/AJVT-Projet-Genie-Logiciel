import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/constants/app_colors.dart';

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isAr = locale.languageCode == 'ar';

    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ع',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                color: isAr ? AppColors.primary : AppColors.textLight,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('|', style: TextStyle(color: AppColors.border)),
            ),
            Text(
              'FR',
              style: TextStyle(
                fontSize: 14,
                fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                color: !isAr ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
