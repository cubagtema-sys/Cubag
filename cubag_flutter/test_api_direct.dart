import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    // Note: this is a public endpoint or we need a token?
    // Let's do a request to the backend. We don't have a token.
    // What does it return if no token? 401.
    final res = await dio.get('https://cubag-backend.onrender.com/api', options: Options(validateStatus: (s) => true));
    print('Status: ${res.statusCode}');
    print('Data type: ${res.data.runtimeType}');
    print('Data: ${res.data}');
  } catch (e) {
    print('Error: $e');
  }
}
