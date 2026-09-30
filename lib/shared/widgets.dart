import 'package:flutter/material.dart';

import '../core/api_client.dart';

const brandInk = Color(0xff171421);
const brandOrange = Color(0xffff6b35);
const brandAction = Color(0xffc34312); // White label contrast exceeds 4.5:1.
const brandSurface = Color(0xfffbf8f3);
const brandMuted = Color(0xff686a76);
const brandBorder = Color(0xffe3e0dc);
const brandPeach = Color(0xffffe8da);
const brandGreen = Color(0xffe4efdf);
const titleStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 28,
  fontWeight: FontWeight.w800,
  letterSpacing: -1,
  color: brandInk,
);
const totalStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 40,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.6,
  color: brandInk,
);
ThemeData mhpTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: brandBorder),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: brandSurface,
    colorScheme: const ColorScheme.light(
      primary: brandAction,
      onPrimary: Colors.white,
      secondary: brandOrange,
      surface: brandSurface,
      onSurface: brandInk,
      onSurfaceVariant: brandMuted,
      outline: brandBorder,
      error: Color(0xffb3261e),
    ),
    textTheme: const TextTheme(
      headlineLarge: titleStyle,
      headlineMedium: titleStyle,
      titleLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: brandInk),
      bodyMedium: TextStyle(fontSize: 15, color: brandInk),
      bodySmall: TextStyle(fontSize: 13, color: brandMuted),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: brandSurface,
      foregroundColor: brandInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: brandInk,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: brandBorder,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(size: 22, color: brandMuted),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: brandAction),
      ),
      labelStyle: const TextStyle(color: brandMuted, fontSize: 15),
      hintStyle: const TextStyle(color: brandMuted, fontSize: 14),
      prefixIconColor: brandMuted,
      suffixIconColor: brandMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandAction,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: brandBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}

/// Fills the available viewport; the flexible gap yields to scrolling/keyboard.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.footer,
    this.padding = const EdgeInsets.all(22),
  });
  final List<Widget> children;
  final Widget? footer;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (c.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                if (footer != null) ...[
                  const Spacer(),
                  const SizedBox(height: 24),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget phoneShell(BuildContext context, Widget? child) => ColoredBox(
  color: brandBorder,
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: child ?? const SizedBox.shrink(),
    ),
  ),
);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = const Color(0x88ffffff),
    this.padding = const EdgeInsets.all(16),
    this.borderColor = brandBorder,
  });
  final Widget child;
  final Color color, borderColor;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(11),
    ),
    child: child,
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel(this.text, {super.key, this.success = false});
  final String text;
  final bool success;
  @override
  Widget build(BuildContext context) => Panel(
    color: success ? brandGreen : const Color(0xfff0f0f2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          success ? Icons.check_circle_outline : Icons.info_outline,
          color: success ? const Color(0xff28633e) : brandInk,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, this.success = false});
  final String text;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: success ? const Color(0xffdcefe4) : brandPeach,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: success ? const Color(0xff17613c) : brandAction,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar(
    this.name, {
    super.key,
    this.size = 48,
    this.peach = false,
  });
  final String name;
  final double size;
  final bool peach;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size / 2,
    backgroundColor: peach ? brandPeach : const Color(0xffeae9e8),
    child: Text(
      name.trim().isEmpty
          ? '?'
          : name.trim().split(RegExp(r'\s+')).take(2).map((v) => v[0]).join(),
      style: TextStyle(color: brandInk, fontSize: size * .32),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(color: brandMuted, fontSize: 12, letterSpacing: 1),
    ),
  );
}

class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Row(
                children: [
                  Container(width: 44, height: 44, color: brandBorder),
                  const SizedBox(width: 16),
                  Expanded(child: Container(height: 16, color: brandBorder)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

String friendlyFailure(ApiFailure f) {
  if (f.status == 401) return 'Your session has expired. Please sign in again.';
  if (f.status == 403) {
    return 'You do not have permission for this action in this workspace.';
  }
  if (f.status == 429) {
    return 'Too many attempts. Please wait before trying again.';
  }
  if (f.status >= 500) {
    return 'MHP is temporarily unavailable. Please try again shortly.';
  }
  if (f.code == 'network_error' || f.code == 'timeout') {
    return 'Cannot connect to MHP. Check your connection and try again.';
  }
  if (f.status == 409) {
    return 'This record has changed or is locked. Reload the server version before continuing.';
  }
  if (f.status == 422) return 'Check the highlighted details and try again.';
  return f.status == 0
      ? f.message
      : 'This action could not be completed. Please try again.';
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
              '${friendlyFailure(failure!)}${failure!.retryAt == null ? '' : ' Try after ${TimeOfDay.fromDateTime(failure!.retryAt!.toLocal()).format(context)}.'}',
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
