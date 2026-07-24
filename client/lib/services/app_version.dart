// Версионирование формата новелл и приложения (спека 4.1).

import '../models/novel.dart';

/// Максимальная версия формата новелл, которую понимает этот клиент.
/// Новелла с `formatVersion` больше этого значения не запускается —
/// пользователю предлагается обновить приложение.
const int supportedFormatVersion = 2;

/// Версия приложения (semver, без build-номера).
///
/// package_info_plus в проект НЕ добавлен (по спеке 4.1 новый плагин не
/// вводим) — константа синхронизируется вручную с полем `version:` в
/// pubspec.yaml (сейчас `1.0.0+1`). При смене версии в pubspec обновите
/// и эту константу.
const String appVersion = '1.0.0';

/// Сравнение semver-строк по числовым компонентам ("1.2.3").
/// Отсутствующие компоненты считаются нулём, нечисловые — нулём.
/// Возвращает отрицательное число если a меньше b, 0 если равны,
/// положительное если a больше b.
int compareSemver(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final na = i < pa.length ? int.tryParse(pa[i].trim()) ?? 0 : 0;
    final nb = i < pb.length ? int.tryParse(pb[i].trim()) ?? 0 : 0;
    if (na != nb) return na - nb;
  }
  return 0;
}

/// Совместима ли новелла с этим клиентом (спека 4.1):
/// - `formatVersion` (при отсутствии — 1) не выше [supportedFormatVersion];
/// - `minAppVersion` (если задана) не выше [appVersion].
bool isNovelFormatSupported(NovelMeta meta) {
  if (meta.formatVersion > supportedFormatVersion) return false;
  final minApp = meta.minAppVersion;
  if (minApp != null &&
      minApp.trim().isNotEmpty &&
      compareSemver(appVersion, minApp) < 0) {
    return false;
  }
  return true;
}

/// Удобный геттер для UI (каталог/детали/движок).
extension NovelMetaFormatCompat on NovelMeta {
  bool get isFormatSupported => isNovelFormatSupported(this);
}
