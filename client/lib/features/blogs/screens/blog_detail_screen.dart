import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/time_utils.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/blog.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String blogId;

  const BlogDetailScreen({super.key, required this.blogId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Blog'),
        content: const Text('Are you sure you want to delete this blog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      context.pop(); // Return to list immediately

      try {
        await ref.read(blogActionsProvider).deleteBlogWithUndo(
          id: blogId,
          showUndoSnackBar: (onUndo, dismiss) {
            messenger.clearSnackBars();
            final snackBar = SnackBar(
              content: const Text('Blog deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: onUndo,
              ),
              duration: const Duration(seconds: 4),
            );

            messenger.showSnackBar(snackBar).closed.then((reason) {
              // If it closed because of time or swipe, and NOT because of the undo button
              if (reason != SnackBarClosedReason.action) {
                dismiss();
              }
            });
          },
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogsAsync = ref.watch(allBlogsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final myId = userProfileAsync.maybeWhen(
      data: (profile) => profile['id'] as String?,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Details'),
        actions: [
          blogsAsync.maybeWhen(
            data: (blogs) {
              final blog = blogs.where((b) => b.id == blogId).firstOrNull;
              if (blog != null && blog.doctorId == myId) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Blog',
                      onPressed: () => context.push('/blogs/$blogId/edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Blog',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: blogsAsync.when(
        data: (blogs) {
          final blog = blogs.where((b) => b.id == blogId).firstOrNull;
          if (blog == null) {
            return const Center(child: Text('Blog no longer exists'));
          }
          return _BlogContent(blog: blog);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _BlogContent extends StatelessWidget {
  final Blog blog;

  const _BlogContent({required this.blog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            blog.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: blog.doctorAvatarUrl != null
                    ? NetworkImage(blog.doctorAvatarUrl!)
                    : null,
                child: blog.doctorAvatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blog.doctorName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    TimeUtils.timeAgo(blog.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            blog.content,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
