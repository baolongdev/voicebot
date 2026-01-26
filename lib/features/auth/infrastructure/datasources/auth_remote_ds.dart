import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/login_response_dto.dart';
import '../models/user_dto.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  });

  Future<UserDto> getProfile({
    required String accessToken,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  final http.Client client;
  final String baseUrl;

  @override
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await client.post(
      uri,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw AuthApiException(statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponseDto.fromJson(data);
  }

  @override
  Future<UserDto> getProfile({required String accessToken}) async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final response = await client.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw AuthApiException(statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return UserDto.fromJson(data);
  }
}

class AuthApiException implements Exception {
  AuthApiException({required this.statusCode});

  final int statusCode;
}
