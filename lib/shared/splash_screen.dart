import 'package:flutter/material.dart';
import '../widgets/brand_mark.dart';

/// Startup reflects real authentication work, with no decorative delay.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: 24),
            Text(
              'TeleDrive',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator.adaptive(
              semanticsLabel: 'Opening your drive',
            ),
          ],
        ),
      ),
    ),
  );
}
