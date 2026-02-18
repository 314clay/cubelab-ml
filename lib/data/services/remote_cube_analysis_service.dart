import 'dart:convert';
import 'dart:typed_data';

import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';
import 'package:http/http.dart' as http;

/// Remote implementation that sends photos to a Python pipeline server
/// running ResNet-18 sticker classification and solver tree.
class RemoteCubeAnalysisService implements CubeAnalysisService {
  final String baseUrl;
  final http.Client _client;

  RemoteCubeAnalysisService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<CubeScanResult> analyze(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/analyze');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'cube.jpg',
      ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Analysis failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CubeScanResult.fromJson(json);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
