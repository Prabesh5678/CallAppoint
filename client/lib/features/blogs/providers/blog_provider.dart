import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blog.dart';
import '../../../core/dio_client.dart';
import '../../../core/undo_manager.dart';

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

  Future<void> createBlog(String title, String content) async {
    await DioClient.instance.post(
      '/blogs/',
      data: {'title': title, 'content': content},
    );
    ref.invalidate(allBlogsProvider);
  }

  Future<void> updateBlog(String id, String title, String content) async {
    await DioClient.instance.put(
      '/blogs/$id/',
      data: {'title': title, 'content': content},
    );
    ref.invalidate(allBlogsProvider);
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
