class Asset {
  final String id;
  final String systemName;
  final String? displayName;
  final double width;
  final double height;
  final String type;
  final String status;
  final String materialName;
  final double materialThickness;
  final String locationName;
  final String? jobReference;

  Asset({
    required this.id,
    required this.systemName,
    this.displayName,
    required this.width,
    required this.height,
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
      displayName: json['display_name'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
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
