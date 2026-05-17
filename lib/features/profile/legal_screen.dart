import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

enum LegalKind { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final title = kind == LegalKind.privacy
        ? 'Privacy Policy'
        : 'Terms of Service';
    final icon = kind == LegalKind.privacy
        ? Icons.privacy_tip_outlined
        : Icons.description_outlined;
    final sections = kind == LegalKind.privacy
        ? _privacySections
        : _termsSections;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => AppConfig.openRepository(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open Source Project',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Last updated: May 2026',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          for (final section in sections) ...[
            _LegalSection(section),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection(this.section);

  final _SectionContent section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (section.paragraph != null)
          Text(section.paragraph!, style: theme.textTheme.bodyLarge),
        for (final item in section.bullets) _BulletItem(item),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '-',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _SectionContent {
  const _SectionContent({
    required this.title,
    this.paragraph,
    this.bullets = const [],
  });

  final String title;
  final String? paragraph;
  final List<String> bullets;
}

const _privacySections = [
  _SectionContent(
    title: 'Overview',
    paragraph:
        'TeleDrive is an open-source Telegram-backed drive project. The app is designed to be transparent about what it accesses, what it stores, and why.',
  ),
  _SectionContent(
    title: 'What We Collect',
    paragraph:
        'TeleDrive stores only the minimum metadata needed to work as a file manager:',
    bullets: [
      'File names, sizes, types, and timestamps for your library, search, sorting, previews, and organization.',
      'Folder structure so your directory hierarchy can be restored across devices.',
      'Telegram user ID, name, username, and profile photo from the authenticated Telegram account.',
      'An authentication token stored securely on this device so the app can call your backend.',
    ],
  ),
  _SectionContent(
    title: 'What We Do Not Collect',
    bullets: [
      'TeleDrive does not read the contents of your files.',
      'TeleDrive does not access your Telegram messages or contacts.',
      'TeleDrive does not sell your data or use advertising trackers.',
    ],
  ),
  _SectionContent(
    title: 'Where Files Are Stored',
    paragraph:
        'Your actual files are stored on Telegram infrastructure. TeleDrive acts as a management layer and stores references, thumbnails or previews when needed, and metadata required to display and manage your files.',
  ),
  _SectionContent(
    title: 'Open Source Transparency',
    paragraph:
        'Because TeleDrive is open source, you can inspect the code, audit how data is handled, and contribute fixes or improvements through the project repository.',
  ),
  _SectionContent(
    title: 'Your Controls',
    bullets: [
      'You can disconnect Telegram access from the app.',
      'You can sign out and remove the local authentication token from this device.',
      'Files uploaded to Telegram remain under your Telegram account.',
    ],
  ),
  _SectionContent(
    title: 'Contact',
    paragraph:
        'For privacy questions, open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];

const _termsSections = [
  _SectionContent(
    title: 'Acceptance of Terms',
    paragraph:
        'By using TeleDrive, you agree to these terms. TeleDrive is open-source software provided as-is, and you use it at your own discretion.',
  ),
  _SectionContent(
    title: 'Service Description',
    paragraph:
        'TeleDrive provides a file management interface backed by Telegram storage. It lets you upload, organize, preview, stream, and download files through the app and your configured backend.',
  ),
  _SectionContent(
    title: 'Your Account',
    bullets: [
      'You are responsible for securing your Telegram account.',
      'You are responsible for the files you upload and manage through TeleDrive.',
      'You must comply with Telegram Terms of Service and applicable laws.',
    ],
  ),
  _SectionContent(
    title: 'Data and Storage',
    paragraph:
        'Your files are stored through Telegram. TeleDrive stores metadata such as file names, sizes, folder structure, and Telegram references so the file manager experience can work.',
  ),
  _SectionContent(
    title: 'Open Source License',
    paragraph:
        'The TeleDrive codebase is available under its project license. You retain all rights to the content you upload.',
  ),
  _SectionContent(
    title: 'Limitations',
    paragraph:
        'TeleDrive is provided without warranties of any kind. Development builds may use cleartext LAN HTTP; production deployments should use HTTPS. You are responsible for backups and for validating the deployment you run.',
  ),
  _SectionContent(
    title: 'Changes',
    paragraph:
        'As an open-source project, TeleDrive may evolve over time. Features and behavior can change as maintainers and contributors improve the project.',
  ),
  _SectionContent(
    title: 'Termination',
    paragraph:
        'You may stop using TeleDrive at any time by signing out or disconnecting Telegram. Files already uploaded to Telegram remain accessible through Telegram directly.',
  ),
  _SectionContent(
    title: 'Contact',
    paragraph:
        'For questions about these terms, open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];
