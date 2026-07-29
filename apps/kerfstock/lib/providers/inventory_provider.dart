import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../domain/models/asset.dart';
import '../repositories/stock_repository.dart';

class InventoryProvider with ChangeNotifier {
  final StockRepository _repository;

  List<Asset> _assets = [];
  bool _isLoading = false;
  String? _error;
  String? _workspaceId;

  int _refreshGeneration = 0;

  InventoryProvider(this._repository);

  List<Asset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get workspaceId => _workspaceId;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch assets and workspaceId in parallel
      final results = await Future.wait([
        _repository.fetchAssets(),
        if (_workspaceId == null)
          _repository.getWorkspaceId()
        else
          Future.value(_workspaceId),
      ]);

      if (generation != _refreshGeneration) return;

      _assets = results[0] as List<Asset>;
      _workspaceId = results[1] as String;

      _error = null;
    } catch (e) {
      if (generation != _refreshGeneration) return;
      _error = userFacingApiError(e);
    } finally {
      if (generation == _refreshGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchMaterials() {
    return _repository.fetchMaterials();
  }

  Future<List<Map<String, dynamic>>> fetchLocations() {
    return _repository.fetchLocations();
  }

  Future<void> addAsset({
    required String materialId,
    required double width,
    required double height,
    required String type,
    String? displayName,
    String? locationId,
    String? jobReference,
    int quantity = 1,
  }) async {
    try {
      final newAssets = await _repository.createAssets(
        materialId: materialId,
        width: width,
        height: height,
        type: type,
        displayName: displayName,
        locationId: locationId,
        jobReference: jobReference,
        quantity: quantity,
      );
      _assets.insertAll(0, newAssets);
      notifyListeners();
    } catch (e) {
      _error = userFacingApiError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> editAsset({
    required Asset asset,
    required String materialId,
    required double width,
    required double height,
    required String status,
    String? displayName,
    String? locationId,
    String? jobReference,
  }) async {
    try {
      final updated = await _repository.updateAsset(
        asset: asset,
        materialId: materialId,
        width: width,
        height: height,
        status: status,
        displayName: displayName,
        locationId: locationId,
        jobReference: jobReference,
      );
      final index = _assets.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _assets[index] = updated;
      notifyListeners();
    } catch (e) {
      _error = userFacingApiError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<String> fetchCurrentRole() => _repository.getCurrentRole();
  Future<List<String>> fetchCurrentPermissions() =>
      _repository.getCurrentPermissions();

  Future<Map<String, dynamic>> addMaterial({
    required String name,
    required double thickness,
    String unit = 'mm',
  }) {
    return _repository.createMaterial(
      name: name,
      thickness: thickness,
      unit: unit,
    );
  }

  Future<Map<String, dynamic>> addLocation({
    required String name,
    String? parentId,
    String? jobReference,
  }) {
    return _repository.createLocation(
      name: name,
      parentId: parentId,
      jobReference: jobReference,
    );
  }

  Future<void> removeLocation(String locationId) =>
      _repository.archiveLocation(locationId);
}
