import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import 'package:documind/features/widgets/decorations.dart';
import '../state/home_provider.dart';
import '../state/library_provider.dart';
import 'chat/chat_screen.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';

/// Root scaffold: bottom navigation between the five top-level surfaces plus
/// a calm, intentional offline sheet (amber, never red).
class AppShell extends StatefulWidget {
  final bool offline;
  const AppShell({super.key, this.offline = false});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().refresh();
      context.read<HomeProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      LibraryScreen(),
      SearchScreen(),
      ChatScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (widget.offline)
            OfflineBanner(onDismiss: () => setState(() {})),
          Expanded(child: screens[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Offline banner: warm amber, friendly copy with checkmarks — "intentional
/// mode", not an error. Tap for the full explanation.
class OfflineBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const OfflineBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Material(
      color: c.goldSoft,
      child: InkWell(
        onTap: () => _explain(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 16, color: c.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're offline — your documents are still available.",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.plum,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Browse · Search · Read — AI answers need internet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: c.gold),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _explain(BuildContext context) {
    final c = context.docColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            IconBadge(
              icon: Icons.wifi_off_rounded,
              color: c.gold,
              background: c.goldSoft,
              size: 18,
            ),
            const SizedBox(width: 10),
            const Text("You're offline"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _check(context, 'Browse all your documents'),
            _check(context, 'Search your entire library'),
            _check(context, 'Read saved files & conversations'),
            const SizedBox(height: 10),
            Text(
              'AI responses: connect to the internet to use your configured cloud AI provider.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _check(BuildContext context, String text) {
    final c = context.docColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 17, color: c.mint),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
