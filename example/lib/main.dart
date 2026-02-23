import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:biometric_crypto/biometric_crypto.dart';

void main() {
  // Service Locator / Dependency Injection Setup
  _setupDependencies();
  runApp(const MyApp());
}

void _setupDependencies() {
  // Simple DI setup - register services
  _serviceLocator.registerBiometricCryptoService();
}

class _ServiceLocator {
  static final _ServiceLocator _instance = _ServiceLocator._internal();

  late BiometricCryptoService _biometricCryptoService;

  factory _ServiceLocator() {
    return _instance;
  }

  _ServiceLocator._internal();

  void registerBiometricCryptoService() {
    _biometricCryptoService = BiometricCryptoService(BiometricCrypto());
  }

  BiometricCryptoService get biometricCryptoService => _biometricCryptoService;
}

final _serviceLocator = _ServiceLocator();

BiometricCryptoService get biometricCryptoService =>
    _serviceLocator.biometricCryptoService;

/// Service Wrapper untuk BiometricCrypto Plugin
class BiometricCryptoService {
  final BiometricCrypto _biometricCrypto;
  static const String _keyAlias = 'biometric_key';

  BiometricCryptoService(this._biometricCrypto);

  /// Check apakah biometric tersedia
  Future<bool> isBiometricAvailable() async {
    try {
      return await _biometricCrypto.isBiometricAvailable();
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Check apakah key sudah ada
  Future<bool> keyExists() async {
    try {
      return await _biometricCrypto.keyExists(_keyAlias);
    } catch (e) {
      print('Error checking key existence: $e');
      return false;
    }
  }

  /// Generate key baru
  Future<bool> generateKey() async {
    try {
      await _biometricCrypto.generateKey(_keyAlias);
      return true;
    } catch (e) {
      print('Error generating key: $e');
      return false;
    }
  }

  /// Authenticate dengan biometric dan sign data
  Future<BiometricSignResult?> signWithBiometric(String challenge) async {
    try {
      // Authenticate user
      final authenticated = await _biometricCrypto.authenticate();
      if (!authenticated) {
        return null;
      }

      // Sign dengan biometric
      final signature = await _biometricCrypto.sign(_keyAlias, challenge);

      // Get public key
      final publicKey = await _biometricCrypto.getPublicKey(_keyAlias);

      return BiometricSignResult(
        signature: signature,
        publicKey: publicKey,
        challenge: challenge,
      );
    } on PlatformException catch (e) {
      print('Platform Exception during biometric sign: ${e.message}');
      return null;
    } catch (e) {
      print('Error during biometric sign: $e');
      return null;
    }
  }

  /// Get public key
  Future<String> getPublicKey() async {
    try {
      return await _biometricCrypto.getPublicKey(_keyAlias);
    } catch (e) {
      print('Error getting public key: $e');
      rethrow;
    }
  }

  /// Delete key
  Future<void> deleteKey() async {
    try {
      await _biometricCrypto.deleteKey(_keyAlias);
    } catch (e) {
      print('Error deleting key: $e');
      rethrow;
    }
  }
}

class BiometricSignResult {
  final String signature;
  final String publicKey;
  final String challenge;

  BiometricSignResult({
    required this.signature,
    required this.publicKey,
    required this.challenge,
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometric Crypto Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BiometricCryptoDemo(),
    );
  }
}

class BiometricCryptoDemo extends StatefulWidget {
  const BiometricCryptoDemo({super.key});

  @override
  State<BiometricCryptoDemo> createState() => _BiometricCryptoDemoState();
}

class _BiometricCryptoDemoState extends State<BiometricCryptoDemo> {
  late BiometricCryptoService _service;
  bool _isBiometricAvailable = false;
  bool _keyExists = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _statusMessage = 'Initializing...';
  BiometricSignResult? _signResult;

  @override
  void initState() {
    super.initState();
    _service = biometricCryptoService;
    _initializeBiometricFlow();
  }

  /// Flow 1: Initialize dan check biometric availability
  Future<void> _initializeBiometricFlow() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking biometric availability...';
    });

    try {
      // Step 1: Check biometric available
      final isBioAvailable = await _service.isBiometricAvailable();
      if (!mounted) return;

      setState(() {
        _isBiometricAvailable = isBioAvailable;
      });

      if (!isBioAvailable) {
        setState(() {
          _statusMessage = '❌ Biometric tidak tersedia di device ini';
          _isLoading = false;
          _isInitialized = true;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Biometric tersedia ✓\nMengecek key...';
      });

      // Step 2: Check key exists
      final keyExist = await _service.keyExists();
      if (!mounted) return;

      setState(() {
        _keyExists = keyExist;
      });

      if (keyExist) {
        setState(() {
          _statusMessage = '✓ Biometric tersedia\n✓ Key sudah ada\n\nSiap untuk sign dengan biometric';
          _isLoading = false;
          _isInitialized = true;
        });
      } else {
        setState(() {
          _statusMessage = '✓ Biometric tersedia\n❌ Key belum ada\n\nKlik "Generate Key" untuk membuat key baru';
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  /// Flow 2: Generate key
  Future<void> _generateKeyFlow() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating key...';
    });

    try {
      final success = await _service.generateKey();
      if (!mounted) return;

      if (success) {
        setState(() {
          _keyExists = true;
          _statusMessage = '✓ Biometric tersedia\n✓ Key berhasil dibuat\n\nSiap untuk sign dengan biometric';
          _isLoading = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Gagal membuat key';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Flow 3: Sign dengan biometric dan dapatkan public key
  Future<void> _signWithBiometricFlow() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating dengan biometric...';
    });

    try {
      // Generate random challenge
      final challenge = DateTime.now().millisecondsSinceEpoch.toString();

      final result = await _service.signWithBiometric(challenge);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _signResult = result;
          _statusMessage = 'Sign berhasil! ✓';
          _isLoading = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Authentication dibatalkan atau gagal';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Crypto Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Flow Steps
            if (_isInitialized) ...[
              const Text(
                'Flow Biometric Signin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildFlowStep(
                number: 1,
                title: 'Check Biometric Available',
                isCompleted: _isBiometricAvailable,
              ),
              const SizedBox(height: 8),
              _buildFlowStep(
                number: 2,
                title: 'Check Key Exists',
                isCompleted: _keyExists,
              ),
              const SizedBox(height: 16),

              // Action Buttons
              if (!_keyExists)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateKeyFlow,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Generate Key'),
                  ),
                ),
              if (!_keyExists) const SizedBox(height: 12),
              if (_keyExists)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signWithBiometricFlow,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Sign dengan Biometric'),
                  ),
                ),

              // Result Card
              if (_signResult != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Hasil Sign',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildResultField(
                  label: 'Challenge',
                  value: _signResult!.challenge,
                ),
                const SizedBox(height: 12),
                _buildResultField(
                  label: 'Signature',
                  value: _signResult!.signature,
                ),
                const SizedBox(height: 12),
                _buildResultField(
                  label: 'Public Key',
                  value: _signResult!.publicKey,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signWithBiometricFlow,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Sign Lagi'),
                  ),
                ),
              ],
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep({
    required int number,
    required String title,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.grey,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isCompleted ? Colors.green.shade50 : Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted ? Colors.green.shade900 : Colors.grey.shade700,
              ),
            ),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildResultField({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
