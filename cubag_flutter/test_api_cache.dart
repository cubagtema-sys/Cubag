import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/api_service.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  
  final api = ApiService();
  await api.fetchDataWithCache('/announcements?page=1&limit=2', (data, isCached) {
    print('isCached: $isCached');
    print('data: $data');
  });
}
