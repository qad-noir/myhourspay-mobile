import '../hours/workspace_settings_screen.dart';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/device_name.dart';
import '../../shared/widgets.dart';
import '../auth/auth_repository.dart';
import '../auth/google_identity.dart';
import '../session/session_model.dart';
import '../../core/web_account_links.dart';
import 'account_preferences.dart';
import '../notifications/reminder_preferences.dart';

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
          title: Text('Link Google'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm your current password before choosing your Google account. If you registered socially, set a password using password recovery first.',
              ),
              SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Current password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (password.text.isEmpty) {
        setState(
          () => failure = ApiFailure(
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
          () => failure = ApiFailure(
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
        title: Text('Revoke this device?'),
        content: Text(
          '${displayDeviceName(session.name)} will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Revoke'),
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
        SnackBar(
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
          () => failure = ApiFailure(
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
        fillViewport: false,
        footer: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: mhpColor(context, brandAction)),
          ),
          onPressed: widget.model.busy ? null : widget.model.logout,
          child: Text('Sign out'),
        ),
        children: [
          SizedBox(height: 32),
          Text('Account', style: titleStyle),
          SizedBox(height: 24),
          Row(
            children: [
              InitialAvatar(user?.name ?? '', size: 64, peach: true),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -.6,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        color: mhpColor(context, brandMuted),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 26),
          const SectionLabel('ACCOUNT'),
          AccountWebAction(
            title: 'Edit name, phone, or password',
            description: 'Manage your profile on the website. You may need to sign in there.',
            url: WebAccountLinks.profile,
          ),
          const SizedBox(height: 24),
          const SectionLabel('WORKSPACE'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Workspace overtime preferences'),
            subtitle: Text(widget.model.workspace?.name ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.model.workspace == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WorkspaceSettingsScreen(model: widget.model),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('PREFERENCES'),
          const AccountPreferences(),
          const SizedBox(height: 24),
          SectionLabel('SECURITY'),
          Panel(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: mhpColor(context, brandInk),
                  size: 21,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Two-factor authentication',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                SizedBox(width: 8),
                StatusBadge(
                  user?.mfaEnabled == true ? 'Enabled' : 'Off',
                  success: user?.mfaEnabled == true,
                ),
              ],
            ),
          ),
          SizedBox(height: 28),
          if (google.configured &&
              widget.model.providers['google'] == true &&
              !widget.model.googleLinked)
            OutlinedButton.icon(
              onPressed: widget.model.busy ? null : linkGoogle,
              icon: Icon(Icons.link),
              label: Text('Link Google'),
            ),
          SectionLabel('DEVICES'),
          ErrorNotice(failure),
          if (loading && widget.model.deviceSessions == null)
            LoadingCards()
          else if (sessions.isEmpty)
            InfoPanel('No device sessions are available.')
          else
            Panel(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    if (i > 0) Divider(),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.smartphone,
                            color: mhpColor(context, brandInk),
                            size: 22,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayDeviceName(sessions[i].name),
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  sessions[i].current
                                      ? 'Current'
                                      : sessions[i].lastUsedAt == null
                                      ? 'Not used yet'
                                      : 'Last active ${sessions[i].lastUsedAt!.split('T').first}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mhpColor(context, brandMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          sessions[i].current
                              ? StatusBadge('Current', success: true)
                              : TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => revoke(sessions[i]),
                                  child: Text('Revoke'),
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
              child: Text('Try again'),
            ),
          SizedBox(height: 24),
          const ReminderPreferences(),
          InfoPanel('Your account is shared with MyHoursPay on the web.'),
          const SizedBox(height: 28),
          const SectionLabel('DELETE ACCOUNT'),
          AccountWebAction(
            title: 'Delete account',
            description: 'Open your web profile to review account deletion and its consequences before confirming.',
            url: WebAccountLinks.deletion,
            destructive: true,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
