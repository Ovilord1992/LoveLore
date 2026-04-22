/// Конфигурация API сервера
class ApiConfig {
  // Дефолт `10.0.2.2` — IP хост-машины с эмулятора Android.
  // Для физических устройств / iOS-симулятора задавать через
  // `flutter run --dart-define=API_BASE_URL=http://<IP>:3000/v1`.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/v1',
  );
}
