import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/blog_provider.dart';
import '../../auth/providers/auth_provider.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String blogId;

  const BlogDetailScreen({super.key, required this.blogId});

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'earth':
        return const Color(0xFFFF6B47);
      case 'mind':
        return const Color(0xFF45C4D6);
      default:
        return const Color(0xFFECECEC);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: Text('Delete Blog', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Are you sure you want to delete this blog?', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
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
    final blogsAsync = ref.watch(allBlogsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final myId = userProfileAsync.maybeWhen(
      data: (profile) => profile['id'] as String?,
      orElse: () => null,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    const bgColor = Color(0xFF0D0D0D);
    const surfaceColor = Color(0xFF151515);
    const accentRed = Color(0xFFE8433D);

    return Scaffold(
      backgroundColor: bgColor,
      body: blogsAsync.when(
        data: (blogs) {
          final blog = blogs.where((b) => b.id == blogId).firstOrNull;
          if (blog == null) {
            return const Center(child: Text('Blog no longer exists', style: TextStyle(color: Colors.white70)));
          }

          final categoryColor = _getCategoryColor(blog.category);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: isMobile ? 240 : 300,
                pinned: true,
                backgroundColor: bgColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (blog.thumbnailUrl != null)
                        CachedNetworkImage(
                          imageUrl: blog.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: surfaceColor),
                          errorWidget: (context, url, error) => Container(color: surfaceColor),
                        )
                      else
                        Container(color: surfaceColor),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, bgColor],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (blog.doctorId == myId) ...[
                    CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        onPressed: () => context.push('/blogs/$blogId/edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFE8433D), size: 20),
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 16),
                  ],
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isMobile ? 24 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '— ${DateFormat('MMM dd, yyyy').format(blog.createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF7A7A7A),
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
                        decoration: const BoxDecoration(
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
                              color: const Color(0xFFECECEC),
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
                          color: const Color(0xFF9A9A9A),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
      ),
    );
  }
}
