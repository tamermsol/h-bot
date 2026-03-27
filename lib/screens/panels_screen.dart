import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/panel.dart';
import '../repos/panels_repo.dart';
import '../services/enhanced_mqtt_service.dart';
import 'scan_panel_qr_screen.dart';
import 'manage_panel_screen.dart';

/// Screen that lists all paired panels with status and management options
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
        backgroundColor: ctx.hCard,
        title: const Text('Unpair Panel'),
        content: Text(
          'Are you sure you want to unpair "${panel.displayName}"?\n\n'
          'The panel will need to confirm this on its touch screen. '
          'Its display configuration will be reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unpair', style: TextStyle(color: HBotColors.error)),
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
        backgroundColor: ctx.hCard,
        title: const Text('Rename Panel'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Panel name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: const Text('My Panels'),
        backgroundColor: context.hSurface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _panels.isEmpty
              ? _buildEmptyState()
              : _buildPanelList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScanPanelQRScreen(homeId: widget.homeId),
            ),
          );
          _loadPanels();
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Add Panel'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_off, size: 64, color: context.hTextSecondary),
            const SizedBox(height: 16),
            Text(
              'No panels paired yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.hTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code on your H-Bot wall panel to pair it with this app.',
              style: TextStyle(fontSize: 14, color: context.hTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanPanelQRScreen(homeId: widget.homeId),
                  ),
                );
                _loadPanels();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Panel QR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelList() {
    return RefreshIndicator(
      onRefresh: _loadPanels,
      child: ListView.builder(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        itemCount: _panels.length,
        itemBuilder: (context, index) => _buildPanelCard(_panels[index]),
      ),
    );
  }

  Widget _buildPanelCard(Panel panel) {
    final deviceCount = panel.configuredDeviceIds.length;
    final sceneCount = panel.configuredSceneIds.length;

    return Card(
      color: context.hCard,
      margin: const EdgeInsets.only(bottom: HBotSpacing.space3),
      shape: RoundedRectangleBorder(
        borderRadius: HBotRadius.mediumRadius,
        side: BorderSide(color: context.hBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: HBotRadius.mediumRadius,
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
          padding: const EdgeInsets.all(HBotSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HBotColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tv, color: HBotColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          panel.displayName,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.hTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$deviceCount devices • $sceneCount scenes',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.hTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
              const SizedBox(height: 12),
              // Device ID + broker info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.hBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.router, size: 16, color: context.hTextSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${panel.brokerAddress}:${panel.brokerPort}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.hTextSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      panel.deviceId,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.hTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
