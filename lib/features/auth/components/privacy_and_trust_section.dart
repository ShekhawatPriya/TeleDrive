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
          answer: 'Your uploaded files are hosted directly on Telegram\'s robust cloud infrastructure. TeleDrive acts as a client dashboard, wrapping those binaries into a structured, elegant folder interface.',
        ),
        const FaqTile(
          question: 'What does TeleDrive store?',
          answer: 'TeleDrive stores structural folder indexes, configuration tags, search cache files, names, and references on your self-hosted backend metadata DB to build a drive-like navigation experience. We do not inspect nor retain actual file contents.',
        ),
        const FaqTile(
          question: 'Is my login secure?',
          answer: 'Absolutely. Session keys and Telegram session credentials are saved directly in your device\'s hardware-backed keystore/keychain utilizing flutter_secure_storage. This guarantees credentials remain fully isolated.',
        ),
        const FaqTile(
          question: 'Does clearing cache delete my files?',
          answer: 'No. Clearing local device cache only flushes temporary thumbnails, preview clips, and opened documents stored on this phone. Your original uploaded library remains untouched on Telegram.',
        ),
        const FaqTile(
          question: 'How are my device folders accessed?',
          answer: 'TeleDrive only queries local storage when you explicitly tap to upload files or media. There is absolutely no background, automated, or passive storage scanning occurring inside this app.',
        ),
      ],
    );
  }
}
