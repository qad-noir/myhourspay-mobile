import 'package:flutter/material.dart';

import '../core/api_client.dart';

const brandInk = Color(0xff171421);
const brandOrange = Color(0xffff6b35);
const brandAction = Color(0xffcf4515); // White label contrast exceeds 4.5:1.
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
);
const totalStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 40,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.6,
);
Color mhpColor(BuildContext context, Color light) {
  if (Theme.of(context).brightness != Brightness.dark) return light;
  if (light == brandInk) return const Color(0xfff5f1eb);
  if (light == brandMuted) return const Color(0xffb5b2bf);
  if (light == brandBorder) return const Color(0xff39363f);
  if (light == brandSurface) return const Color(0xff151319);
  if (light == brandAction) return const Color(0xffff926d);
  if (light == brandPeach) return const Color(0xff422a23);
  if (light == brandGreen) return const Color(0xff223a2c);
  if (light == const Color(0xffb3261e)) {
    return Theme.of(context).colorScheme.error;
  }
  if (light == Colors.white) return const Color(0xff211e26);
  if (light.computeLuminance() > .65) {
    if (light.g > light.r && light.g > light.b) return const Color(0xff223a2c);
    if (light.r > light.g + .03) return const Color(0xff422a23);
    return const Color(0xff29262f);
  }
  if (light.g > light.r &&
      light.g > light.b &&
      light.computeLuminance() < .25) {
    return const Color(0xff8edbb3);
  }
  return light;
}

ThemeData mhpTheme({bool dark = false}) {
  final ink = dark ? const Color(0xfff5f1eb) : brandInk;
  final muted = dark ? const Color(0xffb5b2bf) : brandMuted;
  final surface = dark ? const Color(0xff151319) : brandSurface;
  final outline = dark ? const Color(0xff39363f) : brandBorder;
  final action = dark ? const Color(0xffff926d) : brandAction;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: BorderSide(color: outline),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: action,
      onPrimary: dark ? brandInk : Colors.white,
      secondary: brandOrange,
      onSecondary: brandInk,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: outline,
      error: dark ? const Color(0xffffaaa4) : const Color(0xffb3261e),
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      headlineLarge: titleStyle,
      headlineMedium: titleStyle,
      titleLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: ink),
      bodyMedium: TextStyle(fontSize: 15, color: ink),
      bodySmall: TextStyle(fontSize: 13, color: muted),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    iconTheme: IconThemeData(size: 22, color: muted),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? const Color(0xff211e26)
          : Colors.white.withValues(alpha: .35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: action)),
      labelStyle: TextStyle(color: muted, fontSize: 15),
      hintStyle: TextStyle(color: muted, fontSize: 14),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: action,
        foregroundColor: dark ? brandInk : Colors.white,
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
        side: BorderSide(color: outline),
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
    this.fillViewport = true,
    this.padding = const EdgeInsets.all(22),
  });
  final List<Widget> children;
  final Widget? footer;
  final bool fillViewport;
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
          child: fillViewport
              ? IntrinsicHeight(child: content(true))
              : content(false),
        ),
      ),
    ),
  );
  Widget content(bool fill) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...children,
      if (footer != null) ...[
        if (fill) Spacer(),
        SizedBox(height: 24),
        footer!,
      ],
    ],
  );
}

Widget phoneShell(BuildContext context, Widget? child) => ColoredBox(
  color: mhpColor(context, brandBorder),
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 430),
      child: child ?? SizedBox.shrink(),
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
      color:
          Theme.of(context).brightness == Brightness.dark &&
              color == const Color(0x88ffffff)
          ? const Color(0xff211e26)
          : mhpColor(context, color),
      border: Border.all(color: mhpColor(context, borderColor)),
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
    color: success
        ? mhpColor(context, brandGreen)
        : mhpColor(context, Color(0xfff0f0f2)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          success ? Icons.check_circle_outline : Icons.info_outline,
          color: success
              ? mhpColor(context, Color(0xff28633e))
              : mhpColor(context, brandInk),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, height: 1.5)),
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
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: success
          ? mhpColor(context, Color(0xffdcefe4))
          : mhpColor(context, brandPeach),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: success
            ? mhpColor(context, Color(0xff17613c))
            : mhpColor(context, brandAction),
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
    backgroundColor: peach
        ? mhpColor(context, brandPeach)
        : mhpColor(context, Color(0xffeae9e8)),
    child: Text(
      name.trim().isEmpty
          ? '?'
          : name.trim().split(RegExp(r'\s+')).take(2).map((v) => v[0]).join(),
      style: TextStyle(
        color: mhpColor(context, brandInk),
        fontSize: size * .32,
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        color: mhpColor(context, brandMuted),
        fontSize: 12,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Keeps the content's measured geometry while a slow wave crosses its placeholder.
class SkeletonRegion extends StatefulWidget {
  const SkeletonRegion({super.key, required this.loading, required this.child});
  final bool loading;
  final Widget child;
  @override
  State<SkeletonRegion> createState() => _SkeletonRegionState();
}

class _SkeletonRegionState extends State<SkeletonRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateAnimation();
  }

  @override
  void didUpdateWidget(SkeletonRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateAnimation();
  }

  void updateAnimation() {
    if (widget.loading && !MediaQuery.disableAnimationsOf(context)) {
      if (!wave.isAnimating) wave.repeat();
    } else {
      wave.stop();
    }
  }

  @override
  void dispose() {
    wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) return widget.child;
    final base = mhpColor(context, brandBorder);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Stack(
            children: [
              Opacity(opacity: 0, child: widget.child),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: wave,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment(wave.value * 4 - 3, 0),
                        end: Alignment(wave.value * 4 - 1, 0),
                        colors: [
                          base,
                          Color.lerp(
                            base,
                            Theme.of(context).colorScheme.onSurface,
                            .12,
                          )!,
                          base,
                        ],
                        stops: const [0, .5, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: SkeletonRegion(
      loading: true,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      color: mhpColor(context, brandBorder),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 16,
                        color: mhpColor(context, brandBorder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String friendlyFailure(ApiFailure f) {
  if (f.code == 'account_link_required') {
    return 'This email already has an account. Sign in with your password before linking Google.';
  }
  if (f.code == 'credential_already_used') {
    return 'Start a new Google or Apple sign-in attempt.';
  }
  if ([
    'google_challenge_used',
    'google_challenge_expired',
    'google_challenge_invalid',
    'google_nonce_mismatch',
  ].contains(f.code)) {
    return 'This Google sign-in attempt is no longer valid. Please start a new attempt.';
  }
  if (f.code == 'google_signup_required') {
    return 'To create a new account with Google, choose Create account and accept the terms. Google supplies your name and email.';
  }
  if (f.code == 'invalid_provider_credential') {
    return 'Google or Apple rejected the sign-in credential. Start a new sign-in attempt. If it continues, contact support.';
  }
  if (f.code == 'provider_email_required') {
    return 'Your sign-in provider must share an email address to continue.';
  }
  if (f.code == 'google_exchange_rejected') {
    return f.message;
  }
  if (f.code == 'invalid_credentials') {
    return 'The email or password is incorrect.';
  }
  if (f.status == 401) {
    return 'Sign-in was rejected by the server. Check your credentials and API configuration.';
  }
  if (f.status == 404) {
    return 'The requested API route is unavailable. Check the API URL and backend deployment.';
  }
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
  if (f.status == 422) {
    return f.fields.isEmpty
        ? 'The server rejected this action. Please try again. If it continues, contact support.'
        : 'Check the highlighted details and try again.';
  }
  return f.status == 0
      ? f.message
      : 'This action could not be completed. Please try again.';
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.failure, {super.key});
  final ApiFailure? failure;
  @override
  Widget build(BuildContext context) => failure == null
      ? SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
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
      ? SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Semantics(liveRegion: true, child: Text(text!)),
        );
}
