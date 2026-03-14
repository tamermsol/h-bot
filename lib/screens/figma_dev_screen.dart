import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/figma_service.dart';

class FigmaDevScreen extends StatefulWidget {
  const FigmaDevScreen({super.key});

  @override
  State<FigmaDevScreen> createState() => _FigmaDevScreenState();
}

class _FigmaDevScreenState extends State<FigmaDevScreen> {
  final TextEditingController _urlController = TextEditingController();
  Map<String, dynamic>? _devFileDetails;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the provided URL
    _urlController.text =
        'https://www.figma.com/design/tUUu8oFzoDWuRX1Fxvnf1e/Smart-Home--Community-?node-id=0-6244&m=dev&t=D0G82uCgy6ojZkXy-1';
  }

  Future<void> _fetchDevFileDetails() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a Figma URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _devFileDetails = null;
    });

    try {
      final details = await FigmaService.getDevFileDetails(
        _urlController.text.trim(),
      );
      setState(() {
        _devFileDetails = details;
        _isLoading = false;
        if (details == null) {
          _errorMessage = 'Failed to fetch dev file details';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Widget _buildFileInfoSection() {
    if (_devFileDetails == null || _devFileDetails!['fileInfo'] == null) {
      return const SizedBox.shrink();
    }

    final fileInfo = _devFileDetails!['fileInfo'] as Map<String, dynamic>;
    final document = fileInfo['document'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (document != null) ...[
              _buildInfoRow('Name', document['name'] ?? 'Unknown'),
              _buildInfoRow('Type', document['type'] ?? 'Unknown'),
              _buildInfoRow('File ID', _devFileDetails!['fileId'] ?? 'Unknown'),
              if (_devFileDetails!['nodeId']?.isNotEmpty == true)
                _buildInfoRow('Node ID', _devFileDetails!['nodeId']),
            ],
            if (fileInfo['lastModified'] != null)
              _buildInfoRow('Last Modified', fileInfo['lastModified']),
            if (fileInfo['version'] != null)
              _buildInfoRow('Version', fileInfo['version'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeInfoSection() {
    if (_devFileDetails == null || _devFileDetails!['nodeInfo'] == null) {
      return const SizedBox.shrink();
    }

    final nodeInfo = _devFileDetails!['nodeInfo'] as Map<String, dynamic>;
    final nodes = nodeInfo['nodes'] as Map<String, dynamic>?;

    if (nodes == null || nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Node Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...nodes.entries.map((entry) {
              final nodeData = entry.value['document'] as Map<String, dynamic>?;
              if (nodeData == null) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Node: ${entry.key}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Name', nodeData['name'] ?? 'Unknown'),
                  _buildInfoRow('Type', nodeData['type'] ?? 'Unknown'),
                  if (nodeData['absoluteBoundingBox'] != null)
                    ..._buildBoundingBoxInfo(
                      nodeData['absoluteBoundingBox'] as Map<String, dynamic>,
                    ),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataSection() {
    if (_devFileDetails == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raw Data (JSON)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _formatJson(_devFileDetails!)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _formatJson(_devFileDetails!),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBoundingBoxInfo(Map<String, dynamic> bbox) {
    return [
      _buildInfoRow('Width', '${bbox['width']}'),
      _buildInfoRow('Height', '${bbox['height']}'),
      _buildInfoRow('X', '${bbox['x']}'),
      _buildInfoRow('Y', '${bbox['y']}'),
    ];
  }

  String _formatJson(Map<String, dynamic> data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Figma Dev File Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // URL Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Figma URL',
                    hintText: 'Enter Figma design URL',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _fetchDevFileDetails,
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Fetching...'),
                            ],
                          )
                        : const Text('Fetch Dev File Details'),
                  ),
                ),
              ],
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HBotColors.errorLight,
                border: Border.all(color: HBotColors.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: HBotColors.errorDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: HBotColors.errorDark),
                    ),
                  ),
                ],
              ),
            ),

          // Results Section
          Expanded(
            child: _devFileDetails != null
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildFileInfoSection(),
                        _buildNodeInfoSection(),
                        _buildRawDataSection(),
                      ],
                    ),
                  )
                : const Center(
                    child: Text(
                      'Enter a Figma URL and click "Fetch Dev File Details" to get started',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
