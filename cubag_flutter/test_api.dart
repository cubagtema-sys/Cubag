import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://cubag-backend.onrender.com/api',
  ));
  
  try {
    final res = await _dio.get('/announcements?page=1&limit=20');
    print(res.data.runtimeType);
    print(res.data);
  } catch (e) {
    print(e);
  }
}
