/// Where the FuelSense backend lives.
///
/// The default below is the LAN address of the machine running the Django
/// server. Change it, or better, override it at build time so nothing in the
/// source needs editing:
///
///   flutter run --dart-define=API_BASE=http://192.168.1.50:8000/api
///
/// `ipconfig` shows the address a phone on the same Wi-Fi can reach. The
/// Android emulator reaches the host machine at http://10.0.2.2:8000/api.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.100.219:8000/api',
  );

  /// Without a timeout a wrong address leaves the UI spinning forever.
  static const Duration requestTimeout = Duration(seconds: 15);
}
