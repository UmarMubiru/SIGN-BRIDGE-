import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';

class AppNavigation extends ConsumerWidget {
  const AppNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    if (isDesktop) {
      return _DesktopNavigation();
    } else {
      return _MobileNavigation();
    }
  }
}

class _DesktopNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.secondarySurface,
      child: Column(
        children: [
          // Use the full brand mark on its own so it reads clearly in the sidebar.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SizedBox(
              width: 210,
              height: 105,
              child: Image.asset(
                'assets/images/signbridge_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.accessibility_new,
                  size: 88,
                  color: AppTheme.teal,
                ),
              ),
            ),
          ),
          const Divider(color: AppTheme.primaryBackground),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                ),
                _NavItem(
                  icon: Icons.videocam,
                  label: 'New recording',
                  route: '/sessions/create',
                ),
                _NavItem(
                  icon: Icons.people,
                  label: 'Signers',
                  route: '/signers',
                ),
                _NavItem(
                  icon: Icons.library_books,
                  label: 'Sign Library',
                  route: '/signs',
                ),
                _NavItem(
                  icon: Icons.history,
                  label: 'Records',
                  route: '/records',
                ),
                _NavItem(
                  icon: Icons.assessment,
                  label: 'Coverage',
                  route: '/coverage',
                ),
                _NavItem(
                  icon: Icons.folder,
                  label: 'Sessions',
                  route: '/sessions',
                ),
                _NavItem(
                  icon: Icons.cloud_download,
                  label: 'Export',
                  route: '/datasets',
                ),
                const Divider(color: AppTheme.primaryBackground),
                _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  route: '/settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.secondarySurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Logo
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.gold, AppTheme.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/signbridge_logo.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to placeholder if image not found
                    return const Icon(
                      Icons.accessibility_new,
                      size: 48,
                      color: AppTheme.primaryBackground,
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'SignBridge',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBackground,
                  ),
                ),
                const Text(
                  'Different Hands • Same Voice',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryBackground,
                  ),
                ),
              ],
            ),
          ),
          // Navigation items
          _NavItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/dashboard',
          ),
          _NavItem(
            icon: Icons.videocam,
            label: 'New recording',
            route: '/sessions/create',
          ),
          _NavItem(icon: Icons.people, label: 'Signers', route: '/signers'),
          _NavItem(
            icon: Icons.library_books,
            label: 'Sign Library',
            route: '/signs',
          ),
          _NavItem(icon: Icons.history, label: 'Records', route: '/records'),
          _NavItem(
            icon: Icons.assessment,
            label: 'Coverage',
            route: '/coverage',
          ),
          _NavItem(icon: Icons.folder, label: 'Sessions', route: '/sessions'),
          _NavItem(
            icon: Icons.cloud_download,
            label: 'Export',
            route: '/datasets',
          ),
          const Divider(color: AppTheme.primaryBackground),
          _NavItem(icon: Icons.settings, label: 'Settings', route: '/settings'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isActive = location == route || location.startsWith('$route/');

    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.gold : AppTheme.ivory),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? AppTheme.gold : AppTheme.ivory,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        // Closing the drawer removes this ListTile's element. Capture the
        // router first so navigation does not query inherited widgets through
        // a deactivated BuildContext.
        final router = GoRouter.of(context);
        Scaffold.maybeOf(context)?.closeDrawer();
        // Moving between primary sections should replace the current route,
        // rather than stacking another copy of a section in the back stack.
        router.go(route);
      },
      selected: isActive,
      selectedTileColor: AppTheme.primaryBackground.withValues(alpha: 0.1),
    );
  }
}
