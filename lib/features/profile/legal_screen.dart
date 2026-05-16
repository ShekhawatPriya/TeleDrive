import 'package:flutter/material.dart';

enum LegalKind { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.kind, super.key});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final title = kind == LegalKind.privacy
        ? 'Privacy Policy'
        : 'Terms of Service';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text(
            kind == LegalKind.privacy
                ? 'TeleDrive stores your authentication token securely on this device and uses your backend to access Telegram files, thumbnails, previews, streams, and uploads. No file data is cached manually by this app beyond standard media and temporary download caches.'
                : 'TeleDrive is a client for your Telegram-backed drive. You are responsible for the files you upload and for keeping your Telegram account secure. Development builds may use cleartext LAN HTTP; production deployments should use HTTPS.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
