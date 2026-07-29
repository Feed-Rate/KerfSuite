import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiRequestException implements Exception {
  final String message;
  final int? statusCode;

  const ApiRequestException(this.message, {this.statusCode});

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return '$message$status';
  }
}

String userFacingApiError(Object error) {
  if (error is ApiRequestException) return error.toString();
  return 'Unexpected communication error';
}

String normalizeApiBaseUrl(String value) {
  final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Must be an absolute HTTP URL');
  }
  return normalized;
}

String resolvePortalApiBaseUrl({
  required String environmentValue,
  String compileTimeValue = const String.fromEnvironment('KERFPORTAL_API_URL'),
}) {
  final selected = compileTimeValue.trim().isNotEmpty
      ? compileTimeValue
      : environmentValue;
  return normalizeApiBaseUrl(selected);
}

typedef RequestHeaderProvider = Future<Map<String, String>> Function();

class ApiService {
  static const _requestTimeout = Duration(seconds: 15);

  final String baseUrl;
  final SupabaseClient _supabase = Supabase.instance.client;
  final RequestHeaderProvider? licenseHeaders;

  ApiService({required String baseUrl, this.licenseHeaders})
    : baseUrl = normalizeApiBaseUrl(baseUrl);

  Future<Map<String, String>> _getHeaders() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const ApiRequestException('Authentication session is unavailable');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
    final licenseHeaderProvider = licenseHeaders;
    if (licenseHeaderProvider != null) {
      headers.addAll(await licenseHeaderProvider());
    }
    return headers;
  }

  Future<http.Response> _awaitResponse(
    Future<http.Response> request,
    String operation,
  ) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiRequestException('$operation timed out');
    }
  }

  Future<String> getWorkspaceId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = await _supabase
        .from('users')
        .select('workspace_id')
        .eq('id', user.id)
        .single();

    return data['workspace_id'] as String;
  }

  Future<List<Map<String, dynamic>>> getAssets() async {
    final response = await _awaitResponse(
      http.get(
        Uri.parse('$baseUrl/api/stock/assets'),
        headers: await _getHeaders(),
      ),
      'Loading inventory',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }

    throw ApiRequestException(
      'Loading inventory failed',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> createAssets(
    Map<String, dynamic> data,
  ) async {
    final response = await _awaitResponse(
      http.post(
        Uri.parse('$baseUrl/api/stock/assets'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ),
      'Creating asset',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [Map<String, dynamic>.from(decoded as Map)];
    }

    throw ApiRequestException(
      'Creating asset failed',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> updateAsset(
    String assetId,
    Map<String, dynamic> data,
  ) async {
    final response = await _awaitResponse(
      http.patch(
        Uri.parse('$baseUrl/api/stock/assets/$assetId'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ),
      'Updating asset',
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw ApiRequestException(
      'Updating asset failed',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> archiveAsset(String assetId) async {
    final response = await _awaitResponse(
      http.delete(
        Uri.parse('$baseUrl/api/stock/assets/$assetId'),
        headers: await _getHeaders(),
      ),
      'Removing asset',
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw ApiRequestException(
      'Removing asset failed',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> getMaterials() async {
    final response = await _awaitResponse(
      http.get(
        Uri.parse('$baseUrl/api/stock/materials'),
        headers: await _getHeaders(),
      ),
      'Loading materials',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }

    throw ApiRequestException(
      'Loading materials failed',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await _awaitResponse(
      http.get(
        Uri.parse('$baseUrl/api/stock/locations'),
        headers: await _getHeaders(),
      ),
      'Loading locations',
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }

    throw ApiRequestException(
      'Loading locations failed',
      statusCode: response.statusCode,
    );
  }

  Future<String> getCurrentRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ApiRequestException('Authentication session is unavailable');
    }
    final data = await _supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .single();
    return data['role'] as String;
  }

  Future<List<String>> getCurrentPermissions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const ApiRequestException('Authentication session is unavailable');
    }
    final data = await _supabase
        .from('users')
        .select('permissions')
        .eq('id', user.id)
        .single();
    return List<String>.from(data['permissions'] ?? const <String>[]);
  }

  Future<Map<String, dynamic>> createMaterial({
    required String name,
    required double thickness,
    String unit = 'mm',
  }) async {
    final response = await _awaitResponse(
      http.post(
        Uri.parse('$baseUrl/api/stock/materials'),
        headers: await _getHeaders(),
        body: json.encode({'name': name, 'thickness': thickness, 'unit': unit}),
      ),
      'Creating material',
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw ApiRequestException(
      response.statusCode == 403
          ? 'You do not have permission to manage materials'
          : 'Creating material failed',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> data) async {
    final response = await _awaitResponse(
      http.post(
        Uri.parse('$baseUrl/api/stock/locations'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ),
      'Creating location',
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw ApiRequestException(
      response.statusCode == 403
          ? 'You do not have permission to manage locations'
          : 'Creating location failed',
      statusCode: response.statusCode,
    );
  }

  Future<void> archiveLocation(String locationId) async {
    final response = await _awaitResponse(
      http.delete(
        Uri.parse('$baseUrl/api/stock/locations/$locationId'),
        headers: await _getHeaders(),
      ),
      'Removing location',
    );
    if (response.statusCode == 200) return;

    String message = 'Removing location failed';
    if (response.statusCode == 403) {
      message = 'You do not have permission to manage locations';
    } else if (response.statusCode == 409) {
      try {
        message = json.decode(response.body)['error'] as String? ?? message;
      } catch (_) {
        // Keep the safe fallback message.
      }
    }
    throw ApiRequestException(message, statusCode: response.statusCode);
  }
}
