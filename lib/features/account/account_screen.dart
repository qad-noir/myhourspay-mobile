import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/device_name.dart';
import '../../shared/widgets.dart';
import '../auth/auth_repository.dart';
import '../auth/google_identity.dart';
import '../session/session_model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final google = NativeGoogleIdentity(
    serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    iosClientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  );
  Future<void> linkGoogle() async {
    final password = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Link Google'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm your current password before choosing your Google account. If you registered socially, set a password using password recovery first.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (password.text.isEmpty) {
        setState(
          () => failure = const ApiFailure(
            'invalid_credentials',
            'Enter your current password.',
          ),
        );
        return;
      }
      final success = await widget.model.linkGoogle(
        google.acquireCredential,
        password.text,
      );
      if (mounted) {
        setState(() => failure = success ? null : widget.model.failure);
      }
    } finally {
      password.dispose();
    }
  }

  List<DeviceSession> sessions = [];
  @override
  void dispose() {
    widget.model.cancelGoogleAttempt();
    super.dispose();
  }

  bool loading = true;
  ApiFailure? failure;
  @override
  void initState() {
    super.initState();
    sessions = widget.model.deviceSessions ?? [];
    loading = widget.model.deviceSessions == null;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await widget.model.auth.sessions();
      if (mounted) {
        widget.model.deviceSessions = result;
        setState(() => sessions = result);
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = const ApiFailure(
            'invalid_response',
            'Could not load device sessions.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> revoke(DeviceSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke this device?'),
        content: Text(
          '${displayDeviceName(session.name)} will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      await widget.model.auth.revoke(session.id);
      if (!mounted) return;
      setState(() => sessions.removeWhere((item) => item.id == session.id));
      widget.model.deviceSessions = List.of(sessions);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device revoked.'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = const ApiFailure(
            'device_error',
            'Could not revoke this device. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.model.account;
    return Scaffold(
      body: PageBody(
        footer: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: brandAction),
          ),
          onPressed: widget.model.busy ? null : widget.model.logout,
          child: const Text('Sign out'),
        ),
        children: [
          const SizedBox(height: 32),
          const Text('Account', style: titleStyle),
          const SizedBox(height: 24),
          Row(
            children: [
              InitialAvatar(user?.name ?? '', size: 64, peach: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: brandMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 26),
          const SectionLabel('SECURITY'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: brandInk, size: 21),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Two-factor authentication',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  user?.mfaEnabled == true ? 'Enabled' : 'Off',
                  success: user?.mfaEnabled == true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (google.configured &&
              widget.model.providers['google'] == true &&
              !widget.model.googleLinked)
            OutlinedButton.icon(
              onPressed: widget.model.busy ? null : linkGoogle,
              icon: const Icon(Icons.link),
              label: const Text('Link Google'),
            ),
          const SectionLabel('DEVICES'),
          ErrorNotice(failure),
          if (loading && widget.model.deviceSessions == null)
            const LoadingCards()
          else if (sessions.isEmpty)
            const InfoPanel('No device sessions are available.')
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.smartphone,
                            color: brandInk,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayDeviceName(sessions[i].name),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  sessions[i].current
                                      ? 'Current'
                                      : sessions[i].lastUsedAt == null
                                      ? 'Not used yet'
                                      : 'Last active ${sessions[i].lastUsedAt!.split('T').first}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: brandMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          sessions[i].current
                              ? const StatusBadge('Current', success: true)
                              : TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => revoke(sessions[i]),
                                  child: const Text('Revoke'),
                                ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (failure != null)
            TextButton(
              onPressed: loading ? null : load,
              child: const Text('Try again'),
            ),
          const SizedBox(height: 24),
          const InfoPanel('Your account is shared with MyHoursPay on the web.'),
        ],
      ),
    );
  }
}
