import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_rounded, size: 54),
            SizedBox(height: 18),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
