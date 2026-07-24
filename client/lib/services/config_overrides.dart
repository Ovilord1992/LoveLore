// Сегменты и A/B-эксперименты Remote Config (спека 4.6).
//
// Чистые функции без зависимостей от Hive/Riverpod — применяются
// RemoteConfigService'ом к сырому JSON конфига ДО чтения типизированных
// геттеров. Порядок: базовый конфиг → overrides всех подошедших segments
// (по порядку массива) → overrides варианта каждого включённого эксперимента.

import 'dart:convert';

/// Контекст устройства/пользователя для условий сегментов и бакетирования.
class OverrideContext {
  final String deviceId;

  /// "android" | "ios" | прочее (desktop/web в тестах)
  final String platform;
  final bool isVip;

  /// Дата первого запуска (app_settings.first_launch_ts)
  final DateTime? firstLaunchAt;

  const OverrideContext({
    required this.deviceId,
    required this.platform,
    this.isVip = false,
    this.firstLaunchAt,
  });
}

/// Эксперимент, применённый к текущему устройству (для experiment_exposure).
class AppliedExperiment {
  final String experimentId;
  final String variant;

  const AppliedExperiment({required this.experimentId, required this.variant});
}

/// 32-битный FNV-1a от UTF-8 байтов строки.
/// Детерминирован и стабилен между сессиями/платформами (спека 4.6).
int fnv1a(String input) {
  const int prime = 0x01000193;
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash;
}

/// Выбор варианта эксперимента: `fnv1a("<deviceId>:<expId>") % totalWeight`,
/// вариант — по кумулятивным весам (веса <= 0 игнорируются).
/// Возвращает `key` варианта или null (нет валидных весов).
String? pickVariantKey({
  required String deviceId,
  required String experimentId,
  required List<Map<String, dynamic>> variants,
}) {
  var total = 0;
  for (final v in variants) {
    final w = v['weight'];
    if (w is num && w > 0) total += w.toInt();
  }
  if (total <= 0) return null;

  final bucket = fnv1a('$deviceId:$experimentId') % total;
  var cumulative = 0;
  for (final v in variants) {
    final w = v['weight'];
    final weight = (w is num && w > 0) ? w.toInt() : 0;
    if (weight <= 0) continue;
    cumulative += weight;
    if (bucket < cumulative) {
      final key = v['key'];
      return key is String && key.isNotEmpty ? key : null;
    }
  }
  return null;
}

/// Установить значение по плоскому dot-пути ("economy.premiumChoiceBaseCost").
/// Значение заменяется целиком; отсутствующие промежуточные секции создаются.
void setByDotPath(Map<String, dynamic> target, String path, dynamic value) {
  final parts = path.split('.');
  var node = target;
  for (var i = 0; i < parts.length - 1; i++) {
    final key = parts[i];
    final next = node[key];
    if (next is Map<String, dynamic>) {
      node = next;
    } else {
      final created = <String, dynamic>{};
      node[key] = created;
      node = created;
    }
  }
  node[parts.last] = value;
}

/// Проверка условий сегмента: platform, vip, installedAfter/installedBefore.
/// Неизвестные ключи условий игнорируются (forward-compatible).
bool segmentMatches(Map<String, dynamic> conditions, OverrideContext ctx) {
  final platform = conditions['platform'];
  if (platform is String && platform.isNotEmpty && platform != ctx.platform) {
    return false;
  }

  final vip = conditions['vip'];
  if (vip is bool && vip != ctx.isVip) return false;

  final after = conditions['installedAfter'];
  if (after is String && after.isNotEmpty) {
    final dt = DateTime.tryParse(after);
    final first = ctx.firstLaunchAt;
    if (dt == null || first == null || !first.isAfter(dt)) return false;
  }

  final before = conditions['installedBefore'];
  if (before is String && before.isNotEmpty) {
    final dt = DateTime.tryParse(before);
    final first = ctx.firstLaunchAt;
    if (dt == null || first == null || !first.isBefore(dt)) return false;
  }

  return true;
}

/// Применить overrides сегментов и экспериментов к сырому JSON конфига.
///
/// Исходная карта [raw] не мутируется — возвращается глубокая копия.
/// Применённые эксперименты (включая варианты с пустыми overrides —
/// контрольные группы) добавляются в [appliedExperiments].
Map<String, dynamic> applyConfigOverrides(
  Map<String, dynamic> raw, {
  required OverrideContext context,
  List<AppliedExperiment>? appliedExperiments,
}) {
  // Глубокая копия: кеш/база хранит оригинал, overrides не «прилипают».
  final result = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;

  void applyOverrides(dynamic overrides) {
    if (overrides is! Map) return;
    overrides.forEach((key, value) {
      final path = key.toString();
      if (path.isEmpty) return;
      setByDotPath(result, path, value);
    });
  }

  // 1. Сегменты — по порядку массива
  final segments = raw['segments'];
  if (segments is List) {
    for (final seg in segments) {
      if (seg is! Map) continue;
      final rawConditions = seg['conditions'];
      final conditions = rawConditions is Map
          ? rawConditions.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};
      if (!segmentMatches(conditions, context)) continue;
      applyOverrides(seg['overrides']);
    }
  }

  // 2. Эксперименты — только включённые, вариант по стабильному бакету
  final experiments = raw['experiments'];
  if (experiments is List) {
    for (final exp in experiments) {
      if (exp is! Map) continue;
      if (exp['enabled'] != true) continue;
      final id = exp['id'];
      if (id is! String || id.isEmpty) continue;
      final variantsRaw = exp['variants'];
      if (variantsRaw is! List) continue;
      final variants = variantsRaw
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      final variantKey = pickVariantKey(
        deviceId: context.deviceId,
        experimentId: id,
        variants: variants,
      );
      if (variantKey == null) continue;
      final variant = variants.firstWhere((v) => v['key'] == variantKey);
      applyOverrides(variant['overrides']);
      appliedExperiments?.add(
        AppliedExperiment(experimentId: id, variant: variantKey),
      );
    }
  }

  return result;
}
