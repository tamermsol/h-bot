import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FigmaService {
  static const String _baseUrl = 'https://api.figma.com/v1';
  static const String _personalToken =
      'YOUR_FIGMA_PERSONAL_ACCESS_TOKEN'; // TODO: Move to environment variables

  // Extract file ID and node ID from the Figma URL
  static Map<String, String> _parseFileUrl(String url) {
    // URL format: https://www.figma.com/design/tUUu8oFzoDWuRX1Fxvnf1e/Smart-Home--Community-?node-id=0-6244&m=dev&t=D0G82uCgy6ojZkXy-1
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    String? fileId;
    String? nodeId;

    // Extract file ID from path
    if (pathSegments.length >= 2 && pathSegments[0] == 'design') {
      fileId = pathSegments[1];
    }

    // Extract node ID from query parameters
    final nodeIdParam = uri.queryParameters['node-id'];
    if (nodeIdParam != null) {
      nodeId = nodeIdParam.replaceAll('-', ':');
    }

    return {'fileId': fileId ?? '', 'nodeId': nodeId ?? ''};
  }

  // Get file information
  static Future<Map<String, dynamic>?> getFileInfo(String fileId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/files/$fileId'),
        headers: {
          'X-Figma-Token': _personalToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          'Error getting file info: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Exception getting file info: $e');
      return null;
    }
  }

  // Get specific node information
  static Future<Map<String, dynamic>?> getNodeInfo(
    String fileId,
    String nodeId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/files/$fileId/nodes?ids=$nodeId'),
        headers: {
          'X-Figma-Token': _personalToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          'Error getting node info: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Exception getting node info: $e');
      return null;
    }
  }

  // Get dev resources for a node
  static Future<Map<String, dynamic>?> getDevResources(
    String fileId,
    String nodeId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/files/$fileId/nodes?ids=$nodeId&plugin_data=shared',
        ),
        headers: {
          'X-Figma-Token': _personalToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          'Error getting dev resources: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Exception getting dev resources: $e');
      return null;
    }
  }

  // Main method to get all dev file details from URL
  static Future<Map<String, dynamic>?> getDevFileDetails(
    String figmaUrl,
  ) async {
    final urlData = _parseFileUrl(figmaUrl);
    final fileId = urlData['fileId']!;
    final nodeId = urlData['nodeId']!;

    if (fileId.isEmpty) {
      debugPrint('Could not extract file ID from URL');
      return null;
    }

    debugPrint('Fetching details for File ID: $fileId, Node ID: $nodeId');

    // Get file information
    final fileInfo = await getFileInfo(fileId);
    if (fileInfo == null) {
      return null;
    }

    Map<String, dynamic> result = {
      'fileId': fileId,
      'nodeId': nodeId,
      'fileInfo': fileInfo,
    };

    // Get specific node information if node ID is available
    if (nodeId.isNotEmpty) {
      final nodeInfo = await getNodeInfo(fileId, nodeId);
      if (nodeInfo != null) {
        result['nodeInfo'] = nodeInfo;
      }

      // Get dev resources
      final devResources = await getDevResources(fileId, nodeId);
      if (devResources != null) {
        result['devResources'] = devResources;
      }
    }

    return result;
  }

  // Helper method to extract design tokens and styles
  static Map<String, dynamic> extractDesignTokens(
    Map<String, dynamic> fileData,
  ) {
    Map<String, dynamic> tokens = {
      'colors': {},
      'typography': {},
      'effects': {},
      'grids': {},
    };

    // Extract color styles
    if (fileData['styles'] != null) {
      final styles = fileData['styles'] as Map<String, dynamic>;
      styles.forEach((key, value) {
        if (value['styleType'] == 'FILL') {
          tokens['colors'][key] = value;
        } else if (value['styleType'] == 'TEXT') {
          tokens['typography'][key] = value;
        } else if (value['styleType'] == 'EFFECT') {
          tokens['effects'][key] = value;
        } else if (value['styleType'] == 'GRID') {
          tokens['grids'][key] = value;
        }
      });
    }

    return tokens;
  }
}
