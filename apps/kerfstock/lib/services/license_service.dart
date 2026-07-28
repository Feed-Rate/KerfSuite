import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const kerfStockAppVersion = '1.0.1';

class LicenseGateResult {
  final bool licensed;
  final bool offline;
  final String? message;

  const LicenseGateResult({
    required this.licensed,
    this.offline = false,
    this.message,
  });
}

class LicenseRequestException implements Exception {
  final String message;
  final bool rejected;

  const LicenseRequestException(this.message, {this.rejected = false});

  @override
  String toString() => message;
}

String normalizeLicenseKey(String value) => value.trim().toUpperCase();

String formatMachineId(String value) {
  final compact = value.replaceAll('-', '').toUpperCase();
  final groups = <String>[];
  for (var index = 0; index < compact.length; index += 4) {
    final end = index + 4 < compact.length ? index + 4 : compact.length;
    groups.add(compact.substring(index, end));
  }
  return groups.join('-');
}

Map<String, dynamic> buildLicenseVerificationPayload({
  required String key,
  required String machineId,
  String appVersion = kerfStockAppVersion,
  String? osInfo,
}) {
  return {
    'cdkey': normalizeLicenseKey(key),
    'machine_id': machineId,
    'app': 'kerfstock',
    'app_version': appVersion,
    if (osInfo != null && osInfo.isNotEmpty) 'os_info': osInfo,
  };
}

class MachineIdentity {
  static Future<String> current() async {
    var source = '${Platform.operatingSystem}|${Platform.localHostname}';

    if (Platform.isWindows) {
      try {
        final result = await Process.run('reg.exe', [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ]).timeout(const Duration(seconds: 5));
        final match = RegExp(
          r'MachineGuid\s+REG_SZ\s+([^\r\n]+)',
          caseSensitive: false,
        ).firstMatch(result.stdout.toString());
        final machineGuid = match?.group(1)?.trim();
        if (result.exitCode == 0 &&
            machineGuid != null &&
            machineGuid.isNotEmpty) {
          source = 'windows|$machineGuid';
        }
      } catch (_) {
        // The stable hostname fallback above keeps activation usable when the
        // registry probe is unavailable.
      }
    }

    return sha256
        .convert(utf8.encode('KERFSTOCK|$source'))
        .toString()
        .substring(0, 16)
        .toUpperCase();
  }
}

class LicenseService {
  static const _licenseKeyStorage = 'kerfstock_license_key';
  static const _machineIdStorage = 'kerfstock_license_machine_id';
  static const _leaseExpiryStorage = 'kerfstock_license_lease_expiry';

  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<String>? _machineIdFuture;

  LicenseService({
    required this.baseUrl,
    http.Client? client,
    FlutterSecureStorage? storage,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();

  Future<String> get machineId =>
      _machineIdFuture ??= MachineIdentity.current();

  Future<String> get machineIdDisplay async => formatMachineId(await machineId);

  Future<LicenseGateResult> checkStoredLicense() async {
    final key = await _storage.read(key: _licenseKeyStorage);
    if (key == null || key.isEmpty) {
      return const LicenseGateResult(licensed: false);
    }

    try {
      return await activate(key);
    } on LicenseRequestException catch (error) {
      if (error.rejected) {
        await clearStoredLicense();
        return LicenseGateResult(licensed: false, message: error.message);
      }

      if (await _hasValidOfflineLease()) {
        return const LicenseGateResult(
          licensed: true,
          offline: true,
          message: 'Using the current offline license lease',
        );
      }

      return LicenseGateResult(licensed: false, message: error.message);
    }
  }

  Future<LicenseGateResult> activate(String rawKey) async {
    final key = normalizeLicenseKey(rawKey);
    if (key.isEmpty) {
      throw const LicenseRequestException(
        'Enter the KerfStock license key from your Portal.',
        rejected: true,
      );
    }

    final currentMachineId = await machineId;
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/licenses/verify'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(
              buildLicenseVerificationPayload(
                key: key,
                machineId: currentMachineId,
                osInfo: Platform.operatingSystemVersion,
              ),
            ),
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const LicenseRequestException('The licensing service timed out.');
    } on SocketException {
      throw const LicenseRequestException('The licensing service is offline.');
    } on http.ClientException {
      throw const LicenseRequestException(
        'The licensing service is unavailable.',
      );
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // A non-JSON server response is handled by the generic status message.
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final lease = body['lease'];
      final expiresAt = lease is Map<String, dynamic>
          ? DateTime.tryParse(lease['expires_at']?.toString() ?? '')
          : null;
      if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const LicenseRequestException(
          'The Portal returned an invalid license lease.',
        );
      }

      await _storage.write(key: _licenseKeyStorage, value: key);
      await _storage.write(key: _machineIdStorage, value: currentMachineId);
      await _storage.write(
        key: _leaseExpiryStorage,
        value: expiresAt.toUtc().toIso8601String(),
      );
      return const LicenseGateResult(licensed: true);
    }

    final message = body['error']?.toString();
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw LicenseRequestException(
        message?.isNotEmpty == true
            ? message!
            : 'Invalid KerfStock license key.',
        rejected: true,
      );
    }

    throw LicenseRequestException(
      message?.isNotEmpty == true
          ? message!
          : 'License verification failed (HTTP ${response.statusCode}).',
    );
  }

  Future<Map<String, String>> requestHeaders() async {
    final key = await _storage.read(key: _licenseKeyStorage);
    if (key == null || key.isEmpty) {
      throw const LicenseRequestException(
        'KerfStock must be activated before accessing inventory.',
        rejected: true,
      );
    }

    return {
      'x-license-key': key,
      'x-machine-id': await machineId,
      'x-app-version': kerfStockAppVersion,
      'x-os-info': Platform.operatingSystemVersion,
    };
  }

  Future<bool> _hasValidOfflineLease() async {
    final storedMachineId = await _storage.read(key: _machineIdStorage);
    final expiryValue = await _storage.read(key: _leaseExpiryStorage);
    final expiry = DateTime.tryParse(expiryValue ?? '');
    return storedMachineId == await machineId &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }

  Future<void> clearStoredLicense() async {
    await Future.wait([
      _storage.delete(key: _licenseKeyStorage),
      _storage.delete(key: _machineIdStorage),
      _storage.delete(key: _leaseExpiryStorage),
    ]);
  }
}
