import 'dart:io';

enum PhotoSource { camera, gallery }

abstract class PostRepository {
  Future<List<File>> pickImages(PhotoSource source);

  Future<void> createPost({
    required String projectId,
    required String description,
    required List<File> imageFiles,
  });
}
