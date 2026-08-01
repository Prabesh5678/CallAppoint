import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/centered_constrained_box.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';

import '../../../../core/theme_provider.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String blogId;

  const BlogDetailScreen({super.key, required this.blogId});

  Color _getCategoryColor(String category, ThemeData theme) {
    switch (category.toLowerCase()) {
      case 'earth':
        return const Color(0xFFFF6B47);
      case 'mind':
        return const Color(0xFF45C4D6);
      default:
        return theme.colorScheme.onSurface.withOpacity(0.8);
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    final transformationController = TransformationController();

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: transformationController,
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
              // Close Button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Zoom Controls
              Positioned(
                bottom: 40,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        final currentScale = transformationController.value.getMaxScaleOnAxis();
                        transformationController.value = Matrix4.identity()..scale(currentScale * 1.2);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () {
                        final currentScale = transformationController.value.getMaxScaleOnAxis();
                        transformationController.value = Matrix4.identity()..scale(currentScale / 1.2);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'zoom_reset',
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        transformationController.value = Matrix4.identity();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete Blog', style: GoogleFonts.poppins(color: theme.colorScheme.onSurface)),
        content: Text('Are you sure you want to delete this blog?', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        context.pop();
        await ref.read(blogActionsProvider).deleteBlogWithUndo(blogId);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    final blogsAsync = ref.watch(allBlogsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final myId = userProfileAsync.maybeWhen(
      data: (profile) => profile['id'] as String?,
      orElse: () => null,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    final bgColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.cardColor;
    final accentRed = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: blogsAsync.when(
        data: (blogs) {
          final blog = blogs.where((b) => b.id == blogId).firstOrNull;
          if (blog == null) {
            return Center(
                child: Text('Blog no longer exists',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7))));
          }

          final categoryColor = _getCategoryColor(blog.category, theme);

          return CenteredConstrainedBox(
            maxWidth: 1000,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: isMobile ? 240 : 350,
                  pinned: true,
                  backgroundColor: bgColor,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: () {
                        if (blog.thumbnailUrl != null) {
                          _showFullImage(context, blog.thumbnailUrl!);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (blog.thumbnailUrl != null)
                            CachedNetworkImage(
                              imageUrl: blog.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: surfaceColor),
                              errorWidget: (context, url, error) =>
                                  Container(color: surfaceColor),
                            )
                          else
                            Container(color: surfaceColor),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, bgColor],
                              ),
                            ),
                          ),
                          // Tip for the user
                          if (blog.thumbnailUrl != null)
                            const Positioned(
                              bottom: 40,
                              right: 16,
                              child: Icon(Icons.fullscreen,
                                  color: Colors.white70, size: 24),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () =>
                            ref.read(themeModeProvider.notifier).toggle(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (blog.doctorId == myId) ...[
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          onPressed: () => context.push('/blogs/$blogId/edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDelete(context, ref),
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 16),
                    ],
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isMobile ? 24 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '— ${DateFormat('MMM dd, yyyy').format(blog.createdAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          blog.title,
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 24 : 28,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 2,
                          width: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentRed, Colors.transparent],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: blog.doctorAvatarUrl != null
                                  ? NetworkImage(blog.doctorAvatarUrl!)
                                  : null,
                              child: blog.doctorAvatarUrl == null
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'By ${blog.displayDoctorName}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          blog.content,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 16 : 17,
                            height: 1.8,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7)))),
      ),
    );
  }
}
