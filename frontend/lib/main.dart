import 'package:flutter/material.dart';
import 'package:studyplaner/data/api_client.dart';
import 'package:studyplaner/data/app_database.dart';
import 'package:studyplaner/data/notification_service.dart';
import 'package:studyplaner/data/session_store.dart';
import 'package:studyplaner/data/sync_service.dart';
import 'package:studyplaner/study_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final api = ApiClient();
  final session = SessionStore();
  final notifications = NotificationService();
  try {
    await notifications.initialize();
  } catch (_) {
    // Web browsers and locked-down desktop environments may deny notifications.
  }
  runApp(
    StudyPlannerApp(
      database: database,
      api: api,
      session: session,
      sync: SyncService(database, api, notifications),
      notifications: notifications,
    ),
  );
}
