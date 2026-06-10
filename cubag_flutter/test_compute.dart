import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() async {
  try {
    final str = await compute(jsonEncode, {"a": 1});
    print(str);
  } catch (e) {
    print("Error: $e");
  }
}
