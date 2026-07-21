import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/blog.dart';
import '../../../core/dio_client.dart';
import '../../../core/undo_manager.dart';
import '../../../core/supabase_client.dart';

// Filter states
final blogSearchQueryProvider = StateProvider<String>((ref) => '');
final showOnlyMyDoctorsBlogsProvider = StateProvider<bool>((ref) => false);
final showOnlyMyOwnBlogsProvider = StateProvider<bool>((ref) => false);

class BlogsNotifier extends AutoDisposeAsyncNotifier<List<Blog>> {
  @override
  FutureOr<List<Blog>> build() async {
    final searchQuery = ref.watch(blogSearchQueryProvider);
    final showOnlyMyDoctors = ref.watch(showOnlyMyDoctorsBlogsProvider);
    final showOnlyMyOwn = ref.watch(showOnlyMyOwnBlogsProvider);

    final Map<String, dynamic> queryParams = {};
    if (searchQuery.isNotEmpty) queryParams['search'] = searchQuery;
    if (showOnlyMyDoctors) queryParams['my_doctors'] = 'true';
    if (showOnlyMyOwn) queryParams['my_blogs'] = 'true';

    final response = await DioClient.instance.get(
      '/blogs/',
      queryParameters: queryParams,
    );

    final list = response.data as List;
    return list.map((json) => Blog.fromJson(json)).toList();
  }

  void setBlogs(List<Blog> blogs) {
    state = AsyncData(blogs);
  }
}

final allBlogsProvider = AsyncNotifierProvider.autoDispose<BlogsNotifier, List<Blog>>(
  () => BlogsNotifier(),
);

final filteredBlogsProvider = Provider.autoDispose<AsyncValue<List<Blog>>>((ref) {
  return ref.watch(allBlogsProvider);
});

class BlogActions {
  final Ref ref;
  BlogActions(this.ref);

  Future<void> createBlog({
    required String title,
    required String content,
    String? category,
    String? thumbnailUrl,
  }) async {
    await DioClient.instance.post(
      '/blogs/',
      data: {
        'title': title,
        'content': content,
        'category': category ?? 'General',
        'thumbnail_url': thumbnailUrl,
      },
    );
    ref.invalidate(allBlogsProvider);
  }

  Future<void> updateBlog({
    required String id,
    required String title,
    required String content,
    String? category,
    String? thumbnailUrl,
  }) async {
    await DioClient.instance.put(
      '/blogs/$id/',
      data: {
        'title': title,
        'content': content,
        'category': category ?? 'General',
        'thumbnail_url': thumbnailUrl,
      },
    );
    ref.invalidate(allBlogsProvider);
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    // Wrap in compute to run in a separate isolate on mobile/desktop
    // On Web, compute still runs on the main thread but helps with organization
    return await compute(_processImage, bytes);
  }

  static Uint8List? _processImage(Uint8List bytes) {
    try {
      // Use a fast decoder
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Shrink even more for better performance
      img.Image resized = image;
      if (image.width > 800 || image.height > 800) {
        resized = img.copyResize(image, width: 800, interpolation: img.Interpolation.average);
      }

      return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes;
    }
  }

  static const String _bucketName = 'blog';

  Future<String?> uploadThumbnail(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from(_bucketName).uploadBinary(
            fileName,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '3600'),
          ).timeout(const Duration(seconds: 20), onTimeout: () {
            throw TimeoutException('Image upload timed out. Please check your internet connection.');
          });

      final url = supabase.storage.from(_bucketName).getPublicUrl(fileName);
      debugPrint('BlogActions: Generated public URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> uploadThumbnailBytes(Uint8List bytes, String name) async {
    try {
      final compressedBytes = await _compressImage(bytes);
      if (compressedBytes == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from(_bucketName).uploadBinary(
            fileName,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '3600'),
          ).timeout(const Duration(seconds: 20), onTimeout: () {
            throw TimeoutException('Image upload timed out. Please check your internet connection.');
          });

      final url = supabase.storage.from(_bucketName).getPublicUrl(fileName);
      debugPrint('BlogActions: Generated public URL (bytes): $url');
      return url;
    } catch (e) {
      debugPrint('Error uploading image bytes: $e');
      return null;
    }
  }

  Future<void> deleteBlogWithUndo(String id) async {
    final previousState = ref.read(allBlogsProvider).valueOrNull;
    if (previousState == null) return;

    final updatedList = previousState.where((b) => b.id != id).toList();
    ref.read(allBlogsProvider.notifier).setBlogs(updatedList);

    final result = await UndoManager.showUndoSnackBar(
      message: 'Blog deleted',
      onUndo: () => ref.read(allBlogsProvider.notifier).setBlogs(previousState),
    );

    if (!result.wasUndone) {
      try {
        await DioClient.instance.delete('/blogs/$id/');
      } catch (e) {
        ref.read(allBlogsProvider.notifier).setBlogs(previousState);
        rethrow;
      }
    }
  }
}

final blogActionsProvider = Provider((ref) => BlogActions(ref));
