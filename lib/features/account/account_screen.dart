import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import '../auth/auth_repository.dart';
import '../session/session_model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<DeviceSession> sessions = [];
  bool loading = true;
  ApiFailure? failure;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await widget.model.auth.sessions();
      if (mounted) setState(() => sessions = result);
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
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: PageBody(
      children: [
        Text(
          widget.model.account?.name ?? '',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(widget.model.account?.email ?? ''),
        const SizedBox(height: 28),
        const Text('SECURITY'),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Two-factor authentication'),
          subtitle: Text(
            widget.model.account?.mfaEnabled == true
                ? 'Enabled · managed on the website'
                : 'Not enabled · managed on the website',
          ),
        ),
        const Divider(),
        const SizedBox(height: 16),
        const Text('DEVICES'),
        ErrorNotice(failure),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          for (final session in sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone),
              title: Text(session.name),
              subtitle: Text(
                session.current
                    ? 'Current device'
                    : session.expiresAt == null
                    ? 'Expiry not provided'
                    : 'Expires ${session.expiresAt!.split('T').first}',
              ),
              trailing: session.current
                  ? null
                  : TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Revoke this device?'),
                            content: const Text(
                              'That device will need to sign in again.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Revoke'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        setState(() => loading = true);
                        try {
                          await widget.model.auth.revoke(session.id);
                          await load();
                        } on ApiFailure catch (e) {
                          if (mounted) {
                            setState(() {
                              failure = e;
                              loading = false;
                            });
                          }
                        }
                      },
                      child: const Text('Revoke'),
                    ),
            ),
        TextButton(
          onPressed: loading ? null : load,
          child: const Text('Reload devices'),
        ),
        const SizedBox(height: 20),
        const Text('Your account is shared with MyHoursPay on the web.'),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: widget.model.busy
              ? null
              : () async {
                  await widget.model.logout();
                },
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
}
