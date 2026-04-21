import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  const SupabaseStorageService();

  Future<String?> uploadMedia({
    required File file,
    required String folderPath,
    required String fileName,
  }) async {
    final fullPath = '$folderPath/$fileName';

    try {
      await Supabase.instance.client.storage
          .from('mezaan_media')
          .upload(fullPath, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('mezaan_media')
          .getPublicUrl(fullPath);

      return publicUrl;
    } catch (error) {
      print('Supabase uploadMedia error: $error');
      return null;
    }
  }
}

// Quick example during user registration:
// final uid = FirebaseAuth.instance.currentUser!.uid;
// final storageService = const SupabaseStorageService();
// final idFrontUrl = await storageService.uploadMedia(
//   file: File(frontIdImage.path),
//   folderPath: 'users/$uid',
//   fileName: 'id_front.jpg',
// );
