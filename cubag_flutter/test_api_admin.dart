import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final res = await dio.get('https://cubag-backend.onrender.com/api/admin/dashboard', options: Options(validateStatus: (s) => true));
    print('Status: ${res.statusCode}');
    print('Data type: ${res.data.runtimeType}');
    print('Data: ${res.data}');
  } catch (e) {
    print('Error: $e');
  }
}
