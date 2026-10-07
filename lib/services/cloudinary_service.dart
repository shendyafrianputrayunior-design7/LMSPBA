import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryService {
  // ===============================================================
  // CLOUDINARY CONFIG
  // ===============================================================

  static const String cloudName = 'atcen2yy';
  static const String uploadPreset = 'elearn_profile';

  // ===============================================================
  // UPLOAD PROFILE IMAGE
  // ===============================================================

  static Future<String?> uploadProfileImage(
      File imageFile,
      ) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final response = await request.send();

      final responseBody =
      await response.stream.bytesToString();

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = jsonDecode(responseBody);

        return data['secure_url'] as String?;
      }

      print('========================================');
      print('CLOUDINARY PROFILE UPLOAD ERROR');
      print('Status: ${response.statusCode}');
      print('Response: $responseBody');
      print('========================================');

      return null;
    } catch (e) {
      print('Cloudinary profile error: $e');
      return null;
    }
  }

  // ===============================================================
  // UPLOAD ASSIGNMENT FILE
  // ===============================================================

  static Future<String?> uploadAssignmentFile(
      File file,
      ) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      final response = await request.send();

      final responseBody =
      await response.stream.bytesToString();

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = jsonDecode(responseBody);

        return data['secure_url'] as String?;
      }

      print('========================================');
      print('CLOUDINARY ASSIGNMENT UPLOAD ERROR');
      print('Status: ${response.statusCode}');
      print('Response: $responseBody');
      print('========================================');

      return null;
    } catch (e) {
      print('Cloudinary assignment error: $e');
      return null;
    }
  }

  // ===============================================================
  // UPLOAD LESSON VIDEO
  // ===============================================================

  static Future<String?> uploadLessonVideo(
      File videoFile,
      ) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
        ),
      );

      final response = await request.send();

      final responseBody =
      await response.stream.bytesToString();

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = jsonDecode(responseBody);

        return data['secure_url'] as String?;
      }

      print('========================================');
      print('CLOUDINARY VIDEO UPLOAD ERROR');
      print('Status: ${response.statusCode}');
      print('Response: $responseBody');
      print('========================================');

      return null;
    } catch (e) {
      print('Cloudinary lesson video error: $e');
      return null;
    }
  }
}