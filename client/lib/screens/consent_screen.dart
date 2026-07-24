import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../services/consent_service.dart';
import '../services/remote_config_service.dart';
import '../services/settings_service.dart';
import 'library_screen.dart';
import 'onboarding_screen.dart';

/// Экран согласий при первом запуске (спека 4.10) — показывается ДО
/// онбординга: подтверждение 16+, тумблеры аналитики и персонализированной
/// рекламы, ссылки на политику конфиденциальности и условия из конфига.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _ageConfirmed = false;
  bool _analytics = true;
  bool _adsPersonalized = true;

  void _continue() {
    if (!_ageConfirmed) return;
    ref.read(consentServiceProvider.notifier).acceptConsents(
          analytics: _analytics,
          adsPersonalized: _adsPersonalized,
        );
    final hasSeenOnboarding =
        ref.read(settingsServiceProvider).hasSeenOnboarding;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasSeenOnboarding
            ? const LibraryScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  /// url_launcher в зависимостях не используем — показываем URL в диалоге
  void _showLinkDialog(String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(ctx),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SelectableText(
          url.isNotEmpty ? url : 'Ссылка появится позже',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Закрыть', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(remoteConfigProvider).links;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ).createShader(bounds),
                child: const Text(
                  'Amoria',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Перед началом',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пара важных вопросов о возрасте и данных',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    // Возраст 16+
                    _ConsentCard(
                      child: CheckboxListTile(
                        value: _ageConfirmed,
                        onChanged: (v) =>
                            setState(() => _ageConfirmed = v ?? false),
                        activeColor: AppTheme.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Мне исполнилось 16 лет',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Истории Amoria предназначены для читателей 16+',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Аналитика
                    _ConsentCard(
                      child: SwitchListTile(
                        value: _analytics,
                        onChanged: (v) => setState(() => _analytics = v),
                        activeTrackColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Анонимная аналитика',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Помогает нам улучшать истории и приложение',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Персонализированная реклама
                    _ConsentCard(
                      child: SwitchListTile(
                        value: _adsPersonalized,
                        onChanged: (v) =>
                            setState(() => _adsPersonalized = v),
                        activeTrackColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Персонализированная реклама',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'При выключении реклама останется, но без подбора '
                          'под интересы',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Ссылки privacy/terms
                    Wrap(
                      spacing: 16,
                      children: [
                        TextButton(
                          onPressed: () => _showLinkDialog(
                              'Политика конфиденциальности',
                              links.privacyPolicyUrl),
                          child: const Text(
                            'Политика конфиденциальности',
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showLinkDialog(
                              'Условия использования', links.termsUrl),
                          child: const Text(
                            'Условия использования',
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Кнопка «Продолжить»
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Opacity(
                    opacity: _ageConfirmed ? 1.0 : 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _ageConfirmed ? _continue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Продолжить',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final Widget child;
  const _ConsentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}
