import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

enum DeviceType {
  relay,
  dimmer,
  shutter,
  sensor,
  other;

  String toJson() => name;
  static DeviceType fromJson(String json) => DeviceType.values.byName(json);
}

@JsonSerializable()
class Device {
  final String id;
  @JsonKey(name: 'home_id')
  final String? homeId;
  @JsonKey(name: 'room_id')
  final String? roomId;
  // Support both old 'name' and new 'display_name' fields
  @JsonKey(name: 'name', includeIfNull: false)
  final String? name;
  @JsonKey(name: 'display_name', includeIfNull: false)
  final String? displayName;
  @JsonKey(name: 'name_is_custom', includeIfNull: false)
  final bool? nameIsCustom;
  @JsonKey(name: 'device_type')
  final DeviceType deviceType;
  final int? channels;
  @JsonKey(name: 'channel_count', includeIfNull: false)
  final int? channelCount;
  @JsonKey(name: 'online', includeIfNull: false)
  final bool? online;
  @JsonKey(name: 'last_seen_at', includeIfNull: false)
  final DateTime? lastSeenAt;
  // Support both old 'tasmota_topic_base' and new 'topic_base' fields
  @JsonKey(name: 'tasmota_topic_base', includeIfNull: false)
  final String? tasmotaTopicBase;
  @JsonKey(name: 'topic_base', includeIfNull: false)
  final String? topicBase;
  @JsonKey(name: 'mac_address', includeIfNull: false)
  final String? macAddress;
  @JsonKey(name: 'owner_user_id', includeIfNull: false)
  final String? ownerUserId;
  @JsonKey(name: 'matter_type')
  final String? matterType;
  @JsonKey(name: 'meta_json')
  final Map<String, dynamic>? metaJson;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Device({
    required this.id,
    this.homeId,
    this.roomId,
    this.name,
    this.displayName,
    this.nameIsCustom,
    required this.deviceType,
    required this.channels,
    this.channelCount,
    this.online,
    this.lastSeenAt,
    this.tasmotaTopicBase,
    this.topicBase,
    this.macAddress,
    this.ownerUserId,
    this.matterType,
    this.metaJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  /// Get the display name for the device (backward compatible)
  String get deviceName {
    // Prefer displayName if available and custom, otherwise use name, otherwise default
    if (nameIsCustom == true &&
        displayName != null &&
        displayName!.isNotEmpty) {
      return displayName!;
    }
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    return _getDefaultDeviceName();
  }

  /// Get the topic base (backward compatible)
  String? get deviceTopicBase {
    return topicBase ?? tasmotaTopicBase;
  }

  /// Get the default device name based on device type
  String _getDefaultDeviceName() {
    switch (deviceType) {
      case DeviceType.relay:
        return 'Smart Relay';
      case DeviceType.dimmer:
        return 'Smart Dimmer';
      case DeviceType.shutter:
        return 'Smart Shutter';
      case DeviceType.sensor:
        return 'Smart Sensor';
      case DeviceType.other:
        return 'Smart Device';
    }
  }

  /// Check if the device has a custom name
  bool get hasCustomName {
    return nameIsCustom == true;
  }

  /// Get the effective channel count for iteration
  /// For relays/dimmers: returns channels (2/4/8)
  /// For shutters/sensors/other: returns 0 (no relay channels to iterate)
  int get effectiveChannels {
    return channels ?? 0;
  }

  /// Get the logical channel count
  /// For relays/dimmers: returns channels (2/4/8)
  /// For shutters: returns 1 (one logical shutter)
  /// For sensors/other: returns channelCount or 1
  int get logicalChannelCount {
    return channelCount ?? channels ?? 1;
  }

  Device copyWith({
    String? id,
    String? homeId,
    String? roomId,
    String? name,
    String? displayName,
    bool? nameIsCustom,
    DeviceType? deviceType,
    int? channels,
    int? channelCount,
    bool? online,
    DateTime? lastSeenAt,
    String? tasmotaTopicBase,
    String? topicBase,
    String? macAddress,
    String? ownerUserId,
    String? matterType,
    Map<String, dynamic>? metaJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      nameIsCustom: nameIsCustom ?? this.nameIsCustom,
      deviceType: deviceType ?? this.deviceType,
      channels: channels ?? this.channels,
      channelCount: channelCount ?? this.channelCount,
      online: online ?? this.online,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      tasmotaTopicBase: tasmotaTopicBase ?? this.tasmotaTopicBase,
      topicBase: topicBase ?? this.topicBase,
      macAddress: macAddress ?? this.macAddress,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      matterType: matterType ?? this.matterType,
      metaJson: metaJson ?? this.metaJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
