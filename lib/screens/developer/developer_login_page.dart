import 'package:flutter/material.dart';
import '../../services/developer_auth_service.dart';
import 'developer_dashboard.dart';

class DeveloperLoginPage extends StatefulWidget {
  const DeveloperLoginPage({super.key});

  @override
  State<DeveloperLoginPage> createState() => _DeveloperLoginPageState();
}

class _DeveloperLoginPageState extends State<DeveloperLoginPage> {
  final _keyController = TextEditingController();
  final _authService = DeveloperAuthService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    // Check if already logged in
    final isAuthenticated = await _authService.isAuthenticated();
    if (isAuthenticated && mounted) {
      // Already logged in, go to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final masterKey = _keyController.text.trim();
      
      if (masterKey.isEmpty) {
        throw Exception("Master key gerekli");
      }

      final success = await _authService.login(masterKey);

      if (!mounted) return;

      if (success) {
        // Login successful, navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
        );
      } else {
        setState(() => _error = "Geçersiz master key veya erişim reddedildi");
      }

    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        
        // Parse specific error messages
        if (errorMsg.contains('429') || errorMsg.contains('Too many')) {
          errorMsg = "Çok fazla deneme. Lütfen bir dakika sonra tekrar deneyin.";
        } else if (errorMsg.contains('401') || errorMsg.contains('Invalid')) {
          errorMsg = "Geçersiz master key";
        } else if (errorMsg.contains('NetworkException') || errorMsg.contains('SocketException')) {
          errorMsg = "İnternet bağlantısı hatası";
        } else {
          errorMsg = "Giriş başarısız: ${errorMsg.replaceAll('Exception: ', '')}";
        }
        
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate 800
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.indigoAccent),
              const SizedBox(height: 24),
              const Text(
                "Geliştirici Girişi",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sistem yönetimi için master key giriniz",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _keyController,
                obscureText: true,
                enabled: !_isLoading,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: "MASTER KEY",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.indigoAccent),
                ),
                onSubmitted: (_) => _isLoading ? null : _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.indigoAccent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Giriş Yap", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
