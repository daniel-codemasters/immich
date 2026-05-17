//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StorageTemplateDeviceDto {
  /// Returns a new [StorageTemplateDeviceDto] instance.
  StorageTemplateDeviceDto({
    required this.assetCount,
    required this.deviceId,
    required this.lastUploadAt,
  });

  /// Number of assets uploaded by this device
  ///
  /// Minimum value: -9007199254740991
  /// Maximum value: 9007199254740991
  int assetCount;

  /// Technical device identifier
  String deviceId;

  /// ISO timestamp of the most recent upload from this device
  String lastUploadAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is StorageTemplateDeviceDto &&
    other.assetCount == assetCount &&
    other.deviceId == deviceId &&
    other.lastUploadAt == lastUploadAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (assetCount.hashCode) +
    (deviceId.hashCode) +
    (lastUploadAt.hashCode);

  @override
  String toString() => 'StorageTemplateDeviceDto[assetCount=$assetCount, deviceId=$deviceId, lastUploadAt=$lastUploadAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'assetCount'] = this.assetCount;
      json[r'deviceId'] = this.deviceId;
      json[r'lastUploadAt'] = this.lastUploadAt;
    return json;
  }

  /// Returns a new [StorageTemplateDeviceDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StorageTemplateDeviceDto? fromJson(dynamic value) {
    upgradeDto(value, "StorageTemplateDeviceDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return StorageTemplateDeviceDto(
        assetCount: mapValueOfType<int>(json, r'assetCount')!,
        deviceId: mapValueOfType<String>(json, r'deviceId')!,
        lastUploadAt: mapValueOfType<String>(json, r'lastUploadAt')!,
      );
    }
    return null;
  }

  static List<StorageTemplateDeviceDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <StorageTemplateDeviceDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StorageTemplateDeviceDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StorageTemplateDeviceDto> mapFromJson(dynamic json) {
    final map = <String, StorageTemplateDeviceDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StorageTemplateDeviceDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StorageTemplateDeviceDto-objects as value to a dart map
  static Map<String, List<StorageTemplateDeviceDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<StorageTemplateDeviceDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StorageTemplateDeviceDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'assetCount',
    'deviceId',
    'lastUploadAt',
  };
}

