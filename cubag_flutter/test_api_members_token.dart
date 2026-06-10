import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    // 1. Login to get token
    final loginRes = await dio.post('https://cubag-backend.onrender.com/api/auth/login', data: {
      'email': 'admin@cubag.com',
      'password': 'adminpassword123'
    }, options: Options(validateStatus: (s) => true));
    
    if (loginRes.statusCode != 200) {
      print('Login failed: ${loginRes.data}');
      return;
    }
    
    final token = loginRes.data['token'];
    
    // 2. Fetch members
    final res = await dio.get('https://cubag-backend.onrender.com/api/members/admin/all?page=1&limit=20', options: Options(
      validateStatus: (s) => true,
      headers: {'Authorization': 'Bearer $token'}
    ));
    print('Members Status: ${res.statusCode}');
    print('Members Data Type: ${res.data.runtimeType}');
    if (res.data is Map) {
      print('Members Keys: ${res.data.keys}');
      print('Total members: ${res.data['total']}');
      final dataList = res.data['data'] as List?;
      print('Data list length: ${dataList?.length}');
      if (dataList != null && dataList.isNotEmpty) {
        print('First member status: ${dataList[0]['status']}');
      }
    } else {
      print('Data: ${res.data}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
