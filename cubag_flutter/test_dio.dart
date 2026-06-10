import 'package:dio/dio.dart';

void main() {
  final dio = Dio();
  final t = dio.transformer;
  print(t.runtimeType);
}
