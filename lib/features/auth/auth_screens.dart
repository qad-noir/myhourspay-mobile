import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../session/session_model.dart';

String get deviceName => Platform.isAndroid
    ? 'MHP Android'
    : Platform.isIOS
    ? 'MHP iPhone'
    : 'MHP ${Platform.operatingSystem}';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.model});
  final SessionModel model;
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
          children: [
            const SizedBox(height: 36),
            Center(
              child: Image.asset(
                'assets/brand/brand-mark.png',
                width: 64,
                height: 64,
                semanticLabel: 'MyHoursPay',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MyHoursPay',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
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
            ErrorNotice(model.failure), Notice(model.notice),
            if (model.phase == SessionPhase.expired)
              const Notice('Your session expired. Sign in again.'),
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
            const SizedBox(height: 20),
            TextButton(
              onPressed: model.busy
                  ? null
                  : () => setState(() {
                      register = !register;
                      password.clear();
                      confirmation.clear();
                    }),
              child: Text(
                register
                    ? 'Already have an account? Sign in'
                    : 'Create an account',
              ),
            ),
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
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.verified_user_outlined,
            size: 64,
            color: Color(0xffac3810),
          ),
          const SizedBox(height: 28),
          Text(
            widget.emailVerification ? 'Verify your email' : 'One more step',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            widget.emailVerification
                ? 'Enter the 6-digit code sent to ${model.account?.email ?? 'your email'}.'
                : recovery
                ? 'Enter one of your unused recovery codes.'
                : 'Enter the 6-digit code from your authenticator app.',
          ),
          const SizedBox(height: 28),
          TextField(
            controller: code,
            enabled: !model.busy,
            keyboardType: recovery ? TextInputType.text : TextInputType.number,
            autofillHints: recovery ? null : const [AutofillHints.oneTimeCode],
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: recovery ? 'Recovery code' : 'Verification code',
            ),
          ),
          ErrorNotice(model.failure),
          Notice(model.notice),
          const SizedBox(height: 20),
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
          if (widget.emailVerification)
            TextButton(
              onPressed: model.busy ? null : model.resend,
              child: const Text('Resend code'),
            )
          else
            TextButton(
              onPressed: model.busy
                  ? null
                  : () => setState(() {
                      recovery = !recovery;
                      code.clear();
                    }),
              child: Text(
                recovery ? 'Use an authenticator code' : 'Use a recovery code',
              ),
            ),
        ],
      ),
    );
  }
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
