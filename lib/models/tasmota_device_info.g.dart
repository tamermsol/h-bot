// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasmota_device_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TasmotaDeviceInfo _$TasmotaDeviceInfoFromJson(Map<String, dynamic> json) =>
    TasmotaDeviceInfo(
      ip: json['ip'] as String,
      mac: json['mac'] as String,
      hostname: json['hostname'] as String,
      module: json['module'] as String,
      version: json['version'] as String,
      channels: (json['channels'] as num).toInt(),
      sensors: (json['sensors'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      topicBase: json['topicBase'] as String,
      fullTopic: json['fullTopic'] as String,
      status: json['status'] as Map<String, dynamic>,
      isShutter: json['isShutter'] as bool? ?? false,
    );

Map<String, dynamic> _$TasmotaDeviceInfoToJson(TasmotaDeviceInfo instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'mac': instance.mac,
      'hostname': instance.hostname,
      'module': instance.module,
      'version': instance.version,
      'channels': instance.channels,
      'sensors': instance.sensors,
      'topicBase': instance.topicBase,
      'fullTopic': instance.fullTopic,
      'status': instance.status,
      'isShutter': instance.isShutter,
    };

WiFiProvisioningRequest _$WiFiProvisioningRequestFromJson(
  Map<String, dynamic> json,
) => WiFiProvisioningRequest(
  ssid: json['ssid'] as String,
  password: json['password'] as String,
  hostname: json['hostname'] as String?,
);

Map<String, dynamic> _$WiFiProvisioningRequestToJson(
  WiFiProvisioningRequest instance,
) => <String, dynamic>{
  'ssid': instance.ssid,
  'password': instance.password,
  'hostname': instance.hostname,
};

WiFiProvisioningResponse _$WiFiProvisioningResponseFromJson(
  Map<String, dynamic> json,
) => WiFiProvisioningResponse(
  success: json['success'] as bool,
  message: json['message'] as String,
  deviceIp: json['deviceIp'] as String?,
);

Map<String, dynamic> _$WiFiProvisioningResponseToJson(
  WiFiProvisioningResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'deviceIp': instance.deviceIp,
};

DeviceDiscoveryResult _$DeviceDiscoveryResultFromJson(
  Map<String, dynamic> json,
) => DeviceDiscoveryResult(
  ip: json['ip'] as String,
  hostname: json['hostname'] as String?,
  isReachable: json['isReachable'] as bool,
  responseTime: (json['responseTime'] as num?)?.toInt(),
  discoveryMethod: json['discoveryMethod'] as String,
);

Map<String, dynamic> _$DeviceDiscoveryResultToJson(
  DeviceDiscoveryResult instance,
) => <String, dynamic>{
  'ip': instance.ip,
  'hostname': instance.hostname,
  'isReachable': instance.isReachable,
  'responseTime': instance.responseTime,
  'discoveryMethod': instance.discoveryMethod,
};

TasmotaCommand _$TasmotaCommandFromJson(Map<String, dynamic> json) =>
    TasmotaCommand(
      topic: json['topic'] as String,
      payload: json['payload'] as String,
      retain: json['retain'] as bool? ?? false,
      qos: (json['qos'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$TasmotaCommandToJson(TasmotaCommand instance) =>
    <String, dynamic>{
      'topic': instance.topic,
      'payload': instance.payload,
      'retain': instance.retain,
      'qos': instance.qos,
    };
