import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _base = 'http://192.168.100.219:8000/api';
  // ── Token storage ────────────────────────────────────────────────────────
  static Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString('token');

  static Future<void> saveAuth(Map data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', data['access']);
    await p.setString('refresh', data['refresh']);
    await p.setString('user', json.encode(data));
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token'); await p.remove('refresh'); await p.remove('user');
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  static Future<Map<String,dynamic>?> getSavedUser() async {
    final raw = (await SharedPreferences.getInstance()).getString('user');
    return raw != null ? json.decode(raw) : null;
  }

  // ── Internal helpers ─────────────────────────────────────────────────────
  static Map<String,String> _h({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // ── Auth ─────────────────────────────────────────────────────────────────
  static Future<ApiResult> sendOtp(String phone) => _post('/auth/send-otp/', {'phone': phone});
  static Future<ApiResult> verifyOtp(String phone, String otp) => _post('/auth/verify-otp/', {'phone': phone, 'otp': otp});
  static Future<ApiResult> requestPasswordReset(String email) => _post('/auth/request-password-reset/', {'email': email});
  static Future<ApiResult> resetPassword(String email, String otp, String newPassword) =>
      _post('/auth/reset-password/', {'email': email, 'otp': otp, 'new_password': newPassword});

  static Future<ApiResult> signup({
    required String fullName,
    required String phone,
    required String cnic,
    required String password,
    String? email,
    String role = 'driver',
    int? stationId,
  }) async {
    final body = {
      'full_name': fullName, 'phone': phone, 'cnic': cnic, 'password': password, 'role': role,
      if (email != null) 'email': email,
      if (stationId != null) 'station_id': stationId,
    };
    final r = await _post('/auth/signup/', body, expectedStatus: 201);
    if (r.success) await saveAuth(r.data);
    return r;
  }

  static Future<ApiResult> login(String phone, String password) async {
    final r = await _post('/auth/login/', {'phone': phone, 'password': password});
    if (r.success) await saveAuth(r.data);
    return r;
  }

  // ── Stations ─────────────────────────────────────────────────────────────
  static Future<ApiResult> getAllStations() => _get('/traffic/status/');

  static Future<ApiResult> getNearbyStations(double lat, double lng, {double radius = 10}) =>
      _get('/stations/nearby/?lat=$lat&lng=$lng&radius=$radius');

  static Future<ApiResult> getStationsList() => _get('/stations/list/');

  // ── Dashboard ────────────────────────────────────────────────────────────
  static Future<ApiResult> getDashboard(int stationId) async {
    final token = await getToken();
    return _get('/dashboard/$stationId/overview/', token: token);
  }

  // ── Employees ────────────────────────────────────────────────────────────
  static Future<ApiResult> getEmployees(int stationId) async {
    final token = await getToken();
    return _get('/dashboard/$stationId/employees/', token: token);
  }

  static Future<ApiResult> addEmployee(int stationId, {
    required String name, String phone = '', String role = 'Pump Attendant', String shift = 'MORNING',
  }) async {
    final token = await getToken();
    return _post('/dashboard/$stationId/employees/', {
      'name': name, 'phone': phone, 'role': role, 'shift': shift,
    }, token: token, expectedStatus: 201);
  }

  static Future<ApiResult> deleteEmployee(int stationId, int employeeId) async {
    final token = await getToken();
    return _delete('/dashboard/$stationId/employees/$employeeId/', token: token);
  }

  // ── Private ──────────────────────────────────────────────────────────────
  static Future<ApiResult> _get(String path, {String? token}) async {
    try {
      final res = await http.get(Uri.parse('$_base$path'), headers: _h(token: token));
      final body = json.decode(res.body);
      return res.statusCode < 300 ? ApiResult.ok(body) : ApiResult.err(body['error'] ?? 'Error ${res.statusCode}');
    } catch (e) { return ApiResult.err('Network error: $e'); }
  }

  static Future<ApiResult> _post(String path, Map data, {int expectedStatus = 200, String? token}) async {
    try {
      final res = await http.post(Uri.parse('$_base$path'), headers: _h(token: token), body: json.encode(data));
      final body = json.decode(res.body);
      return res.statusCode == expectedStatus ? ApiResult.ok(body) : ApiResult.err(body['error'] ?? 'Error ${res.statusCode}');
    } catch (e) { return ApiResult.err('Network error: $e'); }
  }

  static Future<ApiResult> _delete(String path, {String? token}) async {
    try {
      final res = await http.delete(Uri.parse('$_base$path'), headers: _h(token: token));
      final body = json.decode(res.body);
      return res.statusCode < 300 ? ApiResult.ok(body) : ApiResult.err(body['error'] ?? 'Error ${res.statusCode}');
    } catch (e) { return ApiResult.err('Network error: $e'); }
  }
}

class ApiResult {
  final bool success;
  final dynamic data;
  final String? error;
  ApiResult._({required this.success, this.data, this.error});
  factory ApiResult.ok(dynamic data) => ApiResult._(success: true, data: data);
  factory ApiResult.err(String msg) => ApiResult._(success: false, error: msg);
}