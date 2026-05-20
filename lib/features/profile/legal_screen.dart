import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

enum LegalKind { privacy, terms }

class LegalScreen extends StatefulWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalKind kind;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalKind _selectedKind;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.kind;
    _pageController = PageController(initialPage: widget.kind.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != oldWidget.kind) {
      setState(() {
        _selectedKind = widget.kind;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          widget.kind.index,
          duration: AppDurations.medium3,
          curve: AppEasing.emphasizedDecelerate,
        );
      }
    }
  }

  void _handleSelectionChanged(Set<LegalKind> selection) {
    if (selection.isEmpty) return;
    final target = selection.first;
    setState(() {
      _selectedKind = target;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target.index,
        duration: AppDurations.medium3,
        curve: AppEasing.emphasizedDecelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = _selectedKind == LegalKind.privacy
        ? 'Privacy Policy'
        : 'Terms of Service';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<LegalKind>(
              segments: const [
                ButtonSegment<LegalKind>(
                  value: LegalKind.privacy,
                  label: Text('Privacy Policy'),
                  icon: Icon(Icons.privacy_tip_outlined, size: 18),
                ),
                ButtonSegment<LegalKind>(
                  value: LegalKind.terms,
                  label: Text('Terms of Service'),
                  icon: Icon(Icons.description_outlined, size: 18),
                ),
              ],
              selected: {_selectedKind},
              onSelectionChanged: _handleSelectionChanged,
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: GitHubIcon(
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    label: const Text(
                      'Open Source Project',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    onPressed: () => AppConfig.openRepository(),
                  ),
                ),
                Text(
                  'Last updated: May 2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedKind = LegalKind.values[index];
                });
              },
              children: const [
                _LegalList(sections: _privacySections),
                _LegalList(sections: _termsSections),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalList extends StatelessWidget {
  const _LegalList({required this.sections});

  final List<_SectionContent> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return _LegalSectionCard(sections[index]);
      },
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard(this.section);

  final _SectionContent section;

  IconData _iconForSection(String title) {
    final t = title.toLowerCase();
    if (t.contains('overview')) return Icons.info_outline_rounded;
    if (t.contains('collect')) {
      if (t.contains('not')) return Icons.gpp_good_outlined;
      return Icons.analytics_outlined;
    }
    if (t.contains('security') || t.contains('keychain')) return Icons.vpn_key_outlined;
    if (t.contains('cache') || t.contains('performance')) return Icons.speed_rounded;
    if (t.contains('permission') || t.contains('media')) return Icons.photo_library_outlined;
    if (t.contains('store')) return Icons.cloud_done_outlined;
    if (t.contains('transparency') || t.contains('license')) return Icons.code_rounded;
    if (t.contains('control')) return Icons.tune_rounded;
    if (t.contains('contact')) return Icons.mail_outline_rounded;
    if (t.contains('acceptance')) return Icons.assignment_turned_in_outlined;
    if (t.contains('description')) return Icons.dashboard_customize_outlined;
    if (t.contains('account')) return Icons.person_outline_rounded;
    if (t.contains('limit') || t.contains('api')) return Icons.gavel_rounded;
    if (t.contains('warranty') || t.contains('backup')) return Icons.backup_outlined;
    if (t.contains('change')) return Icons.update_rounded;
    if (t.contains('termination')) return Icons.cancel_presentation_rounded;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sectionIcon = _iconForSection(section.title);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: section.title.toLowerCase().contains('open source')
                      ? GitHubIcon(
                          size: 20,
                          color: scheme.primary,
                        )
                      : Icon(
                          sectionIcon,
                          size: 20,
                          color: scheme.primary,
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (section.paragraph != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  section.paragraph!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (section.bullets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final item in section.bullets) _BulletItem(item),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
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
        'TeleDrive stores only the minimum metadata needed to work as an efficient, modern file manager:',
    bullets: [
      'File names, sizes, types, and timestamps for your library, search, sorting, previews, and organization.',
      'Folder structure and structural directory references so your hierarchy can be restored seamlessly across devices.',
      'Telegram account details (user ID, name, username, and profile photo link) retrieved upon authentication.',
      'A server session and connection token stored securely on your device so the application can communicate with your backend.',
    ],
  ),
  _SectionContent(
    title: 'Local Device Security & Keychain',
    paragraph:
        'To guarantee maximum security of your connection credentials, all authenticated keys and credentials are saved locally in the device\'s hardware-backed keystore/keychain (utilizing flutter_secure_storage). They are isolated and never exposed to other apps.',
  ),
  _SectionContent(
    title: 'Media Caching & Performance',
    paragraph:
        'For fluid performance and network efficiency, the app caches image thumbnails, document previews, and streaming video chunks locally on your device (using cached_network_image and flutter_cache_manager). These temporary files live in secure cache directories and are permanently deleted when you sign out.',
  ),
  _SectionContent(
    title: 'On-Demand Media Access',
    paragraph:
        'TeleDrive requests access to your photos, camera, or file directories (using file_picker and image_picker) only when you explicitly tap to upload files. There is no automated, passive, or background scanning of your device\'s local storage.',
  ),
  _SectionContent(
    title: 'What We Do Not Collect',
    bullets: [
      'TeleDrive does not read, intercept, or analyze the actual content of your files.',
      'TeleDrive has no access to your personal Telegram chat messages, contacts, or channels unrelated to your drive.',
      'TeleDrive does not contain ads, trackers, analytics packages, or third-party telemetry. All communication is strictly client-to-server.',
    ],
  ),
  _SectionContent(
    title: 'Where Files Are Stored',
    paragraph:
        'Your files are hosted directly on Telegram\'s infrastructure. TeleDrive acts as a frontend management layer, storing references, metadata, and cache structures required to display and structure your library on your configured backend API.',
  ),
  _SectionContent(
    title: 'Open Source Transparency',
    paragraph:
        'Because TeleDrive is fully open source, you can audit the entire codebase, verify how your data is handled, and build or deploy the software yourself through the project repository.',
  ),
  _SectionContent(
    title: 'Your Controls',
    bullets: [
      'You can sign out of your account at any time, which fully deletes all local session keys and secure credentials from the device.',
      'Signing out completely flushes the cached previews, images, and document indices from your local device storage.',
      'Files uploaded to Telegram remain under your complete control and ownership in Telegram.',
    ],
  ),
  _SectionContent(
    title: 'Contact',
    paragraph:
        'For privacy questions, feel free to open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];

const _termsSections = [
  _SectionContent(
    title: 'Acceptance of Terms',
    paragraph:
        'By using TeleDrive, you agree to these terms. TeleDrive is open-source software provided as-is, and you use it at your own discretion and risk.',
  ),
  _SectionContent(
    title: 'Service Description',
    paragraph:
        'TeleDrive provides a sleek, cloud-like file management interface backed by Telegram storage. It allows you to upload, organize, preview, stream, and download files through the mobile app and your configured self-hosted backend API.',
  ),
  _SectionContent(
    title: 'Your Account & Security',
    bullets: [
      'You are solely responsible for securing your Telegram account and the device on which this application is installed.',
      'You are responsible for the files you upload and manage through TeleDrive.',
      'You must comply with all Telegram Terms of Service and applicable local and international laws.',
    ],
  ),
  _SectionContent(
    title: 'Telegram Platform and API Limits',
    paragraph:
        'Because TeleDrive leverages the Telegram API, you must respect Telegram\'s usage rules. The developers bear no responsibility or liability if Telegram rate-limits, restricts, or suspends your account due to heavy data uploads or terms violations.',
  ),
  _SectionContent(
    title: 'No Warranties & Off-Site Backup',
    paragraph:
        'TeleDrive is open-source and provided "as-is" without warranty of any kind. You are responsible for configuring the security of your self-hosted backend. The developers do not guarantee data integrity and strongly recommend maintaining independent backups of any critical files.',
  ),
  _SectionContent(
    title: 'Data and Storage',
    paragraph:
        'Your actual files reside on Telegram servers. TeleDrive stores structural references, names, folder trees, and configuration details solely to deliver an elegant drive interface on top of your chat storage.',
  ),
  _SectionContent(
    title: 'Open Source License',
    paragraph:
        'The TeleDrive codebase is licensed under its open-source license. You retain all rights and ownership of the content you upload and manage.',
  ),
  _SectionContent(
    title: 'Changes',
    paragraph:
        'As an active open-source project, TeleDrive will evolve over time. Features, APIs, and overall behavior can change as maintainers and contributors improve the codebase.',
  ),
  _SectionContent(
    title: 'Termination',
    paragraph:
        'You may terminate your use of TeleDrive at any time by signing out or uninstalling the app. Files uploaded to Telegram will remain accessible through Telegram directly.',
  ),
  _SectionContent(
    title: 'Contact',
    paragraph:
        'For questions about these terms, feel free to open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];

class GitHubIcon extends StatelessWidget {
  const GitHubIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GitHubPainter(color),
      ),
    );
  }
}

class _GitHubPainter extends CustomPainter {
  _GitHubPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    final scaleX = size.width / 16.0;
    final scaleY = size.height / 16.0;
    
    path.moveTo(8 * scaleX, 0 * scaleY);
    
    path.cubicTo(3.58 * scaleX, 0 * scaleY, 0 * scaleX, 3.58 * scaleY, 0 * scaleX, 8 * scaleY);
    path.cubicTo(0 * scaleX, 11.54 * scaleY, 2.29 * scaleX, 14.53 * scaleY, 5.47 * scaleX, 15.59 * scaleY);
    path.cubicTo(5.87 * scaleX, 15.66 * scaleY, 6.02 * scaleX, 15.42 * scaleY, 6.02 * scaleX, 15.21 * scaleY);
    path.cubicTo(6.02 * scaleX, 15.02 * scaleY, 6.01 * scaleX, 14.39 * scaleY, 6.01 * scaleX, 13.72 * scaleY);
    path.cubicTo(4.0 * scaleX, 14.09 * scaleY, 3.48 * scaleX, 13.23 * scaleY, 3.32 * scaleX, 12.78 * scaleY);
    path.cubicTo(3.23 * scaleX, 12.55 * scaleY, 2.84 * scaleX, 11.84 * scaleY, 2.5 * scaleX, 11.65 * scaleY);
    path.cubicTo(2.22 * scaleX, 11.5 * scaleY, 1.82 * scaleX, 11.13 * scaleY, 2.49 * scaleX, 11.12 * scaleY);
    path.cubicTo(3.12 * scaleX, 11.11 * scaleY, 3.57 * scaleX, 11.7 * scaleY, 3.72 * scaleX, 11.94 * scaleY);
    path.cubicTo(4.44 * scaleX, 13.15 * scaleY, 5.59 * scaleX, 12.81 * scaleY, 6.05 * scaleX, 12.6 * scaleY);
    path.cubicTo(6.12 * scaleX, 12.08 * scaleY, 6.33 * scaleX, 11.73 * scaleY, 6.56 * scaleX, 11.53 * scaleY);
    path.cubicTo(4.78 * scaleX, 11.33 * scaleY, 2.92 * scaleX, 10.64 * scaleY, 2.92 * scaleX, 7.58 * scaleY);
    path.cubicTo(2.92 * scaleX, 6.71 * scaleY, 3.23 * scaleX, 5.99 * scaleY, 3.74 * scaleX, 5.43 * scaleY);
    path.cubicTo(3.66 * scaleX, 5.23 * scaleY, 3.38 * scaleX, 4.41 * scaleY, 3.82 * scaleX, 3.31 * scaleY);
    path.cubicTo(3.82 * scaleX, 3.31 * scaleY, 4.49 * scaleX, 3.1 * scaleY, 6.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(6.66 * scaleX, 3.95 * scaleY, 7.34 * scaleX, 3.86 * scaleY, 8.02 * scaleX, 3.86 * scaleY);
    path.cubicTo(8.7 * scaleX, 3.86 * scaleY, 9.38 * scaleX, 3.95 * scaleY, 10.02 * scaleX, 4.13 * scaleY);
    path.cubicTo(11.55 * scaleX, 3.09 * scaleY, 12.22 * scaleX, 3.31 * scaleY, 12.22 * scaleX, 3.31 * scaleY);
    path.cubicTo(12.66 * scaleX, 4.41 * scaleY, 12.38 * scaleX, 5.23 * scaleY, 12.3 * scaleX, 5.43 * scaleY);
    path.cubicTo(12.81 * scaleX, 5.99 * scaleY, 13.12 * scaleX, 6.71 * scaleY, 13.12 * scaleX, 7.58 * scaleY);
    path.cubicTo(13.12 * scaleX, 10.65 * scaleY, 11.25 * scaleX, 11.33 * scaleY, 9.47 * scaleX, 11.53 * scaleY);
    path.cubicTo(9.76 * scaleX, 11.78 * scaleY, 10.01 * scaleX, 12.26 * scaleY, 10.01 * scaleX, 13.01 * scaleY);
    path.cubicTo(10.01 * scaleX, 14.08 * scaleY, 10.0 * scaleX, 14.94 * scaleY, 10.0 * scaleX, 15.21 * scaleY);
    path.cubicTo(10.0 * scaleX, 15.42 * scaleY, 10.15 * scaleX, 15.67 * scaleY, 10.55 * scaleX, 15.59 * scaleY);
    path.cubicTo(13.73 * scaleX, 14.53 * scaleY, 16.0 * scaleX, 11.54 * scaleY, 16.0 * scaleX, 8.0 * scaleY);
    path.cubicTo(16.0 * scaleX, 3.58 * scaleY, 12.42 * scaleX, 0 * scaleY, 8.0 * scaleX, 0 * scaleY);
    
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
