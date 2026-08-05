import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import 'theme_toggle_button.dart';

class NavigationDestinationItem {
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const NavigationDestinationItem({
    required this.icon,
    Widget? selectedIcon,
    required this.label,
  }) : selectedIcon = selectedIcon ?? icon;
}

class ResponsiveScaffold extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      // Standard drawer for mobile
      drawer: isWide ? null : _buildDrawer(context),
      // Tune edge swipe width - 20.0 is standard and safe
      drawerEdgeDragWidth: isWide ? 0 : 20.0,
      body: Row(
        children: [
          if (isWide) ...[
            _buildSidebar(context),
            const VerticalDivider(width: 1, thickness: 1),
          ],
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: widget.title,
                // Add hamburger button for mobile
                leading: isWide
                    ? null
                    : Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          tooltip: 'Open menu',
                        ),
                      ),
                actions: [
                  ...?widget.actions,
                  const ThemeToggleButton(),
                  const SizedBox(width: 8),
                ],
              ),
              body: widget.body,
              bottomNavigationBar: isWide
                  ? null
                  : NavigationBar(
                      selectedIndex: widget.selectedIndex,
                      onDestinationSelected: widget.onDestinationSelected,
                      destinations: widget.destinations
                          .map((d) => NavigationDestination(
                                icon: d.icon,
                                selectedIcon: d.selectedIcon,
                                label: d.label,
                              ))
                          .toList(),
                    ),
              floatingActionButton: widget.floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medical_services, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CallAppoint',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Medical Reports'),
            onTap: () {
              Navigator.pop(context);
              context.push('/artifacts');
            },
          ),
          const Spacer(),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.brightness_medium_outlined),
            title: Text('Appearance'),
            trailing: ThemeToggleButton(),
          ),
          _LogoutTile(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final sidebarWidth = _isCollapsed ? 80.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medical_services, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'CallAppoint',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                IconButton(
                  icon: Icon(_isCollapsed ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.destinations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final d = widget.destinations[index];
                final isSelected = widget.selectedIndex == index;

                if (_isCollapsed) {
                  return Center(
                    child: IconButton(
                      icon: IconTheme(
                        data: IconThemeData(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        child: isSelected ? d.selectedIcon : d.icon,
                      ),
                      onPressed: () => widget.onDestinationSelected(index),
                      tooltip: d.label,
                    ),
                  );
                }

                return InkWell(
                  onTap: () => widget.onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconTheme(
                          data: IconThemeData(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          child: isSelected ? d.selectedIcon : d.icon,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          d.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_isCollapsed) ...[
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => context.push('/profile'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            _LogoutTile(),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.redAccent),
      title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('Are you sure you want to log out of your account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Log out'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await supabase.auth.signOut();
          } catch (_) {}
          if (context.mounted) context.go('/login');
        }
      },
    );
  }
}
