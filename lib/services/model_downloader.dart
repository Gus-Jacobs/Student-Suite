import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloader {
  static final Dio _dio = Dio();

  static Future<File> downloadModel({
    required String url,
    required String filename,
    required void Function(double progress) onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/$filename');

    if (await modelFile.exists()) {
      onProgress(1.0);
      return modelFile;
    }

    try {
      await _dio.download(
        url,
        modelFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );
      return modelFile;
    } catch (e) {
      // If download fails, delete the partial file
      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      throw Exception('Failed to download model: $e');
    }
  }
}
