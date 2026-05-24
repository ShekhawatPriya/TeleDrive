import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'faq_tile.dart';

class PrivacyAndTrustSection extends StatelessWidget {
  const PrivacyAndTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Privacy & Core Principles',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We believe trust is built on transparency, precise wording, and verifiable open-source practices.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const FaqTile(
          question: 'Where are my files stored?',
          answer:
              'Your private file objects are transferred locally through TDLib and referenced from Telegram storage. TeleDrive presents them in a structured folder interface.',
        ),
        const FaqTile(
          question: 'What does TeleDrive store?',
          answer:
              'The backend stores folder indexes, names, shares, upload state, backup fingerprints, and Telegram references. Private file bytes are not uploaded through TeleDrive backend servers.',
        ),
        const FaqTile(
          question: 'Is my login secure?',
          answer:
              'Backend login and the local TDLib session must both be ready before Drive opens. Local TDLib keys are stored in the device keystore/keychain through flutter_secure_storage.',
        ),
        const FaqTile(
          question: 'Does clearing cache delete my files?',
          answer:
              'No. Clearing local device cache only flushes temporary thumbnails, preview clips, and opened documents stored on this phone. Your original uploaded library remains untouched on Telegram.',
        ),
        const FaqTile(
          question: 'How are my device folders accessed?',
          answer:
              'Manual uploads read only the files you select. Gallery backup scans permitted media only after you turn it on from the profile sheet, and path scanning is limited by Android scoped storage.',
        ),
      ],
    );
  }
}
