import 'package:json_annotation/json_annotation.dart';

part 'device_channel.g.dart';

@JsonSerializable()
class DeviceChannel {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'channel_no')
  final int channelNo;
  final String label;
  @JsonKey(name: 'label_is_custom')
  final bool labelIsCustom;
  @JsonKey(name: 'channel_type')
  final String channelType; // 'light' or 'switch'
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const DeviceChannel({
    required this.deviceId,
    required this.channelNo,
    required this.label,
    required this.labelIsCustom,
    this.channelType = 'light',
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceChannel.fromJson(Map<String, dynamic> json) =>
      _$DeviceChannelFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceChannelToJson(this);

  DeviceChannel copyWith({
    String? deviceId,
    int? channelNo,
    String? label,
    bool? labelIsCustom,
    String? channelType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceChannel(
      deviceId: deviceId ?? this.deviceId,
      channelNo: channelNo ?? this.channelNo,
      label: label ?? this.label,
      labelIsCustom: labelIsCustom ?? this.labelIsCustom,
      channelType: channelType ?? this.channelType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this channel is configured as a light
  bool isLight() {
    return channelType == 'light';
  }

  /// Check if this channel is configured as a switch
  bool isSwitch() {
    return channelType == 'switch';
  }

  /// Get the display label for this channel
  String getDisplayLabel() {
    return labelIsCustom ? label : 'Channel $channelNo';
  }

  /// Check if this channel has a custom label
  bool hasCustomLabel() {
    return labelIsCustom && label != 'Channel $channelNo';
  }
}

/// Request model for creating/updating device channels
@JsonSerializable()
class DeviceChannelRequest {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'channel_no')
  final int channelNo;
  final String label;

  const DeviceChannelRequest({
    required this.deviceId,
    required this.channelNo,
    required this.label,
  });

  factory DeviceChannelRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceChannelRequestFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceChannelRequestToJson(this);
}

/// Enhanced device model with channel information
@JsonSerializable()
class DeviceWithChannels {
  final String id;
  @JsonKey(name: 'topic_base')
  final String topicBase;
  @JsonKey(name: 'mac_address')
  final String? macAddress;
  @JsonKey(name: 'owner_user_id')
  final String ownerUserId;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'name_is_custom')
  final bool nameIsCustom;
  final int? channels;
  @JsonKey(name: 'home_id')
  final String? homeId;
  @JsonKey(name: 'room_id')
  final String? roomId;
  @JsonKey(name: 'device_type')
  final String deviceType;
  @JsonKey(name: 'matter_type')
  final String? matterType;
  @JsonKey(name: 'meta_json')
  final Map<String, dynamic>? metaJson;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'channel_labels')
  final Map<String, dynamic>? channelLabels;

  const DeviceWithChannels({
    required this.id,
    required this.topicBase,
    this.macAddress,
    required this.ownerUserId,
    required this.displayName,
    required this.nameIsCustom,
    required this.channels,
    this.homeId,
    this.roomId,
    required this.deviceType,
    this.matterType,
    this.metaJson,
    required this.createdAt,
    required this.updatedAt,
    this.channelLabels,
  });

  factory DeviceWithChannels.fromJson(Map<String, dynamic> json) =>
      _$DeviceWithChannelsFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceWithChannelsToJson(this);

  /// Get the display name for the device
  String getDisplayName() {
    return nameIsCustom ? displayName : _getDefaultDeviceName();
  }

  /// Get the default device name based on device type
  String _getDefaultDeviceName() {
    switch (deviceType.toLowerCase()) {
      case 'relay':
        return 'Smart Relay';
      case 'dimmer':
        return 'Smart Dimmer';
      case 'shutter':
        return 'Smart Shutter';
      case 'sensor':
        return 'Smart Sensor';
      default:
        return 'Smart Device';
    }
  }

  /// Get the label for a specific channel
  /// Checks meta_json.channel_labels first (client-writable), then view's channel_labels
  String getChannelLabel(int channelNo) {
    // Check meta_json.channel_labels first (stored via device update)
    final metaLabels = metaJson?['channel_labels'] as Map<String, dynamic>?;
    if (metaLabels != null) {
      final metaData = metaLabels[channelNo.toString()];
      if (metaData is Map<String, dynamic>) {
        final label = metaData['label'] as String?;
        final isCustom = metaData['is_custom'] as bool? ?? false;
        if (isCustom && label != null && label.isNotEmpty) {
          return label;
        }
      }
    }

    // Fallback to view's channel_labels (from device_channels table)
    if (channelLabels != null) {
      final channelData = channelLabels![channelNo.toString()];
      if (channelData is Map<String, dynamic>) {
        final label = channelData['label'] as String?;
        final isCustom = channelData['is_custom'] as bool? ?? false;
        if (isCustom && label != null && label.isNotEmpty) {
          return label;
        }
      }
    }

    return 'Channel $channelNo';
  }

  /// Get the type for a specific channel ('light' or 'switch')
  String getChannelType(int channelNo) {
    if (channelLabels == null) {
      return 'light';
    }

    final channelData = channelLabels![channelNo.toString()];
    if (channelData is Map<String, dynamic>) {
      final type = channelData['type'] as String?;
      if (type != null && (type == 'light' || type == 'switch')) {
        return type;
      }
    }

    return 'light';
  }

  /// Check if a channel is configured as a light
  bool isChannelLight(int channelNo) {
    return getChannelType(channelNo) == 'light';
  }

  /// Check if a channel is configured as a switch
  bool isChannelSwitch(int channelNo) {
    return getChannelType(channelNo) == 'switch';
  }

  /// Check if a channel has a custom label
  bool hasCustomChannelLabel(int channelNo) {
    if (channelLabels == null) {
      return false;
    }

    final channelData = channelLabels![channelNo.toString()];
    if (channelData is Map<String, dynamic>) {
      return channelData['is_custom'] as bool? ?? false;
    }

    return false;
  }

  /// Get all channel labels as a map
  Map<int, String> getAllChannelLabels() {
    final result = <int, String>{};
    final effectiveChannels = channels ?? 0;

    for (int i = 1; i <= effectiveChannels; i++) {
      result[i] = getChannelLabel(i);
    }

    return result;
  }

  /// Get the effective channel count for iteration
  /// For relays/dimmers: returns channels (2/4/8)
  /// For shutters/sensors/other: returns 0 (no relay channels to iterate)
  int get effectiveChannels {
    return channels ?? 0;
  }
}
