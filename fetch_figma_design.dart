import 'dart:convert';
import 'dart:io';

void main() async {
  const figmaToken =
      'YOUR_FIGMA_PERSONAL_ACCESS_TOKEN'; // Replace with your actual token
  const fileKey = 'tUUu8oFzoDWuRX1Fxvnf1e';
  const nodeId = '0-6244';

  final client = HttpClient();

  try {
    // Get file data
    final request = await client.getUrl(
      Uri.parse('https://api.figma.com/v1/files/$fileKey'),
    );
    request.headers.set('X-Figma-Token', figmaToken);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      print('=== FIGMA FILE DATA ===');
      print(jsonEncode(data));

      // Also try to get specific node
      final nodeRequest = await client.getUrl(
        Uri.parse('https://api.figma.com/v1/files/$fileKey/nodes?ids=$nodeId'),
      );
      nodeRequest.headers.set('X-Figma-Token', figmaToken);

      final nodeResponse = await nodeRequest.close();
      final nodeResponseBody = await nodeResponse
          .transform(utf8.decoder)
          .join();

      if (nodeResponse.statusCode == 200) {
        final nodeData = jsonDecode(nodeResponseBody);
        print('\n=== FIGMA NODE DATA ===');
        print(jsonEncode(nodeData));
      }
    } else {
      print('Error: ${response.statusCode}');
      print(responseBody);
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
