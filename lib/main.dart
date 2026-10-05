import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/api_client.dart';
import 'core/appearance.dart';
import 'core/device_name.dart';
import 'core/api_environment.dart';
import 'core/secure_session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/google_identity.dart';
import 'features/hours/hours_screen.dart';
import 'features/hours/repository.dart';
import 'features/session/session_model.dart';
import 'shared/widgets.dart';
import 'shared/branded_loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try {
    final config = ApiEnvironment.parse(
      const String.fromEnvironment('APP_ENV'),
      const String.fromEnvironment('API_BASE_URL'),
      release: kReleaseMode,
    );
    final api = ApiClient(
      config,
      onDiagnostic: kDebugMode ? (line) => debugPrint(line) : null,
    );
    runApp(
      MhpApp(
        googleIdentity: NativeGoogleIdentity(
          serverClientId: const String.fromEnvironment(
            'GOOGLE_SERVER_CLIENT_ID',
          ),
          iosClientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
        ),
        model: SessionModel(
          AuthRepository(api),
          HoursRepository(api),
          SecureSessionStore(config.base.toString()),
        ),
      ),
    );
  } on FormatException catch (error) {
    runApp(
      MaterialApp(
        theme: mhpTheme(),
        home: Scaffold(
          body: PageBody(
            children: [
              const SizedBox(height: 64),
              const Text('MHP setup required'),
              const SizedBox(height: 16),
              Text(error.message),
              const Text(
                'No API connection has been made. See docs/SETUP.md for local build configuration.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MhpApp extends StatefulWidget {
  const MhpApp({
    super.key,
    required this.model,
    this.deviceLabelLoader = resolveDeviceName,
    this.googleIdentity,
    this.appearance,
  });
  final SessionModel model;
  final Future<String> Function() deviceLabelLoader;
  final GoogleIdentity? googleIdentity;
  final AppearanceController? appearance;
  @override
  State<MhpApp> createState() => _MhpAppState();
}

class _MhpAppState extends State<MhpApp> {
  late final appearance =
      widget.appearance ?? AppearanceController(SecureAppearanceStore());
  final messenger = GlobalKey<ScaffoldMessengerState>();
  void showToast() {
    final message = widget.model.toast;
    if (message == null) return;
    widget.model.toast = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.currentState?.hideCurrentSnackBar();
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    widget.model.addListener(showToast);
    widget.model.restore();
    appearance.addListener(appearanceChanged);
    appearance.load();
  }

  void appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.model.removeListener(showToast);
    appearance.removeListener(appearanceChanged);
    if (widget.appearance == null) appearance.dispose();
    widget.model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
    controller: appearance,
    child: MaterialApp(
      title: 'MyHoursPay',
      scaffoldMessengerKey: messenger,
      debugShowCheckedModeBanner: false,
      theme: mhpTheme(),
      darkTheme: mhpTheme(dark: true),
      themeMode: appearance.mode,
      builder: phoneShell,
      home: ListenableBuilder(
        listenable: widget.model,
        builder: (context, _) {
          final model = widget.model;
          // Rebuild the navigator to discard private routes after logout or restriction.
          final gate =
              '${model.sessionRevision}:${model.phase}:${model.workspace?.id}';
          return Navigator(
            key: ValueKey(gate),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ListenableBuilder(
                listenable: model,
                builder: (context, _) => home(context, model),
              ),
            ),
          );
        },
      ),
    ),
  );
  Widget home(BuildContext context, SessionModel model) =>
      switch (model.phase) {
        SessionPhase.signedOut || SessionPhase.expired => LoginScreen(
          model: model,
          deviceLabelLoader: widget.deviceLabelLoader,
          providerActions: {
            if (widget.googleIdentity?.configured == true)
              'google': () => model.googleSignIn(
                widget.googleIdentity!.acquireCredential,
                widget.deviceLabelLoader,
              ),
          },
          signupProviderActions: {
            if (widget.googleIdentity?.configured == true)
              'google': (name, terms, marketing) async {
                await model.googleSignIn(
                  widget.googleIdentity!.acquireCredential,
                  widget.deviceLabelLoader,
                  terms: terms,
                );
              },
          },
        ),
        SessionPhase.twoFactorChallenge => ChallengeScreen(
          model: model,
          emailVerification: false,
        ),
        SessionPhase.verificationRequired => ChallengeScreen(
          model: model,
          emailVerification: true,
        ),
        SessionPhase.onboardingRequired || SessionPhase.authenticated =>
          model.workspace == null
              ? WorkspaceScreen(model: model)
              : HoursScreen(model: model),
        SessionPhase.restricted => Scaffold(
          body: PageBody(
            children: [
              const SizedBox(height: 48),
              Text(
                'Account action required',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Notice(
                'Your account has a restriction that cannot be resolved in this app. Contact MHP support for help.',
              ),
              ErrorNotice(model.failure),
              FilledButton(
                onPressed: model.busy ? null : model.refreshAccount,
                child: const Text('Check again'),
              ),
              TextButton(
                onPressed: model.busy ? null : model.logout,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
        SessionPhase.restoring =>
          model.busy
              ? const BrandedLoadingScreen()
              : Scaffold(
                  body: PageBody(
                    children: [
                      const SizedBox(height: 64),
                      if (model.busy)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        ErrorNotice(model.failure),
                        FilledButton(
                          onPressed: model.restore,
                          child: const Text('Retry connection'),
                        ),
                        TextButton(
                          onPressed: model.logout,
                          child: const Text('Sign out on this device'),
                        ),
                      ],
                    ],
                  ),
                ),
      };
}
