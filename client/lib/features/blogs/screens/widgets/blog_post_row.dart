import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/blog.dart';

class BlogPostRow extends StatefulWidget {
  final Blog blog;
  final VoidCallback onTap;

  const BlogPostRow({
    super.key,
    required this.blog,
    required this.onTap,
  });

  @override
  State<BlogPostRow> createState() => _BlogPostRowState();
}

class _BlogPostRowState extends State<BlogPostRow> {
  bool _isHovered = false;

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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    final categoryColor = _getCategoryColor(widget.blog.category);
    const accentRed = Color(0xFFE8433D);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '— ${DateFormat('MMM dd, yyyy').format(widget.blog.createdAt)}',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 12 : 13,
            color: const Color(0xFF7A7A7A),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.blog.title,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 20 : 21,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: categoryColor,
            decoration: _isHovered ? TextDecoration.underline : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (widget.blog.doctorAvatarUrl != null)
              CircleAvatar(
                radius: isMobile ? 11 : 10,
                backgroundImage: CachedNetworkImageProvider(widget.blog.doctorAvatarUrl!),
              )
            else
              Icon(Icons.person, size: isMobile ? 18 : 16, color: const Color(0xFF7A7A7A)),
            const SizedBox(width: 8),
            Text(
              widget.blog.displayDoctorName,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFECECEC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.blog.content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: isMobile ? 14 : 15,
            height: 1.7,
            color: const Color(0xFF9A9A9A),
          ),
        ),
      ],
    );

    Widget thumbnail = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AspectRatio(
        aspectRatio: isMobile ? 16 / 9 : 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              AnimatedScale(
                scale: _isHovered ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: widget.blog.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.blog.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: const Color(0xFF1A1A1A)),
                        errorWidget: (context, url, error) => Container(color: const Color(0xFF1A1A1A)),
                      )
                    : Container(color: const Color(0xFF1A1A1A)),
              ),
              // Scrim
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              // Title Overlay
              Positioned(
                left: 16,
                bottom: 16,
                right: 22,
                child: Text(
                  widget.blog.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
              ),
              // Red Bar
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(color: accentRed),
              ),
            ],
          ),
        ),
      ),
    );

    return InkWell(
      onTap: widget.onTap,
      onHover: (hovering) => setState(() => _isHovered = hovering),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 24 : 32),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  thumbnail,
                  const SizedBox(height: 20),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 65, child: content),
                  const SizedBox(width: 32),
                  SizedBox(width: 300, child: thumbnail),
                ],
              ),
      ),
    );
  }
}
