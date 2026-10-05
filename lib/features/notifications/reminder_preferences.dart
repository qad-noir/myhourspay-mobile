import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import 'push_controller.dart';

class ReminderPreferences extends StatelessWidget {
  const ReminderPreferences({super.key});
  @override
  Widget build(BuildContext context) {
    final push = PushScope.of(context);
    if (push == null || !push.supported) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('REMINDERS'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Missing hours'),
                subtitle: Text(
                  push.configured
                      ? 'A weekday reminder when you haven’t recorded hours. Available on every plan.'
                      : 'Notifications will be available after setup is complete.',
                ),
                value: push.enabled,
                onChanged: push.configured && !push.busy
                    ? (value) => push.setEnabled(value)
                    : null,
              ),
              if (push.busy) const LinearProgressIndicator(),
              if (push.error != null) ...[
                Text(
                  push.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: push.busy ? null : () => push.setEnabled(true),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
