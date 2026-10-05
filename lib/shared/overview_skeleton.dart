import 'package:flutter/material.dart';

import 'widgets.dart';

/// A complete dashboard placeholder; no live values or actions appear midway
/// through the first load. Sizes follow the dashboard's content sections.
class OverviewSkeleton extends StatelessWidget {
  const OverviewSkeleton({
    super.key,
    required this.monthly,
    this.calendarRows = 5,
  });
  final bool monthly;
  final int calendarRows;

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width}) => SkeletonRegion(
      loading: true,
      child: SizedBox(height: height, width: width ?? double.infinity),
    );
    return Semantics(
      label: 'Loading overview',
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  block(38, width: 36),
                  const SizedBox(width: 12),
                  Expanded(child: block(20)),
                  const SizedBox(width: 64),
                  block(38, width: 38),
                ],
              ),
              const SizedBox(height: 24),
              block(36, width: 190),
              const SizedBox(height: 8),
              block(20, width: 160),
              const SizedBox(height: 14),
              block(48),
              const SizedBox(height: 4),
              block(56),
              const SizedBox(height: 14),
              if (monthly) ...[
                Row(
                  children: [
                    Expanded(child: block(136)),
                    const SizedBox(width: 12),
                    Expanded(child: block(136)),
                  ],
                ),
                const SizedBox(height: 12),
                block(50),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(26, width: 170),
                      const SizedBox(height: 12),
                      block(18),
                      const SizedBox(height: 8),
                      for (var row = 0; row < calendarRows; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              for (var day = 0; day < 7; day++) ...[
                                if (day > 0) const SizedBox(width: 3),
                                Expanded(child: block(52)),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                block(100),
                const SizedBox(height: 16),
                block(350),
              ] else ...[
                block(110),
                const SizedBox(height: 28),
                block(24, width: 140),
                const SizedBox(height: 14),
                for (var row = 0; row < 3; row++) ...[
                  block(76),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
