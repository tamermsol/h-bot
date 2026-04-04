import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../models/panel.dart';

class PanelsRepo {
  /// List all panels owned by the current user
  Future<List<Panel>> listMyPanels() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await supabase
          .from('panels')
          .select('*')
          .eq('owner_user_id', user.id)
          .order('created_at');

      return (response as List).map((j) => Panel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Failed to load panels: $e');
      throw 'Failed to load panels: $e';
    }
  }

  /// Get a single panel by ID
  Future<Panel?> getPanel(String panelId) async {
    try {
      final response = await supabase
          .from('panels')
          .select('*')
          .eq('id', panelId)
          .maybeSingle();

      if (response == null) return null;
      return Panel.fromJson(response);
    } catch (e) {
      debugPrint('Failed to get panel: $e');
      throw 'Failed to get panel: $e';
    }
  }

  /// Get a panel by its hardware device_id
  Future<Panel?> getPanelByDeviceId(String deviceId) async {
    try {
      final response = await supabase
          .from('panels')
          .select('*')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) return null;
      return Panel.fromJson(response);
    } catch (e) {
      debugPrint('Failed to get panel by device ID: $e');
      throw 'Failed to get panel by device ID: $e';
    }
  }

  /// Pair a new panel from QR code data
  Future<Panel> pairPanel({
    required String deviceId,
    required String brokerAddress,
    required int brokerPort,
    required String pairingToken,
    String displayName = 'My Panel',
    String? homeId,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Hash the token for storage (panel keeps raw, we keep hash)
      final hashedToken = sha256.convert(utf8.encode(pairingToken)).toString();

      // Generate household_id stub from user ID
      final householdId = _generateHouseholdId(user.id);

      final data = {
        'device_id': deviceId,
        'display_name': displayName,
        'broker_address': brokerAddress,
        'broker_port': brokerPort,
        'pairing_token': hashedToken,
        'owner_user_id': user.id,
        'home_id': homeId,
        'household_id': householdId,
        'display_config': {
          'version': 1,
          'layout': 'grid',
          'devices': [],
          'scenes': [],
        },
      };

      final response = await supabase
          .from('panels')
          .insert(data)
          .select()
          .single();

      debugPrint('Panel paired: $deviceId');
      return Panel.fromJson(response);
    } catch (e) {
      debugPrint('Failed to pair panel: $e');
      throw 'Failed to pair panel: $e';
    }
  }

  /// Update panel display name
  Future<Panel> updateDisplayName(String panelId, String name) async {
    try {
      final response = await supabase
          .from('panels')
          .update({
            'display_name': name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', panelId)
          .select()
          .single();

      return Panel.fromJson(response);
    } catch (e) {
      debugPrint('Failed to update panel name: $e');
      throw 'Failed to update panel name: $e';
    }
  }

  /// Update panel display config (devices, scenes, layout)
  Future<Panel> updateDisplayConfig(
    String panelId,
    Map<String, dynamic> config,
  ) async {
    try {
      final response = await supabase
          .from('panels')
          .update({
            'display_config': config,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', panelId)
          .select()
          .single();

      debugPrint('Panel config updated: $panelId');
      return Panel.fromJson(response);
    } catch (e) {
      debugPrint('Failed to update panel config: $e');
      throw 'Failed to update panel config: $e';
    }
  }

  /// Delete a panel (unpair) and cascade-delete its associated relay devices.
  /// Relay devices are identified by meta_json->>'panel_device_id' matching
  /// the panel's device_id.
  Future<void> deletePanel(String panelId) async {
    try {
      // First, get the panel to know its device_id
      final panel = await getPanel(panelId);

      // Delete associated relay devices if we have the panel's device_id
      if (panel != null) {
        try {
          await supabase
              .from('devices')
              .delete()
              .eq('meta_json->>panel_device_id', panel.deviceId);
          debugPrint('Deleted relay devices for panel ${panel.deviceId}');
        } catch (e) {
          debugPrint('Failed to delete orphaned relay devices (non-fatal): $e');
        }
      }

      // Then delete the panel record
      await supabase
          .from('panels')
          .delete()
          .eq('id', panelId);

      debugPrint('Panel deleted: $panelId');
    } catch (e) {
      debugPrint('Failed to delete panel: $e');
      throw 'Failed to delete panel: $e';
    }
  }

  /// Get the raw pairing token for a panel (needed for revoke messages)
  /// Note: We store the hash, so we pass the raw token during pairing
  /// and the caller should cache it for the revoke flow.
  /// This method returns the hashed token from DB.
  Future<String?> getPairingTokenHash(String panelId) async {
    try {
      final response = await supabase
          .from('panels')
          .select('pairing_token')
          .eq('id', panelId)
          .maybeSingle();

      return response?['pairing_token'] as String?;
    } catch (e) {
      debugPrint('Failed to get pairing token: $e');
      return null;
    }
  }

  /// Generate a deterministic household ID (valid UUID format) from user ID
  String _generateHouseholdId(String userId) {
    final bytes = utf8.encode('household:$userId');
    final hex = sha256.convert(bytes).toString().substring(0, 32);
    // Format as UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
