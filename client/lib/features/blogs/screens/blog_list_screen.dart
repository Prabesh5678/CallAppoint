import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/centered_constrained_box.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/blog_post_row.dart';

import '../../../../core/theme_provider.dart';

class BlogListScreen extends ConsumerWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogsAsync = ref.watch(filteredBlogsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final themeMode = ref.watch(themeModeProvider);

    final isDoctor = userProfileAsync.maybeWhen(
      data: (profile) => profile['role'] == 'doctor',
      orElse: () => false,
    );

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    final bgColor = theme.scaffoldBackgroundColor;
    final accentRed = theme.colorScheme.primary; // Using primary color from theme
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(allBlogsProvider),
          child: CenteredConstrainedBox(
            maxWidth: 1000,
            child: CustomScrollView(
              slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMobile ? 32 : 56,
                    horizontalPadding,
                    isMobile ? 24 : 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 28 : 36,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
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
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  themeMode == ThemeMode.dark
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                  color: textColor.withOpacity(0.7),
                                ),
                                onPressed: () =>
                                    ref.read(themeModeProvider.notifier).toggle(),
                              ),
                              _FilterButton(isDoctor: isDoctor),
                              if (isDoctor)
                                IconButton(
                                  onPressed: () => context.push('/blogs/new'),
                                  icon: Icon(Icons.add, color: textColor),
                                ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentRed,
                              accentRed.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
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
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No blogs found',
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: theme.dividerColor,
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
                      style: TextStyle(color: subTextColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list, color: textColor.withOpacity(0.7)),
      color: theme.cardColor,
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
                  if (!onlyMyBlogs) Icon(Icons.check, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Text('All Blogs', style: TextStyle(color: textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_blogs',
              child: Row(
                children: [
                  if (onlyMyBlogs) Icon(Icons.check, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Text('My Blogs', style: TextStyle(color: textColor)),
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
                  if (!onlyMyDoctors) Icon(Icons.check, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Text('All Blogs', style: TextStyle(color: textColor)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'my_doctors',
              child: Row(
                children: [
                  if (onlyMyDoctors) Icon(Icons.check, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Text("My Doctors' Blogs", style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ];
        }
      },
    );
  }
}
