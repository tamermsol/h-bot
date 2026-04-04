// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'panel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Panel _$PanelFromJson(Map<String, dynamic> json) => Panel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      displayName: json['display_name'] as String,
      brokerAddress: json['broker_address'] as String,
      brokerPort: (json['broker_port'] as num?)?.toInt() ?? 1883,
      pairingToken: json['pairing_token'] as String,
      ownerUserId: json['owner_user_id'] as String,
      homeId: json['home_id'] as String?,
      householdId: json['household_id'] as String,
      displayConfig: json['display_config'] as Map<String, dynamic>?,
      pairedAt: json['paired_at'] == null
          ? null
          : DateTime.parse(json['paired_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$PanelToJson(Panel instance) => <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'display_name': instance.displayName,
      'broker_address': instance.brokerAddress,
      'broker_port': instance.brokerPort,
      'pairing_token': instance.pairingToken,
      'owner_user_id': instance.ownerUserId,
      'home_id': instance.homeId,
      'household_id': instance.householdId,
      'display_config': instance.displayConfig,
      'paired_at': instance.pairedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
