import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/appearance.dart';
import '../../core/web_account_links.dart';
import '../../shared/widgets.dart';

class AccountWebAction extends StatelessWidget {
  const AccountWebAction({
    super.key,
    required this.title,
    required this.description,
    required this.url,
    this.destructive = false,
  });
  final String title, description, url;
  final bool destructive;
  Future<void> open(BuildContext context) async {
    final uri = WebAccountLinks.parse(url);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the website. Please try again.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = WebAccountLinks.parse(url);
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Panel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          leading: Icon(
            destructive ? Icons.delete_outline : Icons.open_in_new,
            color: color,
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              uri == null
                  ? 'Website link is currently unavailable.'
                  : '$description\n${WebAccountLinks.displayDomain(uri)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          trailing: const Icon(Icons.open_in_new, size: 19),
          onTap: uri == null ? null : () => open(context),
        ),
      ),
    );
  }
}

class AccountPreferences extends StatelessWidget {
  const AccountPreferences({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppearanceScope.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.brightness_6_outlined),
              SizedBox(width: 12),
              Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'System follows your device. This preference applies to this app.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final large =
                  MediaQuery.textScalerOf(context).scale(14) > 20 ||
                  MediaQuery.sizeOf(context).width < 356;
              Widget option(ThemeMode mode) => Semantics(
                selected: controller?.mode == mode,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: controller?.mode == mode
                        ? mhpColor(context, brandPeach)
                        : Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                  onPressed: controller == null
                      ? null
                      : () async {
                          final saved = await controller.select(mode);
                          if (!saved && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Appearance changed, but could not be saved for next time.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: Icon(switch (mode) {
                    ThemeMode.system => Icons.phone_android,
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                  }, size: 18),
                  label: Text(switch (mode) {
                    ThemeMode.system => 'System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }, style: const TextStyle(fontSize: 13)),
                ),
              );
              return large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final mode in ThemeMode.values) option(mode),
                      ],
                    )
                  : Row(
                      children: [
                        for (final mode in ThemeMode.values)
                          Expanded(child: option(mode)),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}
