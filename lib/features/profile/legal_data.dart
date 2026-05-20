class SectionContent {
  const SectionContent({
    required this.title,
    this.paragraph,
    this.bullets = const [],
  });

  final String title;
  final String? paragraph;
  final List<String> bullets;
}

const privacySections = [
  SectionContent(
    title: 'Overview',
    paragraph:
        'TeleDrive is an open-source Telegram-backed drive project. The app is designed to be transparent about what it accesses, what it stores, and why.',
  ),
  SectionContent(
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
  SectionContent(
    title: 'Local Device Security & Keychain',
    paragraph:
        'To guarantee maximum security of your connection credentials, all authenticated keys and credentials are saved locally in the device\'s hardware-backed keystore/keychain (utilizing flutter_secure_storage). They are isolated and never exposed to other apps.',
  ),
  SectionContent(
    title: 'Media Caching & Performance',
    paragraph:
        'For fluid performance and network efficiency, the app caches image thumbnails, document previews, and streaming video chunks locally on your device (using cached_network_image and flutter_cache_manager). These temporary files live in secure cache directories and are permanently deleted when you sign out.',
  ),
  SectionContent(
    title: 'On-Demand Media Access',
    paragraph:
        'TeleDrive requests access to your photos, camera, or file directories (using file_picker and image_picker) only when you explicitly tap to upload files. There is no automated, passive, or background scanning of your device\'s local storage.',
  ),
  SectionContent(
    title: 'What We Do Not Collect',
    bullets: [
      'TeleDrive does not read, intercept, or analyze the actual content of your files.',
      'TeleDrive has no access to your personal Telegram chat messages, contacts, or channels unrelated to your drive.',
      'TeleDrive does not contain ads, trackers, analytics packages, or third-party telemetry. All communication is strictly client-to-server.',
    ],
  ),
  SectionContent(
    title: 'Where Files Are Stored',
    paragraph:
        'Your files are hosted directly on Telegram\'s infrastructure. TeleDrive acts as a frontend management layer, storing references, metadata, and cache structures required to display and structure your library on your configured backend API.',
  ),
  SectionContent(
    title: 'Open Source Transparency',
    paragraph:
        'Because TeleDrive is fully open source, you can audit the entire codebase, verify how your data is handled, and build or deploy the software yourself through the project repository.',
  ),
  SectionContent(
    title: 'Your Controls',
    bullets: [
      'You can sign out of your account at any time, which fully deletes all local session keys and secure credentials from the device.',
      'Signing out completely flushes the cached previews, images, and document indices from your local device storage.',
      'Files uploaded to Telegram remain under your complete control and ownership in Telegram.',
    ],
  ),
  SectionContent(
    title: 'Contact',
    paragraph:
        'For privacy questions, feel free to open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];

const termsSections = [
  SectionContent(
    title: 'Acceptance of Terms',
    paragraph:
        'By using TeleDrive, you agree to these terms. TeleDrive is open-source software provided as-is, and you use it at your own discretion and risk.',
  ),
  SectionContent(
    title: 'Service Description',
    paragraph:
        'TeleDrive provides a sleek, cloud-like file management interface backed by Telegram storage. It allows you to upload, organize, preview, stream, and download files through the mobile app and your configured self-hosted backend API.',
  ),
  SectionContent(
    title: 'Your Account & Security',
    bullets: [
      'You are solely responsible for securing your Telegram account and the device on which this application is installed.',
      'You are responsible for the files you upload and manage through TeleDrive.',
      'You must comply with all Telegram Terms of Service and applicable local and international laws.',
    ],
  ),
  SectionContent(
    title: 'Telegram Platform and API Limits',
    paragraph:
        'Because TeleDrive leverages the Telegram API, you must respect Telegram\'s usage rules. The developers bear no responsibility or liability if Telegram rate-limits, restricts, or suspends your account due to heavy data uploads or terms violations.',
  ),
  SectionContent(
    title: 'No Warranties & Off-Site Backup',
    paragraph:
        'TeleDrive is open-source and provided "as-is" without warranty of any kind. You are responsible for configuring the security of your self-hosted backend. The developers do not guarantee data integrity and strongly recommend maintaining independent backups of any critical files.',
  ),
  SectionContent(
    title: 'Data and Storage',
    paragraph:
        'Your actual files reside on Telegram servers. TeleDrive stores structural references, names, folder trees, and configuration details solely to deliver an elegant drive interface on top of your chat storage.',
  ),
  SectionContent(
    title: 'Open Source License',
    paragraph:
        'The TeleDrive codebase is licensed under its open-source license. You retain all rights and ownership of the content you upload and manage.',
  ),
  SectionContent(
    title: 'Changes',
    paragraph:
        'As an active open-source project, TeleDrive will evolve over time. Features, APIs, and overall behavior can change as maintainers and contributors improve the codebase.',
  ),
  SectionContent(
    title: 'Termination',
    paragraph:
        'You may terminate your use of TeleDrive at any time by signing out or uninstalling the app. Files uploaded to Telegram will remain accessible through Telegram directly.',
  ),
  SectionContent(
    title: 'Contact',
    paragraph:
        'For questions about these terms, feel free to open an issue in the project repository or contact the DevsDoCode project maintainers.',
  ),
];
