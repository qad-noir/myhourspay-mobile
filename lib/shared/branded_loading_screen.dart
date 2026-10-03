import 'package:flutter/material.dart';

import 'widgets.dart';

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/brand-mark.png',
                width: 132,
                height: 132,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 18),
              const Text(
                'MyHoursPay',
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              const Text(
                'Your time. In order.',
                style: TextStyle(fontSize: 16, color: brandMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              Semantics(
                label: 'Loading MyHoursPay',
                child: const SizedBox(
                  width: 96,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: brandOrange,
                    backgroundColor: brandPeach,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
