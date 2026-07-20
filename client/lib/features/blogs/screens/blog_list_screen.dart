import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/blog_card.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogsAsync = ref.watch(filteredBlogsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final isDoctor = userProfileAsync.maybeWhen(
      data: (profile) => profile['role'] == 'doctor',
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Blogs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search blogs...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) =>
                        ref.read(blogSearchQueryProvider.notifier).state = value,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(isDoctor: isDoctor),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(allBlogsProvider),
        child: blogsAsync.when(
          data: (blogs) {
            if (blogs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No blogs found')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: blogs.length,
              itemBuilder: (context, index) {
                final blog = blogs[index];
                return BlogCard(
                  blog: blog,
                  onTap: () => context.push('/blogs/${blog.id}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(child: Text('Error: $e')),
            ],
          ),
        ),
      ),
      floatingActionButton: isDoctor
          ? FloatingActionButton(
              onPressed: () => context.push('/blogs/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _FilterButton extends ConsumerWidget {
  final bool isDoctor;

  const _FilterButton({required this.isDoctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      onSelected: (value) {
        if (isDoctor) {
          ref.read(showOnlyMyOwnBlogsProvider.notifier).state =
              value == 'my_blogs';
        } else {
          ref.read(showOnlyMyDoctorsBlogsProvider.notifier).state =
              value == 'my_doctors';
        }
      },
      itemBuilder: (context) {
        if (isDoctor) {
          final onlyMyBlogs = ref.watch(showOnlyMyOwnBlogsProvider);
          return [
            PopupMenuItem(
              value: 'all',
              child: Row(
                children: [
                  if (!onlyMyBlogs) const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  const Text('All Blogs'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_blogs',
              child: Row(
                children: [
                  if (onlyMyBlogs) const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  const Text('My Blogs'),
                ],
              ),
            ),
          ];
        } else {
          final onlyMyDoctors = ref.watch(showOnlyMyDoctorsBlogsProvider);
          return [
            PopupMenuItem(
              value: 'all',
              child: Row(
                children: [
                  if (!onlyMyDoctors) const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  const Text('All Blogs'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_doctors',
              child: Row(
                children: [
                  if (onlyMyDoctors) const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  const Text("My Doctors' Blogs"),
                ],
              ),
            ),
          ];
        }
      },
    );
  }
}
