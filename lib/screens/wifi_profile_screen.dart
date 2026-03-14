import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../theme/app_theme.dart';
import '../models/wifi_profile.dart';
import '../services/smart_home_service.dart';
import '../core/supabase_client.dart';

/// Screen for managing Wi-Fi profiles for device provisioning
class WiFiProfileScreen extends StatefulWidget {
  final WiFiProfile? initialProfile;
  final VoidCallback? onProfileSaved;

  const WiFiProfileScreen({
    super.key,
    this.initialProfile,
    this.onProfileSaved,
  });

  @override
  State<WiFiProfileScreen> createState() => _WiFiProfileScreenState();
}

class _WiFiProfileScreenState extends State<WiFiProfileScreen> {
  final SmartHomeService _service = SmartHomeService();
  final NetworkInfo _networkInfo = NetworkInfo();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _saveToAccount = true;
  bool _setAsDefault = true;
  bool _obscurePassword = true;
  String _statusMessage = '';
  String? _currentSSID;
  WiFiProfile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadCurrentNetwork();
    if (widget.initialProfile != null) {
      _loadExistingProfile();
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentNetwork() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid != null && mounted) {
        setState(() {
          _currentSSID = ssid.replaceAll('"', ''); // Remove quotes on Android
          _ssidController.text = _currentSSID!;
        });

        // Check if we already have a profile for this SSID
        _checkExistingProfile(_currentSSID!);
      }
    } catch (e) {
      // Ignore errors getting current network
    }
  }

  void _loadExistingProfile() {
    final profile = widget.initialProfile!;
    setState(() {
      _ssidController.text = profile.ssid;
      _passwordController.text = profile.password;
      _setAsDefault = profile.isDefault;
      _existingProfile = profile;
    });
  }

  Future<void> _checkExistingProfile(String ssid) async {
    try {
      final profile = await _service.findWiFiProfileBySSID(ssid);
      if (profile != null && mounted) {
        setState(() {
          _existingProfile = profile;
          _passwordController.text = profile.password;
          _setAsDefault = profile.isDefault;
        });
      }
    } catch (e) {
      // Ignore errors checking existing profile
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.initialProfile != null ? 'Edit WiFi Profile' : 'WiFi Profiles',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1628),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current network info
              if (_currentSSID != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0883FD).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: Color(0xFF0883FD), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Network',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF5A6577),
                              ),
                            ),
                            Text(
                              _currentSSID!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF0A1628),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_existingProfile != null)
                        const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Form fields in a card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8ECF1)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SSID field
                    const Text(
                      'Network Name (SSID)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A1628),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ssidController,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Color(0xFF0A1628),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your WiFi network name',
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF7A8494),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0883FD), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'SSID is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A1628),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Color(0xFF0A1628),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your WiFi password',
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF7A8494),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0883FD), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF5A6577),
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Options
              if (widget.initialProfile == null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8ECF1)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Save to my account',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF0A1628),
                          ),
                        ),
                        subtitle: const Text(
                          'Reuse credentials for future devices',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF5A6577),
                          ),
                        ),
                        value: _saveToAccount,
                        onChanged: (value) {
                          setState(() {
                            _saveToAccount = value;
                          });
                        },
                        activeColor: const Color(0xFF0883FD),
                      ),
                      if (_saveToAccount) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1, color: Color(0xFFF0F2F5)),
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Set as default profile',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF0A1628),
                            ),
                          ),
                          subtitle: const Text(
                            'Use by default for new devices',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF5A6577),
                            ),
                          ),
                          value: _setAsDefault,
                          onChanged: (value) {
                            setState(() {
                              _setAsDefault = value;
                            });
                          },
                          activeColor: const Color(0xFF0883FD),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Status message
              if (_statusMessage.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save button
              InkWell(
                onTap: _isLoading ? null : _saveProfile,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                          ),
                    color: _isLoading ? const Color(0xFFD1D7E0) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            widget.initialProfile != null ? 'Update Profile' : 'Save',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if user is signed in
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'You must be signed in before saving Wi-Fi.';
      });
      return;
    }

    // Get trimmed values
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    // Additional validation
    if (ssid.isEmpty) {
      setState(() {
        _statusMessage = 'SSID is required.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _statusMessage = 'Password is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving Wi-Fi profile...';
    });

    try {
      if (_saveToAccount) {
        // Use the SmartHomeService instead of direct Supabase calls
        final request = WiFiProfileRequest(
          ssid: ssid,
          password: password,
          isDefault: _setAsDefault,
        );

        if (_existingProfile != null) {
          // Update existing profile
          await _service.updateWiFiProfile(_existingProfile!.id, request);
        } else {
          // Create new profile
          await _service.createWiFiProfile(request);
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Wi-Fi profile saved.';
        });

        // Notify parent and close after a short delay
        widget.onProfileSaved?.call();

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, {'ssid': ssid, 'password': password});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Failed to save Wi-Fi profile: ${e.toString().split(':').last.trim()}';
        });
      }
    }
  }
}
