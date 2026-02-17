import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/locale_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final settingsNotifier = ref.read(settingsServiceProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Скорость текста
          _SectionTitle('Текст'),
          _SliderTile(
            icon: Icons.speed,
            label: 'Скорость текста',
            value: settings.textSpeed,
            min: 0.0,
            max: 1.0,
            leadingLabel: 'Быстро',
            trailingLabel: 'Медленно',
            onChanged: (v) => settingsNotifier.setTextSpeed(v),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.play_circle_outline,
            label: 'Автопрокрутка',
            subtitle: 'Автоматически переключать диалоги',
            value: settings.autoPlay,
            onChanged: (_) => settingsNotifier.toggleAutoPlay(),
          ),
          if (settings.autoPlay) ...[
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.timer,
              label: 'Задержка автопрокрутки',
              value: settings.autoPlayDelay.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              leadingLabel: '1с',
              trailingLabel: '8с',
              onChanged: (v) => settingsNotifier.setAutoPlayDelay(v.toInt()),
            ),
          ],

          const SizedBox(height: 24),

          // Звук
          _SectionTitle('Звук'),
          _SwitchTile(
            icon: settings.isMuted ? Icons.volume_off : Icons.volume_up,
            label: 'Звук',
            subtitle: settings.isMuted ? 'Выключен' : 'Включён',
            value: !settings.isMuted,
            onChanged: (_) => settingsNotifier.toggleMute(),
          ),
          if (!settings.isMuted) ...[
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.music_note,
              label: 'Музыка',
              value: settings.bgMusicVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => settingsNotifier.setBgMusicVolume(v),
            ),
            const SizedBox(height: 8),
            _SliderTile(
              icon: Icons.surround_sound,
              label: 'Звуковые эффекты',
              value: settings.sfxVolume,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => settingsNotifier.setSfxVolume(v),
            ),
          ],

          const SizedBox(height: 24),

          // Язык
          _SectionTitle('Язык'),
          const _LanguageTile(),

          const SizedBox(height: 24),

          // О приложении
          _SectionTitle('О приложении'),
          _InfoTile(
            icon: Icons.info_outline,
            label: 'Amoria',
            subtitle: 'Версия 1.0.0',
          ),
        ],
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
          color: Color(0xFFE91E63),
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
        color: const Color(0xFF16213E),
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
                    activeTrackColor: const Color(0xFFE91E63),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFFE91E63),
                    overlayColor: const Color(0x29E91E63),
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
        color: const Color(0xFF16213E),
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
            activeTrackColor: const Color(0xFFE91E63),
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
        color: const Color(0xFF16213E),
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
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Язык / Language',
                style: TextStyle(color: Colors.white)),
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
                color: Color(0xFFE91E63),
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
