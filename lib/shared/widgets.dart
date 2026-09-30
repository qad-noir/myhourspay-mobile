import 'package:flutter/material.dart';

import '../core/api_client.dart';

const brandInk = Color(0xff171421);
const brandOrange = Color(0xffff6b35);
const brandSurface = Color(0xfffbf8f3);
ThemeData mhpTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: brandSurface,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brandOrange,
    primary: const Color(0xffac3810),
    surface: brandSurface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: brandSurface,
    foregroundColor: brandInk,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: .5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(64, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: brandInk,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: brandInk,
    ),
  ),
);

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(24), children: children),
      ),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.failure, {super.key});
  final ApiFailure? failure;
  @override
  Widget build(BuildContext context) => failure == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${failure!.message}${failure!.retryAt == null ? '' : ' Wait until ${TimeOfDay.fromDateTime(failure!.retryAt!.toLocal()).format(context)}.'}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key});
  final String? text;
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(liveRegion: true, child: Text(text!)),
        );
}
