import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/blog_post_row.dart';

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

    const bgColor = Color(0xFF0D0D0D);
    const accentRed = Color(0xFFE8433D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(allBlogsProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFECECEC),
                                letterSpacing: 0.5,
                              ),
                              children: [
                                const TextSpan(text: 'Blog '),
                                TextSpan(
                                  text: '/ Literature',
                                  style: GoogleFonts.poppins(color: accentRed),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _FilterButton(isDoctor: isDoctor),
                              if (isDoctor)
                                IconButton(
                                  onPressed: () => context.push('/blogs/new'),
                                  icon: const Icon(Icons.add, color: Colors.white),
                                ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentRed,
                              Color(0xFF4A1A18),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              blogsAsync.when(
                data: (blogs) {
                  if (blogs.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No blogs found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final blog = blogs[index];
                          final isLast = index == blogs.length - 1;
                          return Column(
                            children: [
                              BlogPostRow(
                                blog: blog,
                                onTap: () => context.push('/blogs/${blog.id}'),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFF272727),
                                ),
                            ],
                          );
                        },
                        childCount: blogs.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isDoctor
          ? FloatingActionButton(
              heroTag: 'blog_list_fab',
              onPressed: () => context.push('/blogs/new'),
              backgroundColor: accentRed,
              child: const Icon(Icons.add, color: Colors.white),
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
      icon: const Icon(Icons.filter_list, color: Colors.white70),
      color: const Color(0xFF151515),
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
                  if (!onlyMyBlogs) const Icon(Icons.check, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('All Blogs', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_blogs',
              child: Row(
                children: [
                  if (onlyMyBlogs) const Icon(Icons.check, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('My Blogs', style: TextStyle(color: Colors.white)),
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
                  if (!onlyMyDoctors) const Icon(Icons.check, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('All Blogs', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_doctors',
              child: Row(
                children: [
                  if (onlyMyDoctors) const Icon(Icons.check, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text("My Doctors' Blogs", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ];
        }
      },
    );
  }
}
