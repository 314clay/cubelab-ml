import 'dart:convert';
import 'package:flutter/services.dart';

class JsonLoader {
  static Future<Map<String, dynamic>> loadJson(String path) async {
    final jsonString = await rootBundle.loadString('assets/$path');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> loadJsonList(String path) async {
    final jsonString = await rootBundle.loadString('assets/$path');
    return jsonDecode(jsonString) as List<dynamic>;
  }
}
