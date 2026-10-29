import 'package:flutter/material.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/sync_service.dart';
import 'package:studyplaner/screens/focus_screen.dart';
import 'package:studyplaner/screens/mindmap_screen.dart';
import 'package:studyplaner/screens/overview_screen.dart';
import 'package:studyplaner/screens/roadmap_screen.dart';
import 'package:studyplaner/screens/schedule_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.database,
    required this.api,
    required this.sync,
    required this.notifications,
    required this.email,
    required this.onSignOut,
  });
  final AppDatabase database;
  final ApiClient api;
  final SyncService sync;
  final NotificationService notifications;
  final String email;
  final Future<void> Function() onSignOut;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  bool _syncing = false;
  final _titles = const [
    'Tổng quan',
    'Lịch học',
    'Lộ trình',
    'Mindmap',
    'Tập trung',
  ];
  final _icons = const [
    Icons.grid_view_rounded,
    Icons.calendar_month_rounded,
    Icons.account_tree_rounded,
    Icons.hub_rounded,
    Icons.timer_outlined,
  ];
  Future<void> _sync() async {
    if (widget.api.token == null) {
      _message('Đăng nhập để đồng bộ dữ liệu với thiết bị khác.');
      return;
    }
    setState(() => _syncing = true);
    try {
      await widget.sync.sync();
      _message('Đồng bộ hoàn tất.');
    } catch (error) {
      _message('Chưa đồng bộ được: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _page() => IndexedStack(
    index: _selected,
    children: [
      OverviewScreen(
        database: widget.database,
        onOpenSchedule: () => setState(() => _selected = 1),
      ),
      ScheduleScreen(
        database: widget.database,
        notifications: widget.notifications,
      ),
      RoadmapScreen(database: widget.database),
      MindmapScreen(database: widget.database),
      FocusScreen(notifications: widget.notifications),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final nav = NavigationRail(
      selectedIndex: _selected,
      onDestinationSelected: (index) => setState(() => _selected = index),
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      destinations: List.generate(
        _titles.length,
        (index) => NavigationRailDestination(
          icon: Icon(_icons[index]),
          selectedIcon: Icon(_icons[index]),
          label: Text(_titles[index]),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selected],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ dữ liệu',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: widget.email,
            onSelected: (value) async {
              if (value == 'signout') await widget.onSignOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(widget.email, overflow: TextOverflow.ellipsis),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Đăng xuất')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CircleAvatar(child: Icon(Icons.person_outline)),
            ),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                nav,
                const VerticalDivider(width: 1),
                Expanded(child: _page()),
              ],
            )
          : _page(),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: (index) =>
                  setState(() => _selected = index),
              destinations: List.generate(
                _titles.length,
                (index) => NavigationDestination(
                  icon: Icon(_icons[index]),
                  label: _titles[index],
                ),
              ),
            ),
    );
  }
}
