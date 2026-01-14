import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Service for managing developer panel authentication with session tokens
/// Uses FlutterSecureStorage for secure token persistence
class DeveloperAuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'developer_session_token';
  static const _expiryKey = 'developer_session_expiry';
  
  static const _baseUrl = 'https://us-central1-truck-dispatch-system.cloudfunctions.net';
  
  /// Login with master key and get session token
  /// Returns true if login successful, false otherwise
  Future<bool> login(String masterKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/developerLogin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'masterKey': masterKey}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // Store token and expiry in secure storage
          await _storage.write(key: _tokenKey, value: data['token']);
          await _storage.write(
            key: _expiryKey,
            value: data['expiresAt'].toString(),
          );
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
  
  /// Get the current session token if it's valid
  /// Returns null if no token or token is expired
  Future<String?> getSessionToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final expiryStr = await _storage.read(key: _expiryKey);
      
      if (token == null || expiryStr == null) {
        return null;
      }
      
      // Check if token is expired
      final expiry = int.parse(expiryStr);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now >= expiry) {
        // Token expired, clean up
        await logout();
        return null;
      }
      
      return token;
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getSessionToken();
    return token != null;
  }
  
  /// Logout: Delete token from storage and server
  Future<void> logout() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      
      if (token != null) {
        // Notify server to delete session
        await http.post(
          Uri.parse('$_baseUrl/developerLogout'),
          headers: {'x-session-token': token},
        );
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      // Always clean up local storage
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiryKey);
    }
  }
  
  /// Make authenticated GET request
  /// Returns response or throws exception
  Future<http.Response> makeGetRequest(String endpoint) async {
    final token = await getSessionToken();
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    final response = await http.get(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: {'x-session-token': token},
    );
    
    // Check for auth errors
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Session expired or invalid, clean up
      await logout();
      throw Exception('Session expired');
    }
    
    return response;
  }
  
  /// Make authenticated POST request
  /// Returns response or throws exception
  Future<http.Response> makePostRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await getSessionToken();
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'x-session-token': token,
      },
      body: jsonEncode(body),
    );
    
    // Check for auth errors
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Session expired or invalid, clean up
      await logout();
      throw Exception('Session expired');
    }
    
    return response;
  }
  
  /// Make authenticated GET request with query parameters
  Future<http.Response> makeGetRequestWithQuery(
    String endpoint,
    Map<String, String> queryParams,
  ) async {
    final token = await getSessionToken();
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    final uri = Uri.parse('$_baseUrl/$endpoint').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(
      uri,
      headers: {'x-session-token': token},
    );
    
    // Check for auth errors
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Session expired or invalid, clean up
      await logout();
      throw Exception('Session expired');
    }
    
    return response;
  }
  
  /// Get error message from response
  String getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] ?? 'Unknown error';
    } catch (e) {
      return 'Failed to parse error message';
    }
  }
}
