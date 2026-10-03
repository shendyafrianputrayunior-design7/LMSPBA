import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudinaryService {
  // GANTI dengan Cloud Name milik kamu
  static const String cloudName = 'atcen2yy';

  // GANTI dengan nama Upload Preset milik kamu
  static const String uploadPreset = 'elearn_profile';

  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(responseBody);

        return data['secure_url'] as String?;
      }

      print('Cloudinary upload gagal:');
      print(response.statusCode);
      print(responseBody);

      return null;
    } catch (e) {
      print('Cloudinary error: $e');
      return null;
    }
  }
}