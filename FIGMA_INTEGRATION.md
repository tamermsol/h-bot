# Figma Dev File Integration

This Flutter project includes integration with the Figma API to fetch dev file details using a personal access token.

## Features

- ✅ Connect to Figma API using personal token
- ✅ Parse Figma design URLs to extract file and node IDs
- ✅ Fetch file information including metadata
- ✅ Fetch specific node information with dimensions and properties
- ✅ Display results in a user-friendly interface
- ✅ Copy raw JSON data to clipboard
- ✅ Error handling and loading states

## Personal Token

The integration uses a personal token (stored securely):
```
YOUR_FIGMA_PERSONAL_ACCESS_TOKEN
```
**Note**: Replace with your actual Figma token. Get one from: https://www.figma.com/developers/api#access-tokens

## Target Figma File

The integration is configured to work with this specific Figma file:
```
https://www.figma.com/design/tUUu8oFzoDWuRX1Fxvnf1e/Smart-Home--Community-?node-id=0-6244&m=dev&t=D0G82uCgy6ojZkXy-1
```

**File Details:**
- File ID: `tUUu8oFzoDWuRX1Fxvnf1e`
- Node ID: `0:6244` (converted from `0-6244`)
- Project: Smart Home Community

## Files Created

### 1. `lib/services/figma_service.dart`
Core service class that handles:
- URL parsing to extract file and node IDs
- API calls to Figma endpoints
- Error handling and response processing
- Design token extraction utilities

**Key Methods:**
- `getDevFileDetails(String figmaUrl)` - Main method to fetch all details
- `getFileInfo(String fileId)` - Get file metadata
- `getNodeInfo(String fileId, String nodeId)` - Get specific node details
- `extractDesignTokens(Map<String, dynamic> fileData)` - Extract design tokens

### 2. `lib/screens/figma_dev_screen.dart`
Flutter UI screen that provides:
- URL input field (pre-filled with target URL)
- Fetch button with loading state
- Organized display of file information
- Node details with dimensions
- Raw JSON data viewer with copy functionality
- Error handling and user feedback

### 3. `figma_test.html`
Standalone HTML test page for quick API testing:
- Direct browser-based testing
- Same functionality as Flutter app
- Immediate feedback without Flutter setup
- Copy to clipboard functionality

## API Endpoints Used

1. **Get File**: `GET /v1/files/{file_id}`
   - Returns file metadata, document structure, and styles
   
2. **Get Nodes**: `GET /v1/files/{file_id}/nodes?ids={node_ids}`
   - Returns specific node information including dimensions and properties

## Data Structure

The service returns a comprehensive data structure:

```json
{
  "fileId": "tUUu8oFzoDWuRX1Fxvnf1e",
  "nodeId": "0:6244",
  "fileInfo": {
    "document": {
      "name": "Smart Home Community",
      "type": "DOCUMENT"
    },
    "lastModified": "2024-01-15T10:30:00Z",
    "version": "1234567890"
  },
  "nodeInfo": {
    "nodes": {
      "0:6244": {
        "document": {
          "name": "Component Name",
          "type": "COMPONENT",
          "absoluteBoundingBox": {
            "x": 100,
            "y": 200,
            "width": 300,
            "height": 150
          }
        }
      }
    }
  }
}
```

## Usage

### Flutter App
1. Run the Flutter app: `flutter run -d chrome`
2. The app opens directly to the Figma Dev Screen
3. The target URL is pre-filled
4. Click "Fetch Dev File Details" to retrieve data
5. View organized information or copy raw JSON

### HTML Test Page
1. Open `figma_test.html` in any modern browser
2. The page auto-loads with the target URL
3. Results display immediately
4. Use "Copy JSON to Clipboard" for data export

## Error Handling

The integration includes comprehensive error handling for:
- Invalid URLs
- Network connectivity issues
- API authentication errors
- Missing file or node IDs
- Malformed API responses

## Security Note

The personal token is embedded in the code for demonstration purposes. In production:
- Store tokens securely (environment variables, secure storage)
- Implement token rotation
- Use proper authentication flows
- Validate user permissions

## Dependencies

- `http: ^1.5.0` - For API calls
- Flutter Material Design - For UI components

## Testing

Use the HTML test page for quick verification:
1. Confirms API connectivity
2. Validates token permissions
3. Tests URL parsing logic
4. Verifies data structure

The integration successfully connects to Figma and retrieves comprehensive dev file details including file metadata, node information, and design specifications.
