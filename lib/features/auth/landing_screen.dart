import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'components/fade_in_slide.dart';
import 'components/final_cta_and_footer.dart';
import 'components/hero_section.dart';
import 'components/how_it_works_section.dart';
import 'components/open_source_section.dart';
import 'components/privacy_and_trust_section.dart';
import 'components/storage_separation_section.dart';

/// A premium pre-login landing screen that introduces TeleDrive,
/// explains storage concepts, and guides unauthenticated users.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Section
                  FadeInSlide(
                    delay: Duration.zero,
                    child: HeroSection(),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // 2. How it works Section
                  FadeInSlide(
                    delay: Duration(milliseconds: 150),
                    child: HowItWorksSection(),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // 3. Storage Separation Section
                  FadeInSlide(
                    delay: Duration(milliseconds: 300),
                    child: StorageSeparationSection(),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // 4. Privacy & Trust Section
                  FadeInSlide(
                    delay: Duration(milliseconds: 450),
                    child: PrivacyAndTrustSection(),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // 5. Open Source Section
                  FadeInSlide(
                    delay: Duration(milliseconds: 600),
                    child: OpenSourceSection(),
                  ),
                  SizedBox(height: AppSpacing.xxl),

                  // 6. Final CTA & Footer Section
                  FadeInSlide(
                    delay: Duration(milliseconds: 700),
                    child: FinalCtaAndFooter(),
                  ),
                  SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
