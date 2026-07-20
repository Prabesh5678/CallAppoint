import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blog.dart';
import '../../../core/dio_client.dart';

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

  /// Locally update the state for optimistic UI
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

  /// Optimistic delete with Undo functionality
  Future<void> deleteBlogWithUndo({
    required String id,
    required void Function(Future<void> Function() onUndo, void Function() onTimeout) showUndoSnackBar,
  }) async {
    final previousState = ref.read(allBlogsProvider).valueOrNull;
    if (previousState == null) return;

    // 1. Remove from frontend immediately
    final updatedList = previousState.where((b) => b.id != id).toList();
    ref.read(allBlogsProvider.notifier).setBlogs(updatedList);

    bool wasUndone = false;
    final userActionCompleter = Completer<void>();

    // 2. Show the SnackBar
    showUndoSnackBar(
      // onUndo callback
      () async {
        if (userActionCompleter.isCompleted) return;
        wasUndone = true;
        ref.read(allBlogsProvider.notifier).setBlogs(previousState);
        userActionCompleter.complete();
      },
      // onTimeout/onDismiss callback
      () {
        if (!userActionCompleter.isCompleted) {
          userActionCompleter.complete();
        }
      },
    );

    // 3. Independent Timer to ensure backend request fires even if UI fails to notify
    final timer = Timer(const Duration(milliseconds: 4500), () {
      if (!userActionCompleter.isCompleted) {
        userActionCompleter.complete();
      }
    });

    await userActionCompleter.future;
    timer.cancel();

    // 4. If not undone, fire request to backend
    if (!wasUndone) {
      try {
        await DioClient.instance.delete('/blogs/$id/');
      } catch (e) {
        // If backend fails, restore and show error
        ref.read(allBlogsProvider.notifier).setBlogs(previousState);
        rethrow;
      }
    }
  }
}

final blogActionsProvider = Provider((ref) => BlogActions(ref));
