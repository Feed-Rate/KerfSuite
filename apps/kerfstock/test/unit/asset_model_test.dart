import 'package:flutter_test/flutter_test.dart';
import 'package:kerfstock/domain/models/asset.dart';

void main() {
  group('Asset Model', () {
    test('Asset.fromJson correctly parses nested Supabase data', () {
      final json = {
        'id': 'uuid_123',
        'system_name': 'SHEET-0001',
        'display_name': 'Kitchen Panel',
        'width': 2440,
        'height': 1220,
        'quantity': 100,
        'asset_type': 'full_sheet',
        'status': 'available',
        'materials': {'name': 'MDF', 'thickness': 16.5},
        'locations': {'name': 'Rack A'},
        'job_reference': 'JOB-99',
      };

      final asset = Asset.fromJson(json);

      expect(asset.id, 'uuid_123');
      expect(asset.systemName, 'SHEET-0001');
      expect(asset.displayName, 'Kitchen Panel');
      expect(asset.width, 2440.0);
      expect(asset.height, 1220.0);
      expect(asset.quantity, 100);
      expect(asset.type, 'full_sheet');
      expect(asset.materialName, 'MDF');
      expect(asset.materialThickness, 16.5);
      expect(asset.locationName, 'Rack A');
      expect(asset.jobReference, 'JOB-99');
    });

    test('Asset.fromJson handles missing optional fields', () {
      final json = {
        'id': 'uuid_456',
        'system_name': 'OFFCUT-001',
        'display_name': null,
        'width': 500.5,
        'height': 300,
        'asset_type': 'offcut',
        'status': 'consumed',
        'materials': null,
        'locations': null,
        'job_reference': null,
      };

      final asset = Asset.fromJson(json);

      expect(asset.displayName, isNull);
      expect(asset.materialName, 'Unknown');
      expect(asset.locationName, 'None');
      expect(asset.jobReference, isNull);
      expect(asset.quantity, 1);
    });
  });
}
