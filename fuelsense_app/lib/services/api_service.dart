import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  //static const String _base = 'http://192.168.100.219:8000/api';
  //static const String _base = 'http://127.0.0.1:8000/api';
  static const String _base = 'http://10.18.244.54:8000/api';
  static const Duration _timeout = Duration(seconds: 20);

  // ── Token storage ─────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveAuth(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data['access'] != null) {
      await prefs.setString('token', data['access'].toString());
    }

    if (data['refresh'] != null) {
      await prefs.setString('refresh', data['refresh'].toString());
    }

    await prefs.setString('user', json.encode(data));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('token');
    await prefs.remove('refresh');
    await prefs.remove('user');
  }

  static Future<bool> isLoggedIn() async {
    return (await getToken()) != null;
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');

    if (raw == null) return null;

    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) return decoded;

    return null;
  }

  // ── Headers and response helpers ──────────────────────────────────────

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    try {
      return json.decode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  static String _errorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      final error = body['error'] ??
          body['detail'] ??
          body['message'] ??
          body['non_field_errors'];

      if (error != null) return error.toString();

      // Django may return field-specific validation errors.
      return body.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
    }

    if (body is String && body.isNotEmpty) return body;

    return 'Request failed with status $statusCode';
  }

  // ── Generic HTTP methods ──────────────────────────────────────────────

  static Future<ApiResult> _get(
    String path, {
    String? token,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_base$path'),
            headers: _headers(token: token),
          )
          .timeout(_timeout);

      final body = _decodeBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.ok(body);
      }

      return ApiResult.err(
        _errorMessage(body, response.statusCode),
        data: body,
      );
    } catch (e) {
      return ApiResult.err('Network error: $e');
    }
  }

  static Future<ApiResult> _post(
    String path,
    Map<String, dynamic> data, {
    int expectedStatus = 200,
    String? token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base$path'),
            headers: _headers(token: token),
            body: json.encode(data),
          )
          .timeout(_timeout);

      final body = _decodeBody(response.body);

      if (response.statusCode == expectedStatus) {
        return ApiResult.ok(body);
      }

      return ApiResult.err(
        _errorMessage(body, response.statusCode),
        data: body,
      );
    } catch (e) {
      return ApiResult.err('Network error: $e');
    }
  }

  static Future<ApiResult> _delete(
    String path, {
    String? token,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_base$path'),
            headers: _headers(token: token),
          )
          .timeout(_timeout);

      final body = _decodeBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.ok(body);
      }

      return ApiResult.err(
        _errorMessage(body, response.statusCode),
        data: body,
      );
    } catch (e) {
      return ApiResult.err('Network error: $e');
    }
  }

  // ── Login / profile ───────────────────────────────────────────────────
  // Django: auth/login/ accepts "identifier" (phone or email) or "phone".

  static Future<ApiResult> login(String identifier, String password) async {
    final result = await _post('/auth/login/', {
      'identifier': identifier,
      'password': password,
    });

    if (result.success && result.data is Map<String, dynamic>) {
      await saveAuth(result.data as Map<String, dynamic>);
    }

    return result;
  }

  static Future<ApiResult> getProfile() async {
    final token = await getToken();

    return _get('/auth/profile/', token: token);
  }

  // ── Signup email OTP ───────────────────────────────────────────────────
  // Django: auth/send-otp/ -> send_signup_otp, auth/verify-otp/ ->
  // verify_signup_otp. Both take an EMAIL address, not a phone number.

  static Future<ApiResult> sendSignupOtp(String email) {
    return _post('/auth/send-otp/', {
      'email': email.trim(),
    });
  }

  static Future<ApiResult> verifySignupOtp(
    String email,
    String otp,
  ) {
    return _post('/auth/verify-otp/', {
      'email': email.trim(),
      'otp': otp,
    });
  }

  // Older names, kept so existing screens still compile.
  static Future<ApiResult> sendOtp(String email) => sendSignupOtp(email);

  static Future<ApiResult> verifyOtp(String email, String otp) {
    return verifySignupOtp(email, otp);
  }

  // ── Signup ────────────────────────────────────────────────────────────

  static Future<ApiResult> signup({
    required String fullName,
    required String phone,
    required String cnic,
    required String password,
    required String email,
    required String otp,
    String role = 'driver',
    int? stationId,
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'cnic': cnic,
      'password': password,
      'email': email,
      'otp': otp,
      'role': role,
      if (stationId != null) 'station_id': stationId,
    };

    final result = await _post(
      '/auth/signup/',
      body,
      expectedStatus: 201,
    );

    if (result.success && result.data is Map<String, dynamic>) {
      await saveAuth(result.data as Map<String, dynamic>);
    }

    return result;
  }

  // ── Password reset ────────────────────────────────────────────────────

  static Future<ApiResult> requestPasswordReset(String email) {
    return _post('/auth/request-password-reset/', {
      'email': email,
    });
  }

  static Future<ApiResult> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) {
    return _post('/auth/reset-password/', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  // ── Stations ──────────────────────────────────────────────────────────

  static Future<ApiResult> getAllStations() {
    return _get('/traffic/status/');
  }

  static Future<ApiResult> getNearbyStations(
    double lat,
    double lng, {
    double radius = 10,
  }) {
    return _get(
      '/stations/nearby/?lat=$lat&lng=$lng&radius=$radius',
    );
  }

  static Future<ApiResult> getStationsList() {
    return _get('/stations/list/');
  }

  static Future<ApiResult> getStationStatus(int stationId) {
    return _get('/stations/$stationId/status/');
  }

  static Future<ApiResult> getStationHistory(int stationId) {
    return _get('/stations/$stationId/history/');
  }

  // ── Dashboard ────────────────────────────────────────────────────────

  static Future<ApiResult> getDashboard(int stationId) async {
    final token = await getToken();

    return _get(
      '/dashboard/$stationId/overview/',
      token: token,
    );
  }

  static Future<ApiResult> getTransactions(
    int stationId, {
    int days = 7,
  }) async {
    final token = await getToken();

    return _get(
      '/dashboard/$stationId/transactions/?days=$days',
      token: token,
    );
  }

  // ── Employees ────────────────────────────────────────────────────────

  static Future<ApiResult> getEmployees(int stationId) async {
    final token = await getToken();

    return _get(
      '/dashboard/$stationId/employees/',
      token: token,
    );
  }

  static Future<ApiResult> addEmployee(
    int stationId, {
    required String name,
    String phone = '',
    String role = 'Pump Attendant',
    String shift = 'MORNING',
  }) async {
    final token = await getToken();

    return _post(
      '/dashboard/$stationId/employees/',
      {
        'name': name,
        'phone': phone,
        'role': role,
        'shift': shift,
      },
      token: token,
      expectedStatus: 201,
    );
  }

  static Future<ApiResult> deleteEmployee(
    int stationId,
    int employeeId,
  ) async {
    final token = await getToken();

    return _delete(
      '/dashboard/$stationId/employees/$employeeId/',
      token: token,
    );
  }
}

// ── API result ───────────────────────────────────────────────────────────

class ApiResult {
  final bool success;
  final dynamic data;
  final String? error;

  ApiResult._({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiResult.ok(dynamic data) {
    return ApiResult._(
      success: true,
      data: data,
    );
  }

  factory ApiResult.err(
    String message, {
    dynamic data,
  }) {
    return ApiResult._(
      success: false,
      error: message,
      data: data,
    );
  }

  // Supports the signup screen's r.devOtp usage.
  dynamic get devOtp {
    if (data is Map) {
      return data['dev_otp'] ?? data['devOtp'];
    }

    return null;
  }
}