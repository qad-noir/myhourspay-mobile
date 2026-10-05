import 'package:flutter/material.dart';

import 'widgets.dart';

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/brand-mark.png',
                width: 132,
                height: 132,
                excludeFromSemantics: true,
              ),
              SizedBox(height: 18),
              Text(
                'MyHoursPay',
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 9),
              Text(
                'Your time. In order.',
                style: TextStyle(
                  fontSize: 16,
                  color: mhpColor(context, brandMuted),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36),
              Semantics(
                label: 'Loading MyHoursPay',
                child: SizedBox(
                  width: 96,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: brandOrange,
                    backgroundColor: mhpColor(context, brandPeach),
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
