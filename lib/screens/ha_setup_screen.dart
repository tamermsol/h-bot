import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/background_container.dart';
import '../services/ha_websocket_service.dart';
import '../repos/ha_repo.dart';
import '../models/ha_connection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ha_entities_screen.dart';

/// Screen for setting up a Home Assistant connection.
/// User enters their HA instance URL and a long-lived access token.
class HaSetupScreen extends StatefulWidget {
  const HaSetupScreen({super.key});

  @override
  State<HaSetupScreen> createState() => _HaSetupScreenState();
}

class _HaSetupScreenState extends State<HaSetupScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController(text: 'Home');
  final _formKey = GlobalKey<FormState>();
  final _repo = HaRepo(Supabase.instance.client);

  bool _isLoading = false;
  bool _isTesting = false;
  String? _error;
  String? _haVersion;
  HaConnection? _existingConnection;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final conn = await _repo.getActiveConnection();
    if (conn != null && mounted) {
      setState(() {
        _existingConnection = conn;
        _urlController.text = conn.baseUrl;
        _tokenController.text = conn.accessToken ?? '';
        _nameController.text = conn.instanceName;
        _haVersion = conn.haVersion;
      });
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _error = null;
      _haVersion = null;
    });

    final ws = HaWebSocketService();
    try {
      final testConn = HaConnection(
        id: '',
        userId: '',
        baseUrl: _urlController.text.trim(),
        accessToken: _tokenController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final connected = await ws.connect(testConn);
      if (!connected) {
        setState(() => _error = 'Could not connect to Home Assistant');
        return;
      }

      // Wait for auth
      final state = await ws.connectionState
          .firstWhere((s) =>
              s == HaConnectionState.connected ||
              s == HaConnectionState.authFailed)
          .timeout(const Duration(seconds: 10));

      if (state == HaConnectionState.authFailed) {
        setState(() => _error = 'Invalid access token');
        return;
      }

      // Get config to verify
      final config = await ws.getConfig();
      setState(() {
        _haVersion = config['version'] as String?;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      ws.disconnect();
      ws.dispose();
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _repo.upsertConnection(
        baseUrl: _urlController.text.trim(),
        accessToken: _tokenController.text.trim(),
        instanceName: _nameController.text.trim(),
        haVersion: _haVersion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home Assistant connected!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HaEntitiesScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    if (_existingConnection == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Home Assistant?'),
        content: const Text(
          'This will remove all imported entities. '
          'Your Home Assistant setup is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _repo.deleteConnection(_existingConnection!.id);
      setState(() {
        _existingConnection = null;
        _urlController.clear();
        _tokenController.clear();
        _nameController.text = 'Home';
        _haVersion = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Assistant'),
        actions: [
          if (_existingConnection != null)
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: _disconnect,
            ),
        ],
      ),
      body: BackgroundContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.home_outlined,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect Home Assistant',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Control devices from any vendor through your Home Assistant instance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Instance name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Instance Name',
                    hintText: 'Home',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // URL
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Home Assistant URL',
                    hintText: 'http://192.168.1.100:8123',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your HA URL';
                    }
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null || !uri.hasScheme) {
                      return 'Enter a valid URL (http:// or https://)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Token
                TextFormField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Long-Lived Access Token',
                    hintText: 'Paste your token here',
                    prefixIcon: Icon(Icons.key),
                  ),
                  obscureText: true,
                  maxLines: 1,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your access token';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a token in HA: Profile → Security → Long-Lived Access Tokens',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),

                // Error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // HA Version (after successful test)
                if (_haVersion != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Connected — HA v$_haVersion'),
                      ],
                    ),
                  ),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        label:
                            Text(_isTesting ? 'Testing...' : 'Test'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _saveConnection,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_existingConnection != null
                            ? 'Update'
                            : 'Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
