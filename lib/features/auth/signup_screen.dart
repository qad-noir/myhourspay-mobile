import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device_name.dart';
import '../../shared/widgets.dart';
import '../session/session_model.dart';

/// Configured provider adapters receive the explicit new-account consent/name.
/// Only configured platform integrations supply these callbacks.
typedef SignupProviderAction = Future<void> Function(
  String name,
  bool terms,
  bool marketingConsent,
);

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.model,
    required this.onSignIn,
    this.providerActions = const {},
    this.deviceLabelLoader = resolveDeviceName,
  });
  final SessionModel model;
  final VoidCallback onSignIn;
  final Map<String, SignupProviderAction> providerActions;
  final Future<String> Function() deviceLabelLoader;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool hidden = true,
      confirmationHidden = true,
      terms = false,
      marketing = true,
      submitting = false,
      showTermsError = false;
  String? socialNameError;
  bool socialValidation = false;
  final clearedErrors = <String>{};
  SessionModel get model => widget.model;
  bool get pending => submitting || model.busy;
  String? serverError(String key) => clearedErrors.contains(key)
      ? null
      : model.failure?.fields[key]?.firstOrNull;
  void changed(String key) => setState(() => clearedErrors.add(key));
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.runes.length < 8 ||
        !RegExp(r'\p{Ll}', unicode: true).hasMatch(text) ||
        !RegExp(r'\p{Lu}', unicode: true).hasMatch(text) ||
        !RegExp('[0-9]').hasMatch(text)) {
      return 'Use at least 8 characters, upper- and lowercase letters, and a number.';
    }
    return serverError('password');
  }

  Future<void> openLegal(String path) async {
    final url = model.auth.api.environment.base.replace(
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
              'Could not open this page. Please read it on the MyHoursPay website.',
            ),
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (pending) return;
    socialValidation = false;
    final valid = form.currentState!.validate();
    setState(() => showTermsError = !terms);
    if (!valid || !terms) return;
    FocusScope.of(context).unfocus();
    setState(() {
      submitting = true;
      clearedErrors.clear();
    });
    try {
      final label = await widget.deviceLabelLoader();
      if (!mounted) return;
      await model.register({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'password_confirmation': confirmation.text,
        'device_name': label,
        'terms': true,
        'marketing_consent': marketing,
      });
      if (mounted) form.currentState?.validate();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> social(String provider) async {
    if (pending) return;
    setState(() {
      socialValidation = true;
      model.failure = null;
      clearedErrors.clear();
      showTermsError = !terms;
      socialNameError = name.text.trim().isEmpty
          ? 'Enter your full name.'
          : null;
    });
    form.currentState!.validate();
    if (!terms || socialNameError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    try {
      await widget.providerActions[provider]!(
        name.text.trim(),
        terms,
        marketing,
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Widget field({
    required String keyName,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool secret = false,
    bool confirm = false,
  }) {
    final masked = confirm ? confirmationHidden : hidden;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('signup-$keyName'),
        controller: controller,
        enabled: !pending,
        obscureText: secret && masked,
        autocorrect: false,
        enableSuggestions: !secret,
        maxLength: secret ? 4096 : 255,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        keyboardType: keyName == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        textCapitalization: keyName == 'name'
            ? TextCapitalization.words
            : TextCapitalization.none,
        textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
        autofillHints: [
          keyName == 'name'
              ? AutofillHints.name
              : keyName == 'email'
              ? AutofillHints.email
              : AutofillHints.newPassword,
        ],
        decoration: InputDecoration(
          hintText: label,
          errorMaxLines: 3,
          errorText: keyName == 'name' ? socialNameError : null,
          prefixIcon: Icon(icon),
          suffixIcon: secret
              ? IconButton(
                  tooltip: masked ? 'Show $label' : 'Hide $label',
                  onPressed: pending
                      ? null
                      : () => setState(() {
                          if (confirm) {
                            confirmationHidden = !confirmationHidden;
                          } else {
                            hidden = !hidden;
                          }
                        }),
                  icon: Icon(
                    masked
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
        validator: (value) =>
            socialValidation && keyName != 'name' ? null : validator(value),
        onChanged: (_) {
          if (keyName == 'name') socialNameError = null;
          changed(keyName);
        },
        onFieldSubmitted: confirm ? (_) => submit() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledProviders = ['google', 'apple']
        .where(
          (p) =>
              model.providers[p] == true &&
              widget.providerActions.containsKey(p),
        )
        .toList();
    return PopScope(
      canPop: !pending,
      child: Scaffold(
        body: AutofillGroup(
          child: Form(
            key: form,
            child: PageBody(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              footer: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(fontSize: 14, color: brandMuted),
                  ),
                  TextButton(
                    onPressed: pending ? null : widget.onSignIn,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              children: [
                Stack(
                  children: [
                    Column(
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/brand/brand-mark.png',
                            width: 52,
                            height: 52,
                            semanticLabel: 'MyHoursPay',
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'MyHoursPay',
                          textAlign: TextAlign.center,
                          style: titleStyle,
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: 'Return to sign in',
                        onPressed: pending ? null : widget.onSignIn,
                        icon: const Icon(Icons.arrow_back, color: brandInk),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text(
                  'Create your account',
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep your working week in order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: brandMuted, fontSize: 15),
                ),
                const SizedBox(height: 25),
                field(
                  keyName: 'name',
                  controller: name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your full name.'
                      : serverError('name'),
                ),
                field(
                  keyName: 'email',
                  controller: email,
                  label: 'Email address',
                  icon: Icons.mail_outline,
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? 'Enter a valid email address.'
                      : serverError('email'),
                ),
                field(
                  keyName: 'password',
                  controller: password,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  secret: true,
                  validator: validatePassword,
                ),
                field(
                  keyName: 'password_confirmation',
                  controller: confirmation,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  secret: true,
                  confirm: true,
                  validator: (v) => v != password.text
                      ? 'Passwords must match.'
                      : serverError('password_confirmation'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 48,
                      child: Checkbox(
                        semanticLabel:
                            'Agree to Terms of Service and Privacy Policy',
                        value: terms,
                        onChanged: pending
                            ? null
                            : (v) => setState(() {
                                terms = v!;
                                showTermsError = !terms;
                                clearedErrors.add('terms');
                              }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: brandInk,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: Semantics(
                                  link: true,
                                  child: InkWell(
                                    onTap: () => openLegal('/terms'),
                                    child: const Text(
                                      'Terms of Service',
                                      style: TextStyle(
                                        color: brandAction,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: Semantics(
                                  link: true,
                                  child: InkWell(
                                    onTap: () => openLegal('/policy'),
                                    child: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: brandAction,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showTermsError || serverError('terms') != null)
                  Text(
                    serverError('terms') ??
                        'Please agree to the terms and privacy policy.',
                    style: const TextStyle(
                      color: Color(0xffb3261e),
                      fontSize: 12,
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Send me offers and product news (optional)',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: marketing,
                  onChanged: pending
                      ? null
                      : (v) => setState(() => marketing = v!),
                ),
                if (serverError('marketing_consent') != null)
                  Text(
                    serverError('marketing_consent')!,
                    style: const TextStyle(color: Color(0xffb3261e)),
                  ),
                ErrorNotice(model.failure),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: pending ? null : submit,
                  child: Text(pending ? 'Creating account…' : 'Create account'),
                ),
                if (enabledProviders.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: TextStyle(color: brandMuted, fontSize: 13),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (enabledProviders.contains('google'))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Google sign-up needs your name and terms acceptance. Google supplies your email; no password is needed.\n\nPromotional consent above applies to email/password registration only. Google registration does not save that preference.',
                        style: TextStyle(color: brandMuted, fontSize: 12),
                      ),
                    ),
                  for (final provider in enabledProviders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: pending ? null : () => social(provider),
                        icon: Image.asset(
                          'assets/providers/$provider.png',
                          width: provider == 'apple' ? 34 : 22,
                          height: provider == 'apple' ? 40 : 22,
                        ),
                        label: Text(
                          'Continue with ${provider == 'google' ? 'Google' : 'Apple'}',
                          style: const TextStyle(color: brandInk),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
