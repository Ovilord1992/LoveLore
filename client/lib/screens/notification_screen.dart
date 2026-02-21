import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../app/theme.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔔 ${ref.tr('notifications')}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(ref.tr('no_notifications'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
              const SizedBox(height: 8),
              Text(ref.tr('notifications_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}
