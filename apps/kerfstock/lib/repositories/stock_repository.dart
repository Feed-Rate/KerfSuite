import '../data/api_service.dart';
import '../domain/models/asset.dart';

Map<String, dynamic> buildCreateAssetPayload({
  required String materialId,
  required double width,
  required double height,
  required String type,
  String? displayName,
  String? locationId,
  String? jobReference,
}) {
  final payload = <String, dynamic>{
    'material_id': materialId,
    'width': width,
    'height': height,
    'asset_type': type,
  };

  if (displayName != null) payload['display_name'] = displayName;
  if (locationId != null) payload['location_id'] = locationId;
  if (jobReference != null) payload['job_reference'] = jobReference;

  return payload;
}

class StockRepository {
  final ApiService _apiService;

  StockRepository(this._apiService);

  Future<String> getWorkspaceId() async {
    // We can still use Supabase directly for session info or go via API
    return await _apiService.getWorkspaceId();
  }

  Future<List<Asset>> fetchAssets() async {
    final rawAssets = await _apiService.getAssets();
    return rawAssets.map((json) => Asset.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMaterials() {
    return _apiService.getMaterials();
  }

  Future<List<Map<String, dynamic>>> fetchLocations() {
    return _apiService.getLocations();
  }

  Future<Asset> createAsset({
    required String materialId,
    required double width,
    required double height,
    required String type,
    String? displayName,
    String? locationId,
    String? jobReference,
  }) async {
    final data = buildCreateAssetPayload(
      materialId: materialId,
      width: width,
      height: height,
      type: type,
      displayName: displayName,
      locationId: locationId,
      jobReference: jobReference,
    );

    final rawAsset = await _apiService.createAsset(data);
    return Asset.fromJson(rawAsset);
  }

  Future<String> getCurrentRole() => _apiService.getCurrentRole();
  Future<List<String>> getCurrentPermissions() =>
      _apiService.getCurrentPermissions();

  Future<Map<String, dynamic>> createMaterial({
    required String name,
    required double thickness,
    String unit = 'mm',
  }) {
    return _apiService.createMaterial(
      name: name,
      thickness: thickness,
      unit: unit,
    );
  }

  Future<Map<String, dynamic>> createLocation({
    required String name,
    String? parentId,
    String? jobReference,
  }) {
    return _apiService.createLocation({
      'name': name,
      'parent_id': ?parentId,
      'job_reference': ?jobReference,
    });
  }

  Future<void> archiveLocation(String locationId) =>
      _apiService.archiveLocation(locationId);
}
