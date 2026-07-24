import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';
import '../services/settings_service.dart';
import '../services/locale_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final settingsNotifier = ref.read(settingsServiceProvider.notifier);
    final authState = ref.watch(authServiceProvider);
    final consent = ref.watch(consentServiceProvider);
    final consentNotifier = ref.read(consentServiceProvider.notifier);
    final notificationPrefs = ref.watch(notificationServiceProvider);
    final notificationNotifier =
        ref.read(notificationServiceProvider.notifier);
    final links = ref.watch(remoteConfigProvider).links;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(ref.tr('settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Скорость текста
          _SectionTitle(ref.tr('text')),
          _SliderTile(
            icon: Icons.speed,
            label: ref.tr('text_speed'),
            value: settings.textSpeed,
            min: 0.0,
            max: 1.0,
            leadingLabel: ref.tr('fast'),
            trailingLabel: ref.tr('slow'),
            onChanged: (v) => settingsNotifier.setTextSpeed(v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.play_circle_outline,
            label: ref.tr('auto_play'),
            subtitle: ref.tr('auto_play_desc'),
            value: settings.autoPlay,
            onChanged: (_) => settingsNotifier.toggleAutoPlay(),
          ),
          if (settings.autoPlay) ...[
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.timer,
              label: ref.tr('auto_play_delay'),
              value: settings.autoPlayDelay.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              leadingLabel: '1с',
              trailingLabel: '8с',
              onChanged: (v) => settingsNotifier.setAutoPlayDelay(v.toInt()),
            ),
          ],
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.vibration,
            label: ref.tr('vibration'),
            subtitle: null,
            value: settings.vibrationEnabled,
            onChanged: (_) => settingsNotifier.toggleVibration(),
          ),
          const SizedBox(height: 8),
          // Стиль диалогов
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Text(ref.tr('dialogue_style'), style: const TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _DialogueStyleCard(
                      label: ref.tr('classic_style'),
                      icon: Icons.dock,
                      selected: settings.dialogueStyle == 0,
                      onTap: () => settingsNotifier.setDialogueStyle(0),
                    ),
                    const SizedBox(width: 8),
                    _DialogueStyleCard(
                      label: ref.tr('overlay_style'),
                      icon: Icons.center_focus_strong,
                      selected: settings.dialogueStyle == 1,
                      onTap: () => settingsNotifier.setDialogueStyle(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Звук
          _SectionTitle(ref.tr('sound')),
          _SwitchTile(
            icon: settings.isMuted ? Icons.volume_off : Icons.volume_up,
            label: ref.tr('sound'),
            subtitle: settings.isMuted ? ref.tr('sound_off') : ref.tr('sound_on'),
            value: !settings.isMuted,
            onChanged: (_) => settingsNotifier.toggleMute(),
          ),
          if (!settings.isMuted) ...[
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.music_note,
              label: ref.tr('music'),
              value: settings.bgMusicVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => settingsNotifier.setBgMusicVolume(v),
            ),
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.surround_sound,
              label: ref.tr('sfx'),
              value: settings.sfxVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => settingsNotifier.setSfxVolume(v),
            ),
          ],

          const SizedBox(height: 24),

          // Язык
          _SectionTitle(ref.tr('language')),
          const _LanguageTile(),

          const SizedBox(height: 24),

          // Тема
          _SectionTitle('🎨 Оформление'),
          Row(
            children: [
              _ThemeCard(
                label: '🌙 Тёмная',
                selected: settings.themeMode == 2,
                onTap: () => settingsNotifier.setThemeMode(2),
              ),
              const SizedBox(width: 8),
              _ThemeCard(
                label: '☀️ Светлая',
                selected: settings.themeMode == 1,
                onTap: () => settingsNotifier.setThemeMode(1),
              ),
              const SizedBox(width: 8),
              _ThemeCard(
                label: '📱 Системная',
                selected: settings.themeMode == 0,
                onTap: () => settingsNotifier.setThemeMode(0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Приложение
          _SectionTitle('📱 ${ref.tr("app")}'),
          _SwitchTile(
            icon: Icons.notifications_outlined,
            label: ref.tr('notifications'),
            subtitle: null,
            value: settings.notificationsEnabled,
            onChanged: (_) => settingsNotifier.toggleNotifications(),
          ),
          const SizedBox(height: 8),
          // Волна 3 (4.10): локальные напоминания (default off,
          // при включении — запрос разрешений Android 13+ / iOS)
          _SwitchTile(
            icon: Icons.bolt_outlined,
            label: 'Напоминать о билетах',
            subtitle: 'Уведомление, когда билеты восстановятся',
            value: notificationPrefs.ticketRefill,
            onChanged: (v) =>
                notificationNotifier.setTicketRefillEnabled(v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.card_giftcard_outlined,
            label: 'Напоминать о ежедневной награде',
            subtitle: 'Вечернее напоминание, если награда не забрана',
            value: notificationPrefs.dailyReward,
            onChanged: (v) =>
                notificationNotifier.setDailyRewardEnabled(v),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.tr('cache_cleared')), duration: const Duration(seconds: 2)),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services, color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('clear_cache'), style: const TextStyle(color: Colors.white)),
                      const Text('~45 MB', style: TextStyle(fontSize: 12, color: Colors.white38)),
                    ],
                  )),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.tr('purchases_restored')), duration: const Duration(seconds: 2)),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.restore, color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Text(ref.tr('restore_purchases'), style: const TextStyle(color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Волна 3 (спека 4.10): приватность — согласия и ссылки
          const _SectionTitle('🔒 Приватность'),
          _SwitchTile(
            icon: Icons.analytics_outlined,
            label: 'Анонимная аналитика',
            subtitle: 'Помогает улучшать истории и приложение',
            value: consent.analytics,
            onChanged: (v) => consentNotifier.setAnalytics(v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.ads_click_outlined,
            label: 'Персонализированная реклама',
            subtitle: 'При выключении реклама показывается без подбора',
            value: consent.adsPersonalized,
            onChanged: (v) => consentNotifier.setAdsPersonalized(v),
          ),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Политика конфиденциальности',
            url: links.privacyPolicyUrl,
          ),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.description_outlined,
            label: 'Условия использования',
            url: links.termsUrl,
          ),

          // v2.1 (спека 4.7): аккаунт — экспорт данных и удаление
          if (authState.isLoggedIn) ...[
            const SizedBox(height: 24),
            const _SectionTitle('👤 Аккаунт'),
            const _ExportDataTile(),
            const SizedBox(height: 8),
            const _DeleteAccountTile(),
          ],

          const SizedBox(height: 24),

          // О приложении
          _SectionTitle(ref.tr('about')),
          _InfoTile(
            icon: Icons.info_outline,
            label: 'Amoria',
            subtitle: ref.tr('version'),
          ),
        ],
      ),
    );
  }
}

/// v2.1 (спека 4.7): «Скачать мои данные» — GET /v1/auth/export →
/// JSON-файл в Documents + snackbar с путём.
class _ExportDataTile extends ConsumerStatefulWidget {
  const _ExportDataTile();

  @override
  ConsumerState<_ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends ConsumerState<_ExportDataTile> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    String message;
    try {
      final path = await ref.read(accountServiceProvider).exportData();
      message = 'Данные сохранены: $path';
    } on AccountServiceException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Не удалось скачать данные. Попробуйте позже';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _export,
        child: Row(
          children: [
            const Icon(Icons.download_outlined,
                color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Скачать мои данные',
                      style: TextStyle(color: Colors.white)),
                  Text('Экспорт в JSON-файл (GDPR)',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

/// v2.1 (спека 4.7): «Удалить аккаунт» — двойное подтверждение →
/// DELETE /v1/auth/account → полный локальный wipe → экран входа.
class _DeleteAccountTile extends ConsumerStatefulWidget {
  const _DeleteAccountTile();

  @override
  ConsumerState<_DeleteAccountTile> createState() =>
      _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<_DeleteAccountTile> {
  bool _busy = false;

  Future<void> _confirmAndDelete() async {
    if (_busy) return;

    // Подтверждение №1
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(ctx),
        title: const Text('Удалить аккаунт?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Аккаунт будет удалён навсегда: прогресс, покупки и валюта '
          'восстановить будет нельзя.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Подтверждение №2 (двойное, спека 4.7)
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(ctx),
        title: const Text('Точно удалить?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Это действие необратимо. Все данные аккаунта будут удалены '
          'с сервера, а локальные — очищены.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить навсегда',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => _busy = true);
    final success = await ref.read(accountServiceProvider).deleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);

    if (success) {
      // Полный wipe выполнен — на экран входа, стек очищаем
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить аккаунт. Попробуйте позже'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: _confirmAndDelete,
        child: Row(
          children: [
            const Icon(Icons.delete_forever_outlined,
                color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Удалить аккаунт',
                      style: TextStyle(color: Colors.redAccent)),
                  Text('Безвозвратно, с удалением данных',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.redAccent),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

/// Волна 3 (4.10): пункт-ссылка (privacy/terms). url_launcher в зависимостях
/// не используем — URL показывается в диалоге для копирования.
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor(ctx),
              title: Text(label, style: const TextStyle(color: Colors.white)),
              content: SelectableText(
                url.isNotEmpty ? url : 'Ссылка появится позже',
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть',
                      style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          );
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.white)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? leadingLabel;
  final String? trailingLabel;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.leadingLabel,
    this.trailingLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
          Row(
            children: [
              if (leadingLabel != null)
                Text(leadingLabel!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white38)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.16),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              if (trailingLabel != null)
                Text(trailingLabel!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white38)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white)),
              if (subtitle != null)
                Text(subtitle!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final meta = localeMetaList[locale]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(ref.tr('language'),
                style: const TextStyle(color: Colors.white)),
          ),
          // ← стрелка
          GestureDetector(
            onTap: () => ref.read(localeProvider.notifier).previous(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // Текущий язык
          SizedBox(
            width: 90,
            child: Text(
              '${meta.flag} ${meta.nativeName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // → стрелка
          GestureDetector(
            onTap: () => ref.read(localeProvider.notifier).next(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppTheme.primary : Colors.white60,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogueStyleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DialogueStyleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppTheme.primary : Colors.white38,
                  size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppTheme.primary : Colors.white60,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
