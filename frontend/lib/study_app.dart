import 'package:flutter/material.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/session_store.dart';
import 'package:studyplaner/data/sync_service.dart';
import 'package:studyplaner/screens/app_shell.dart';
import 'package:studyplaner/screens/login_screen.dart';

class StudyPlannerApp extends StatefulWidget {
  const StudyPlannerApp({
    super.key,
    required this.database,
    required this.api,
    required this.session,
    required this.sync,
    required this.notifications,
  });
  final AppDatabase database;
  final ApiClient api;
  final SessionStore session;
  final SyncService sync;
  final NotificationService notifications;

  @override
  State<StudyPlannerApp> createState() => _StudyPlannerAppState();
}

class _StudyPlannerAppState extends State<StudyPlannerApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _token;
  String? _email;
  bool _ready = false;
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await widget.session.readToken();
      if (token != null) {
        final email = await widget.session.readEmail();
        if (!mounted) return;
        _token = token;
        _email = email;
        _sessionSaved = true;
        widget.api.token = token;
      }
    } catch (_) {
      // Secure storage can be unavailable. The user can sign in again.
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _signedIn(String token, String email) async {
    var saved = false;
    try {
      await widget.session.save(token, email);
      saved = true;
    } catch (_) {
      // Keep the authenticated session in memory if secure storage fails.
    }
    if (!mounted) return;
    widget.api.token = token;
    setState(() {
      _sessionSaved = saved;
      _token = token;
      _email = email;
    });
    if (!saved) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Phiên chỉ dùng lần này. Mở lại app, bạn cần đăng nhập lại.',
          ),
        ),
      );
    }
  }

  Future<void> _continueOffline() async {
    widget.api.token = null;
    setState(() {
      _token = null;
      _email = 'Chế độ offline';
    });
  }

  Future<void> _signOut() async {
    if (_sessionSaved) await widget.session.clear();
    widget.api.token = null;
    if (mounted) {
      setState(() {
        _sessionSaved = false;
        _token = null;
        _email = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Study Planner',
    scaffoldMessengerKey: _messengerKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5274E8)),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    ),
    home: !_ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _token != null || _email == 'Chế độ offline'
        ? AppShell(
            database: widget.database,
            api: widget.api,
            sync: widget.sync,
            notifications: widget.notifications,
            email: _email ?? '',
            onSignOut: _signOut,
          )
        : LoginScreen(
            onSignedIn: _signedIn,
            onContinueOffline: _continueOffline,
            api: widget.api,
          ),
  );
}
