import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../session/session_model.dart';

String get deviceName {
  if (kIsWeb) return 'MHP Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'MHP Android',
    TargetPlatform.iOS => 'MHP iPhone',
    final platform => 'MHP ${platform.name}',
  };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.model,
    this.providerActions = const {},
  });
  final SessionModel model;
  // Only configured integrations supply actions; fixtures inject isolated callbacks.
  final Map<String, VoidCallback> providerActions;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      confirmation = TextEditingController();
  bool register = false, hidden = true, terms = false, marketing = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> openLegal(String path) async {
    final url = widget.model.auth.api.environment.base.replace(
      path: path,
      query: null,
      fragment: null,
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the legal page. Please read it on the MHP website.',
            ),
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (register) {
      await widget.model.register({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'password_confirmation': confirmation.text,
        'device_name': deviceName,
        'terms': terms,
        'marketing_consent': marketing,
      });
    } else {
      await widget.model.login(email.text.trim(), password.text, deviceName);
    }
    password.clear();
    confirmation.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Scaffold(
      body: Form(
        key: form,
        child: PageBody(
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                register
                    ? 'Already have an account?'
                    : 'Don’t have an account?',
                style: const TextStyle(color: brandMuted, fontSize: 14),
              ),
              TextButton(
                onPressed: model.busy
                    ? null
                    : () => setState(() {
                        register = !register;
                        password.clear();
                        confirmation.clear();
                      }),
                child: Text(register ? 'Sign in' : 'Create account'),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Image.asset(
                'assets/brand/brand-mark.png',
                width: 56,
                height: 56,
                semanticLabel: 'MyHoursPay',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MyHoursPay',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),
            Text(
              register ? 'Create your account' : 'Your time. In order.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              register
                  ? 'Track your time across your MHP workspaces.'
                  : 'Welcome back.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (register) ...[
              TextFormField(
                controller: name,
                enabled: !model.busy,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: 'Full name',
                  errorText: model.failure?.fields['name']?.firstOrNull,
                ),
                validator: (v) => v!.trim().isEmpty ? 'Enter your name.' : null,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: email,
              enabled: !model.busy,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: model.failure?.fields['email']?.firstOrNull,
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? 'Enter your email address.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              enabled: !model.busy,
              obscureText: hidden,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: model.failure?.fields['password']?.firstOrNull,
                suffixIcon: IconButton(
                  tooltip: hidden ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => hidden = !hidden),
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Enter your password.' : null,
            ),
            if (register) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmation,
                enabled: !model.busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (v) =>
                    v != password.text ? 'Passwords must match.' : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I accept the MHP terms and privacy policy.'),
                value: terms,
                onChanged: model.busy
                    ? null
                    : (v) => setState(() => terms = v!),
              ),
              const Text(
                'Read the terms and privacy policy before creating your account.',
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => openLegal('/terms'),
                    child: const Text('Terms of service'),
                  ),
                  TextButton(
                    onPressed: () => openLegal('/policy'),
                    child: const Text('Privacy policy'),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Send me optional product news'),
                value: marketing,
                onChanged: model.busy
                    ? null
                    : (v) => setState(() => marketing = v!),
              ),
            ],
            if (model.phase != SessionPhase.expired) ErrorNotice(model.failure),
            Notice(
              model.phase == SessionPhase.expired
                  ? 'Your session has expired. Please sign in again.'
                  : model.notice,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: model.busy || (register && !terms) ? null : submit,
              child: Text(
                model.busy
                    ? 'Please wait…'
                    : register
                    ? 'Create account'
                    : 'Sign in',
              ),
            ),
            if (!register)
              TextButton(
                onPressed: model.busy
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => ForgotPasswordDialog(
                          model: model,
                          initialEmail: email.text,
                        ),
                      ),
                child: const Text('Forgot password?'),
              ),
            if (!register &&
                widget.providerActions.keys.any(
                  (p) => model.providers[p] == true,
                )) ...[
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(fontSize: 13, color: brandMuted),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              for (final provider in ['google', 'apple'])
                if (model.providers[provider] == true &&
                    widget.providerActions.containsKey(provider))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: model.busy
                          ? null
                          : widget.providerActions[provider],
                      icon: provider == 'google'
                          ? Image.asset(
                              'assets/providers/google.png',
                              width: 22,
                              height: 22,
                            )
                          : Image.asset(
                              'assets/providers/apple.png',
                              width: 39,
                              height: 44,
                            ),
                      label: Text(
                        'Continue with ${provider == 'google' ? 'Google' : 'Apple'}',
                        style: const TextStyle(color: brandInk),
                      ),
                    ),
                  ),
            ],
            // Provider SDKs/IDs are not configured. No action is exposed merely because
            // the server can verify a credential. Availability is fetched by SessionModel.
          ],
        ),
      ),
    );
  }
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.model,
    required this.emailVerification,
  });
  final SessionModel model;
  final bool emailVerification;
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final code = TextEditingController();
  bool recovery = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final toggle = TextButton(
      onPressed: model.busy
          ? null
          : () => setState(() {
              recovery = !recovery;
              code.clear();
            }),
      child: Text(
        recovery ? 'Use an authenticator code' : 'Use a recovery code',
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to sign in',
          icon: const Icon(Icons.arrow_back),
          onPressed: model.busy
              ? null
              : widget.emailVerification
              ? model.logout
              : model.cancelChallenge,
        ),
      ),
      body: PageBody(
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: model.busy
                  ? null
                  : () async {
                      if (widget.emailVerification) {
                        await model.verify(code.text.trim());
                      } else {
                        await model.completeMfa(code.text.trim(), recovery);
                      }
                      code.clear();
                    },
              child: Text(model.busy ? 'Verifying…' : 'Verify and continue'),
            ),
            const SizedBox(height: 8),
            widget.emailVerification
                ? TextButton(
                    onPressed: model.busy ? null : model.resend,
                    child: const Text('Resend code'),
                  )
                : toggle,
          ],
        ),
        children: [
          const SizedBox(height: 56),
          Icon(
            widget.emailVerification
                ? Icons.mark_email_read_outlined
                : Icons.verified_user_outlined,
            size: 76,
            color: brandOrange,
          ),
          const SizedBox(height: 30),
          Text(
            widget.emailVerification ? 'Verify your email' : 'One more step',
            style: titleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            widget.emailVerification
                ? 'Enter the 6-digit code sent to ${model.account?.email ?? 'your email'}.'
                : recovery
                ? 'Enter one of your unused recovery codes.'
                : 'Enter the 6-digit code from your authenticator app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: brandMuted, fontSize: 16),
          ),
          const SizedBox(height: 44),
          if (recovery)
            TextField(
              controller: code,
              enabled: !model.busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Recovery code'),
            )
          else
            CodeInput(controller: code, enabled: !model.busy),
          ErrorNotice(model.failure),
          Notice(model.notice),
        ],
      ),
    );
  }
}

/// One editable field provides paste, selection, backspace and screen-reader input.
class CodeInput extends StatelessWidget {
  const CodeInput({super.key, required this.controller, required this.enabled});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 5 ? 0 : 7),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .5),
                            border: Border.all(
                              color: value.text.length == i
                                  ? brandMuted
                                  : brandBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            i < value.text.length ? value.text[i] : '',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            showCursor: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: TextStyle(color: Colors.transparent),
              fillColor: Colors.transparent,
              filled: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.model,
    required this.initialEmail,
  });
  final SessionModel model;
  final String initialEmail;
  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final email = TextEditingController(text: widget.initialEmail);
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset password'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sent)
            const Text(
              'If the account exists, a reset link has been sent. Complete the reset using the secure page in the email.',
            )
          else
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (!sent)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await widget.model.auth.forgot(email.text.trim());
                    if (mounted) setState(() => sent = true);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error = 'Could not send the request. Check the address and try again.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Sending…' : 'Send reset link'),
        ),
    ],
  );
}
