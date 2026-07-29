class Asset {
  final String id;
  final String systemName;
  final String materialId;
  final String? locationId;
  final String? displayName;
  final double width;
  final double height;
  final int quantity;
  final String type;
  final String status;
  final String materialName;
  final double materialThickness;
  final String locationName;
  final String? jobReference;

  Asset({
    required this.id,
    required this.systemName,
    required this.materialId,
    this.locationId,
    this.displayName,
    required this.width,
    required this.height,
    required this.quantity,
    required this.type,
    required this.status,
    required this.materialName,
    required this.materialThickness,
    required this.locationName,
    this.jobReference,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      systemName: json['system_name'],
      materialId: json['material_id'] as String? ?? '',
      locationId: json['location_id'] as String?,
      displayName: json['display_name'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      type: json['asset_type'],
      status: json['status'],
      materialName: json['materials']?['name'] ?? 'Unknown',
      materialThickness:
          (json['materials']?['thickness'] as num?)?.toDouble() ?? 0.0,
      locationName: json['locations']?['name'] ?? 'None',
      jobReference: json['job_reference'],
    );
  }
}
