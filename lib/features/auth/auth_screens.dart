import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../../core/api_client.dart';
import '../session/session_model.dart';
import '../../core/device_name.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.model,
    this.providerActions = const {},
    this.signupProviderActions = const {},
    this.deviceLabelLoader = resolveDeviceName,
  });
  final SessionModel model;
  // Only configured integrations supply actions; fixtures inject isolated callbacks.
  final Map<String, VoidCallback> providerActions;
  final Map<String, SignupProviderAction> signupProviderActions;
  final Future<String> Function() deviceLabelLoader;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool signup = false, hidden = true, preparing = false;
  @override
  void dispose() {
    widget.model.cancelGoogleAttempt();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (preparing || widget.model.busy || !form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => preparing = true);
    final label = await widget.deviceLabelLoader();
    if (!mounted) return;
    await widget.model.login(email.text.trim(), password.text, label);
    if (!mounted) return;
    password.clear();
    setState(() => preparing = false);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    if (signup) {
      return SignupScreen(
        model: model,
        providerActions: widget.signupProviderActions,
        deviceLabelLoader: widget.deviceLabelLoader,
        onSignIn: () => setState(() {
          model.failure = null;
          signup = false;
        }),
      );
    }
    return Scaffold(
      body: Form(
        key: form,
        child: PageBody(
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Don’t have an account?',
                style: TextStyle(
                  color: mhpColor(context, brandMuted),
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: model.busy || preparing
                    ? null
                    : () => setState(() {
                        password.clear();
                        model.failure = null;
                        signup = true;
                      }),
                child: Text('Create account'),
              ),
            ],
          ),
          children: [
            SizedBox(height: 24),
            Center(
              child: Image.asset(
                'assets/brand/brand-mark.png',
                width: 56,
                height: 56,
                semanticLabel: 'MyHoursPay',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'MyHoursPay',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 30),
            Text(
              'Your time. In order.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 8),
            Text('Welcome back.', textAlign: TextAlign.center),
            SizedBox(height: 28),
            TextFormField(
              controller: email,
              enabled: !model.busy,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              autofillHints: [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
                errorText: model.failure?.fields['email']?.firstOrNull,
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? 'Enter your email address.'
                  : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: password,
              enabled: !model.busy,
              obscureText: hidden,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
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
            if (model.phase != SessionPhase.expired) ErrorNotice(model.failure),
            Notice(
              model.phase == SessionPhase.expired
                  ? 'Your session has expired. Please sign in again.'
                  : model.notice,
            ),
            SizedBox(height: 12),
            FilledButton(
              onPressed: model.busy || preparing ? null : submit,
              child: Text(model.busy || preparing ? 'Signing in…' : 'Sign in'),
            ),
            TextButton(
              onPressed: model.busy || preparing
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => ForgotPasswordDialog(
                        model: model,
                        initialEmail: email.text,
                      ),
                    ),
              child: Text('Forgot password?'),
            ),
            if (widget.providerActions.keys.any(
              (p) => model.providers[p] == true,
            )) ...[
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        fontSize: 13,
                        color: mhpColor(context, brandMuted),
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 20),
              for (final provider in ['google', 'apple'])
                if (model.providers[provider] == true &&
                    widget.providerActions.containsKey(provider))
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: mhpColor(context, Colors.white),
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
                        style: TextStyle(color: mhpColor(context, brandInk)),
                      ),
                    ),
                  ),
            ],
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
          icon: Icon(Icons.arrow_back),
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
                      if (!mounted) return;
                      code.clear();
                    },
              child: Text(
                model.busy
                    ? 'Verifying…'
                    : widget.emailVerification
                    ? 'Verify email'
                    : 'Verify and continue',
              ),
            ),
            SizedBox(height: 8),
            widget.emailVerification
                ? TextButton(
                    onPressed: model.busy ? null : model.resend,
                    child: Text('Resend code'),
                  )
                : toggle,
          ],
        ),
        children: [
          SizedBox(height: 56),
          Icon(
            widget.emailVerification
                ? Icons.mark_email_read_outlined
                : Icons.verified_user_outlined,
            size: 76,
            color: brandOrange,
          ),
          SizedBox(height: 30),
          Text(
            widget.emailVerification ? 'Verify your email' : 'One more step',
            style: titleStyle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            widget.emailVerification
                ? 'Enter the 6-digit code sent to ${model.account?.email ?? 'your email'}.'
                : recovery
                ? 'Enter one of your unused recovery codes.'
                : 'Enter the 6-digit code from your authenticator app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mhpColor(context, brandMuted),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 44),
          if (recovery)
            TextField(
              controller: code,
              enabled: !model.busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: 'Recovery code'),
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
                                  ? mhpColor(context, brandMuted)
                                  : mhpColor(context, brandBorder),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            i < value.text.length ? value.text[i] : '',
                            style: TextStyle(fontSize: 24),
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
            autofillHints: [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            showCursor: false,
            enableSuggestions: false,
            decoration: InputDecoration(
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
  final form = GlobalKey<FormState>();
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
    title: Text('Reset password'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sent)
              Text(
                'If the account exists, a reset link has been sent. Complete the reset using the secure page in the email.',
              )
            else
              TextFormField(
                controller: email,
                enabled: !busy,
                autofillHints: [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email address'),
                validator: (value) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
            if (busy) ...[
              SizedBox(height: 16),
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text('Requesting a reset link…'),
            ],
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(sent ? 'Done' : 'Close'),
      ),
      if (!sent)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.model.auth.forgot(email.text.trim());
                    if (mounted && context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => sent = true);
                      Navigator.pop(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'If the account exists, a reset link has been sent. Check your email.',
                          ),
                          duration: Duration(seconds: 6),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } on ApiFailure catch (failure) {
                    if (mounted) {
                      setState(
                        () => error = failure.code == 'timeout'
                            ? 'The reset request was not confirmed. Check your email before requesting another link.'
                            : friendlyFailure(failure),
                      );
                    }
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
