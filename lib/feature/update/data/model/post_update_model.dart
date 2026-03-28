import 'dart:io';

class PostDraftModel {
  final String description;
  final List<File> imageFiles;

  const PostDraftModel({
    required this.description,
    this.imageFiles = const <File>[],
  });

  PostDraftModel copyWith({String? description, List<File>? imageFiles}) {
    return PostDraftModel(
      description: description ?? this.description,
      imageFiles: imageFiles ?? this.imageFiles,
    );
  }

  bool get canPost => description.trim().isNotEmpty;
}
