import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../models/panel.dart';
import '../repos/panels_repo.dart';
import '../services/enhanced_mqtt_service.dart';
import 'scan_panel_qr_screen.dart';
import 'manage_panel_screen.dart';

/// Screen that lists all paired panels with status and management options.
/// Uses Pixel's dark glassmorphism design.
class PanelsScreen extends StatefulWidget {
  final String? homeId;

  const PanelsScreen({super.key, this.homeId});

  @override
  State<PanelsScreen> createState() => _PanelsScreenState();
}

class _PanelsScreenState extends State<PanelsScreen> {
  final PanelsRepo _panelsRepo = PanelsRepo();
  List<Panel> _panels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPanels();
  }

  Future<void> _loadPanels() async {
    try {
      setState(() => _isLoading = true);
      _panels = await _panelsRepo.listMyPanels();
    } catch (e) {
      debugPrint('Error loading panels: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unpairPanel(Panel panel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: const Text('Unpair Panel', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unpair "${panel.displayName}"?\n\n'
          'The panel will need to confirm this on its touch screen. '
          'Its display configuration will be reset.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unpair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Publish revoke message via MQTT
      try {
        final mqtt = EnhancedMqttService();
        if (mqtt.isConnected) {
          final tokenHash = await _panelsRepo.getPairingTokenHash(panel.id);
          mqtt.publishRetained(
            'hbot/panels/${panel.deviceId}/pair/revoke',
            jsonEncode({
              'device_id': panel.deviceId,
              'token': tokenHash,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
          // Clear the config retained message
          mqtt.publishRetained('hbot/panels/${panel.deviceId}/config', '');
        }
      } catch (e) {
        debugPrint('MQTT revoke publish failed: $e');
      }

      // Delete from Supabase
      await _panelsRepo.deletePanel(panel.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${panel.displayName}" unpaired. Walk up to the panel and tap Confirm if prompted.'),
          backgroundColor: HBotColors.success,
        ),
      );

      _loadPanels();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unpair: $e'), backgroundColor: HBotColors.error),
      );
    }
  }

  Future<void> _renamePanel(Panel panel) async {
    final controller = TextEditingController(text: panel.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: const Text('Rename Panel', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Panel name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: BorderSide(color: HBotColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: HBotColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      await _panelsRepo.updateDisplayName(panel.id, newName);
      _loadPanels();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $e'), backgroundColor: HBotColors.error),
      );
    }
  }

  void _navigateToAddPanel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPanelQRScreen(homeId: widget.homeId),
      ),
    );
    _loadPanels();
  }

  String _timeSince(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  int get _onlineCount => _panels.where((p) => p.pairedAt != null).length;
  int get _offlineCount => _panels.where((p) => p.pairedAt == null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: back button + "Panels" + count badge + gradient add button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HBotSpacing.space5, HBotSpacing.space4,
                  HBotSpacing.space5, 0,
                ),
                child: Row(
                  children: [
                    HBotIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: HBotSpacing.space4),
                    const Text(
                      'Panels',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: HBotSpacing.space2),
                    // Count badge
                    if (!_isLoading && _panels.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x260883FD), // rgba(8,131,253,0.15)
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_panels.length}',
                          style: const TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HBotColors.primary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Gradient add button — 40x40 square
                    GestureDetector(
                      onTap: _navigateToAddPanel,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D0883FD),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: HBotSpacing.space5),

              // Summary row: 3 glass stat cards
              if (!_isLoading && _panels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          '${_panels.length}',
                          HBotColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Online',
                          '$_onlineCount',
                          const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Offline',
                          '$_offlineCount',
                          HBotColors.error,
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_isLoading && _panels.isNotEmpty)
                const SizedBox(height: HBotSpacing.space5),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                        ),
                      )
                    : _panels.isEmpty
                        ? _buildEmptyState()
                        : _buildPanelList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HBotColors.glassBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HBotColors.glassBorder, width: 1),
          ),
          child: Column(
            children: [
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: HBotColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: Icon(
                Icons.tv_off_rounded,
                size: 36,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),
            const Text(
              'No panels paired',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space3),
            Text(
              'Scan the QR code on your H-Bot wall panel to pair it with this app.',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            HBotGradientButton(
              onTap: _navigateToAddPanel,
              fullWidth: false,
              padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space6),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 20),
                  SizedBox(width: 8),
                  Text('Scan Panel QR'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelList() {
    final onlinePanels = _panels.where((p) => p.pairedAt != null).toList();
    final offlinePanels = _panels.where((p) => p.pairedAt == null).toList();

    return RefreshIndicator(
      onRefresh: _loadPanels,
      color: HBotColors.primary,
      backgroundColor: HBotColors.sheetBackground,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
        children: [
          // Online section
          if (onlinePanels.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: HBotSectionLabel('Online'),
            ),
            ...onlinePanels.map((p) => _buildPanelCard(p, isOnline: true)),
          ],
          // Offline section
          if (offlinePanels.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(
                top: onlinePanels.isNotEmpty ? HBotSpacing.space4 : 0,
                bottom: 10,
              ),
              child: const HBotSectionLabel('Offline'),
            ),
            ...offlinePanels.map((p) => _buildPanelCard(p, isOnline: false)),
          ],
          const SizedBox(height: HBotSpacing.space5),
        ],
      ),
    );
  }

  Widget _buildPanelCard(Panel panel, {required bool isOnline}) {
    final deviceCount = panel.configuredDeviceIds.length;
    final sceneCount = panel.configuredSceneIds.length;
    final lastSeen = _timeSince(panel.updatedAt ?? panel.pairedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Opacity(
        opacity: isOnline ? 1.0 : 0.65,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManagePanelScreen(panel: panel),
                      ),
                    );
                    _loadPanels();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Panel icon — 48x48 with status-colored bg
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0x1A34D399) // rgba(52,211,153,0.1)
                                    : const Color(0x1AEF4444), // rgba(239,68,68,0.1)
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFF34D399).withOpacity(0.3)
                                      : HBotColors.error.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.tv_rounded,
                                color: isOnline ? const Color(0xFF34D399) : HBotColors.error,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: HBotSpacing.space3),
                            // Name + location
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          panel.displayName,
                                          style: const TextStyle(
                                            fontFamily: 'Readex Pro',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Online/offline status indicator
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isOnline ? const Color(0xFF34D399) : HBotColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          fontFamily: 'Readex Pro',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOnline ? const Color(0xFF34D399) : HBotColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Last seen: $lastSeen',
                                    style: const TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontSize: 12,
                                      color: HBotColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // More menu
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.white.withOpacity(0.6),
                                size: 20,
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'rename':
                                    _renamePanel(panel);
                                    break;
                                  case 'unpair':
                                    _unpairPanel(panel);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'unpair',
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_off, size: 18, color: HBotColors.error),
                                      const SizedBox(width: 8),
                                      Text('Unpair', style: TextStyle(color: HBotColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: HBotSpacing.space3),
                        // Detail chips row: signal, device count, scene count
                        Row(
                          children: [
                            _buildDetailChip(
                              Icons.signal_wifi_4_bar_rounded,
                              isOnline ? '-42 dBm' : 'N/A',
                              isOnline ? const Color(0xFF34D399) : HBotColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            _buildDetailChip(
                              Icons.devices_rounded,
                              '$deviceCount devices',
                              HBotColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildDetailChip(
                              Icons.auto_awesome_rounded,
                              '$sceneCount scenes',
                              const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                        const SizedBox(height: HBotSpacing.space3),
                        // Tap to manage hint
                        Center(
                          child: Text(
                            'Tap to manage display',
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF), // rgba(255,255,255,0.03)
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
