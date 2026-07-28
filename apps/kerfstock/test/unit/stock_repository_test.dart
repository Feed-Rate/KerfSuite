import 'package:flutter_test/flutter_test.dart';
import 'package:kerfstock/data/api_service.dart';
import 'package:kerfstock/repositories/stock_repository.dart';
import 'package:kerfstock/services/license_service.dart';

void main() {
  group('create asset payload', () {
    test('contains all required API fields', () {
      final payload = buildCreateAssetPayload(
        materialId: 'material-1',
        width: 2440,
        height: 1220,
        type: 'full_sheet',
      );

      expect(payload, {
        'material_id': 'material-1',
        'width': 2440.0,
        'height': 1220.0,
        'asset_type': 'full_sheet',
      });
    });

    test('omits absent optional fields instead of sending null', () {
      final payload = buildCreateAssetPayload(
        materialId: 'material-1',
        width: 500,
        height: 300,
        type: 'offcut',
      );

      expect(payload.containsKey('display_name'), isFalse);
      expect(payload.containsKey('location_id'), isFalse);
      expect(payload.containsKey('job_reference'), isFalse);
    });

    test('includes supplied optional fields', () {
      final payload = buildCreateAssetPayload(
        materialId: 'material-1',
        width: 500,
        height: 300,
        type: 'offcut',
        displayName: 'Useful offcut',
        locationId: 'rack-a',
        jobReference: 'JOB-42',
      );

      expect(payload['display_name'], 'Useful offcut');
      expect(payload['location_id'], 'rack-a');
      expect(payload['job_reference'], 'JOB-42');
    });
  });

  group('API configuration and errors', () {
    test('normalizes a valid Portal base URL', () {
      expect(
        normalizeApiBaseUrl('  https://portal.example.test///  '),
        'https://portal.example.test',
      );
    });

    test('rejects a non-HTTP Portal base URL', () {
      expect(
        () => normalizeApiBaseUrl('portal.example.test'),
        throwsArgumentError,
      );
    });

    test('release API URL overrides the bundled development URL', () {
      expect(
        resolvePortalApiBaseUrl(
          environmentValue: 'http://localhost:3000',
          compileTimeValue: 'https://kerfsuite.vercel.app/',
        ),
        'https://kerfsuite.vercel.app',
      );
    });

    test('development falls back to the bundled URL', () {
      expect(
        resolvePortalApiBaseUrl(
          environmentValue: 'http://localhost:3000',
          compileTimeValue: '',
        ),
        'http://localhost:3000',
      );
    });

    test('only exposes intentional API errors to the UI', () {
      expect(
        userFacingApiError(
          const ApiRequestException(
            'Loading inventory failed',
            statusCode: 503,
          ),
        ),
        'Loading inventory failed (HTTP 503)',
      );
      expect(
        userFacingApiError(Exception('database connection details')),
        'Unexpected communication error',
      );
    });
  });
  group('license request data', () {
    test('normalizes and formats Portal license identifiers', () {
      expect(normalizeLicenseKey('  kst-pro-abcd-1234  '), 'KST-PRO-ABCD-1234');
      expect(formatMachineId('aabbccddeeff0011'), 'AABB-CCDD-EEFF-0011');
    });

    test('always identifies activation requests as KerfStock', () {
      final payload = buildLicenseVerificationPayload(
        key: 'kst-pro-abcd-1234',
        machineId: 'AABBCCDDEEFF0011',
        osInfo: 'Windows 11',
      );

      expect(payload['cdkey'], 'KST-PRO-ABCD-1234');
      expect(payload['machine_id'], 'AABBCCDDEEFF0011');
      expect(payload['app'], 'kerfstock');
      expect(payload['app_version'], kerfStockAppVersion);
      expect(payload['os_info'], 'Windows 11');
    });
  });
}
