import '../core/supabase_client.dart';
import '../models/device_share_invitation.dart';
import '../models/device_share_request.dart';
import '../models/shared_device.dart';
import 'package:flutter/foundation.dart';

class DeviceSharingRepo {
  /// Generate a unique invitation code for device sharing
  Future<String> _generateInvitationCode() async {
    try {
      final response = await supabase.rpc('generate_invitation_code');
      return response as String;
    } catch (e) {
      throw 'Failed to generate invitation code: $e';
    }
  }

  /// Create a sharing invitation for a device (generates QR code data)
  Future<DeviceShareInvitation> createInvitation(String deviceId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final invitationCode = await _generateInvitationCode();

      final response = await supabase
          .from('device_share_invitations')
          .insert({
            'device_id': deviceId,
            'owner_id': userId,
            'invitation_code': invitationCode,
          })
          .select()
          .single();

      return DeviceShareInvitation.fromJson(response);
    } catch (e) {
      throw 'Failed to create invitation: $e';
    }
  }

  /// Get invitation by code (for scanning QR)
  Future<DeviceShareInvitation?> getInvitationByCode(String code) async {
    try {
      final response = await supabase
          .from('device_share_invitations')
          .select()
          .eq('invitation_code', code)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (response == null) return null;
      return DeviceShareInvitation.fromJson(response);
    } catch (e) {
      throw 'Failed to get invitation: $e';
    }
  }

  /// Delete an invitation
  Future<void> deleteInvitation(String invitationId) async {
    try {
      await supabase
          .from('device_share_invitations')
          .delete()
          .eq('id', invitationId);
    } catch (e) {
      throw 'Failed to delete invitation: $e';
    }
  }

  /// Create a share request (after scanning QR)
  Future<DeviceShareRequest> createShareRequest({
    required String deviceId,
    required String ownerId,
    required String requesterEmail,
    String? requesterName,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await supabase
          .from('device_share_requests')
          .insert({
            'device_id': deviceId,
            'owner_id': ownerId,
            'requester_id': userId,
            'requester_email': requesterEmail,
            'requester_name': requesterName,
          })
          .select()
          .single();

      return DeviceShareRequest.fromJson(response);
    } catch (e) {
      throw 'Failed to create share request: $e';
    }
  }

  /// Instantly share device (no approval needed)
  Future<SharedDevice> instantShareDevice({
    required String deviceId,
    required String ownerId,
    PermissionLevel permissionLevel = PermissionLevel.control,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      // Auto-create "My Home" if the recipient has no homes yet
      await _ensureUserHasHome();

      final response = await supabase
          .from('shared_devices')
          .insert({
            'device_id': deviceId,
            'owner_id': ownerId,
            'shared_with_id': userId,
            'permission_level': permissionLevel.name,
          })
          .select()
          .single();

      return SharedDevice.fromJson(response);
    } catch (e) {
      throw 'Failed to share device: $e';
    }
  }

  /// Ensure the current user has at least one home; create "My Home" if not.
  Future<void> _ensureUserHasHome() async {
    try {
      final homes = await supabase.from('homes').select('id').limit(1);
      if ((homes as List).isEmpty) {
        // Create default "My Home"
        final homeResponse = await supabase
            .from('homes')
            .insert({'name': 'My Home'})
            .select()
            .single();

        final homeId = homeResponse['id'] as String;

        // Create a default room
        await supabase.from('rooms').insert({
          'home_id': homeId,
          'name': 'My Devices',
          'sort_order': 0,
        });

        debugPrint('DeviceSharingRepo: Created default "My Home" for new user');
      }
    } catch (e) {
      // Non-fatal — user might already have homes or RLS may block the check
      debugPrint('DeviceSharingRepo: Could not ensure home exists: $e');
    }
  }

  /// Get pending share requests for owner
  Future<List<DeviceShareRequest>> getPendingRequests() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await supabase
          .from('device_share_requests')
          .select('*, devices(name, device_type)')
          .eq('owner_id', userId)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);

      return (response as List).map((json) {
        final request = DeviceShareRequest.fromJson(json);
        if (json['devices'] != null) {
          request.deviceName = json['devices']['name'];
          request.deviceType = json['devices']['device_type'];
        }
        return request;
      }).toList();
    } catch (e) {
      throw 'Failed to get pending requests: $e';
    }
  }

  /// Get share requests sent by current user
  Future<List<DeviceShareRequest>> getMyRequests() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await supabase
          .from('device_share_requests')
          .select('*, devices(name, device_type)')
          .eq('requester_id', userId)
          .order('requested_at', ascending: false);

      return (response as List).map((json) {
        final request = DeviceShareRequest.fromJson(json);
        if (json['devices'] != null) {
          request.deviceName = json['devices']['name'];
          request.deviceType = json['devices']['device_type'];
        }
        return request;
      }).toList();
    } catch (e) {
      throw 'Failed to get my requests: $e';
    }
  }

  /// Approve a share request
  Future<void> approveRequest(
    String requestId,
    PermissionLevel permissionLevel,
  ) async {
    try {
      // Get the request details
      final request = await supabase
          .from('device_share_requests')
          .select()
          .eq('id', requestId)
          .single();

      // Create shared device entry
      await supabase.from('shared_devices').insert({
        'device_id': request['device_id'],
        'owner_id': request['owner_id'],
        'shared_with_id': request['requester_id'],
        'permission_level': permissionLevel.name,
      });

      // Update request status
      await supabase
          .from('device_share_requests')
          .update({
            'status': 'approved',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw 'Failed to approve request: $e';
    }
  }

  /// Reject a share request
  Future<void> rejectRequest(String requestId) async {
    try {
      await supabase
          .from('device_share_requests')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw 'Failed to reject request: $e';
    }
  }

  /// Get devices shared with current user
  Future<List<SharedDevice>> getSharedWithMe() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await supabase
          .from('shared_devices')
          .select('*, devices(name, device_type)')
          .eq('shared_with_id', userId)
          .order('shared_at', ascending: false);

      return (response as List).map((json) {
        final shared = SharedDevice.fromJson(json);
        if (json['devices'] != null) {
          shared.deviceName = json['devices']['name'];
          shared.deviceType = json['devices']['device_type'];
        }
        return shared;
      }).toList();
    } catch (e) {
      throw 'Failed to get shared devices: $e';
    }
  }

  /// Get devices I've shared with others
  Future<List<SharedDevice>> getDevicesIShared() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final response = await supabase
          .from('shared_devices')
          .select('*, devices(name, device_type)')
          .eq('owner_id', userId)
          .order('shared_at', ascending: false);

      return (response as List).map((json) {
        final shared = SharedDevice.fromJson(json);
        if (json['devices'] != null) {
          shared.deviceName = json['devices']['name'];
          shared.deviceType = json['devices']['device_type'];
        }
        return shared;
      }).toList();
    } catch (e) {
      throw 'Failed to get devices I shared: $e';
    }
  }

  /// Revoke device sharing
  Future<void> revokeSharing(String sharedDeviceId) async {
    try {
      await supabase.from('shared_devices').delete().eq('id', sharedDeviceId);
    } catch (e) {
      throw 'Failed to revoke sharing: $e';
    }
  }

  /// Check if device is shared with current user
  Future<SharedDevice?> getSharedDeviceAccess(String deviceId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await supabase
          .from('shared_devices')
          .select()
          .eq('device_id', deviceId)
          .eq('shared_with_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return SharedDevice.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Clean up expired invitations
  Future<void> cleanupExpiredInvitations() async {
    try {
      await supabase.rpc('cleanup_expired_invitations');
    } catch (e) {
      // Silent fail - this is a cleanup operation
      debugPrint('Failed to cleanup expired invitations: $e');
    }
  }
}
