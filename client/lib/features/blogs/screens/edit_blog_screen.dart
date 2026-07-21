import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/blog_provider.dart';

class EditBlogScreen extends ConsumerStatefulWidget {
  final String? blogId;

  const EditBlogScreen({super.key, this.blogId});

  @override
  ConsumerState<EditBlogScreen> createState() => _EditBlogScreenState();
}

enum _SaveStage { none, processing, saving }

class _EditBlogScreenState extends ConsumerState<EditBlogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'General';
  String? _thumbnailUrl;
  XFile? _imageFile;
  Uint8List? _webImageBytes;
  bool _isInitialized = false;
  _SaveStage _saveStage = _SaveStage.none;
  bool _isCanceled = false;

  final List<String> _categories = ['General', 'Earth', 'Mind', 'Literature', 'Medical'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && widget.blogId != null) {
      final blogsAsync = ref.watch(allBlogsProvider);
      blogsAsync.whenData((blogs) {
        final blog = blogs.firstWhere((b) => b.id == widget.blogId);
        _titleController.text = blog.title;
        _contentController.text = blog.content;
        _category = blog.category;
        _thumbnailUrl = blog.thumbnailUrl;
        setState(() => _isInitialized = true);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.bytes != null) {
          setState(() {
            _webImageBytes = result.files.single.bytes;
            _imageFile = XFile.fromData(_webImageBytes!, name: result.files.single.name);
          });
        }
      } else {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() => _imageFile = image);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saveStage = _SaveStage.processing;
      _isCanceled = false;
    });

    try {
      final actions = ref.read(blogActionsProvider);
      String? uploadedUrl = _thumbnailUrl;

      if (_imageFile != null) {
        debugPrint('EditBlogScreen: Starting image processing...');

        // Phase 1: Compression (Processing)
        // If it's a large image, this takes a moment.
        if (_isCanceled) return;

        if (kIsWeb && _webImageBytes != null) {
          // On Web, we already have bytes, but we might still want to compress
          // But for immediate feedback, let's move to "Saving" once upload starts
        }

        // Transition to Saving phase
        if (_isCanceled) return;
        setState(() => _saveStage = _SaveStage.saving);

        if (kIsWeb && _webImageBytes != null) {
          uploadedUrl = await actions.uploadThumbnailBytes(_webImageBytes!, _imageFile!.name);
        } else if (!kIsWeb) {
          uploadedUrl = await actions.uploadThumbnail(File(_imageFile!.path));
        }
        debugPrint('EditBlogScreen: Image upload finished. URL: $uploadedUrl');
      } else {
        // No image, just saving the text
        setState(() => _saveStage = _SaveStage.saving);
      }

      if (_isCanceled) return;

      if (uploadedUrl == null && _imageFile != null) {
        throw Exception('Failed to upload thumbnail. Please check your storage permissions.');
      }

      debugPrint('EditBlogScreen: Saving blog record...');
      if (widget.blogId == null) {
        await actions.createBlog(
          title: _titleController.text,
          content: _contentController.text,
          category: _category,
          thumbnailUrl: uploadedUrl,
        );
      } else {
        await actions.updateBlog(
          id: widget.blogId!,
          title: _titleController.text,
          content: _contentController.text,
          category: _category,
          thumbnailUrl: uploadedUrl,
        );
      }
      debugPrint('EditBlogScreen: Blog saved successfully.');
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('EditBlogScreen: Error saving blog: $e');
      if (mounted && !_isCanceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving blog: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saveStage = _SaveStage.none);
    }
  }

  void _onCancel() {
    setState(() {
      _isCanceled = true;
      _saveStage = _SaveStage.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(widget.blogId == null ? 'Create Blog' : 'Edit Blog'),
            actions: [
              TextButton(
                onPressed: _saveStage == _SaveStage.none ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: _saveStage == _SaveStage.none ? _pickImage : null,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF272727)),
                      image: _imageFile != null
                          ? (kIsWeb
                              ? (_webImageBytes != null
                                  ? DecorationImage(image: MemoryImage(_webImageBytes!), fit: BoxFit.cover)
                                  : null)
                              : DecorationImage(image: FileImage(File(_imageFile!.path)), fit: BoxFit.cover))
                          : (_thumbnailUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(_thumbnailUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: _imageFile == null && _thumbnailUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Pick Thumbnail', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: const Color(0xFF151515),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: _saveStage == _SaveStage.none
                      ? (value) {
                          if (value != null) setState(() => _category = value);
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  enabled: _saveStage == _SaveStage.none,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter a catchy title',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  maxLength: 200,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a title';
                    if (value.length < 5) return 'Title must be at least 5 characters long';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  enabled: _saveStage == _SaveStage.none,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    hintText: 'Share your medical knowledge...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 10,
                  maxLength: 10000,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter content';
                    if (value.length < 20) return 'Content must be at least 20 characters long';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        if (_saveStage != _SaveStage.none)
          _LoadingOverlay(
            stage: _saveStage,
            onCancel: _saveStage == _SaveStage.processing ? _onCancel : null,
          ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  final _SaveStage stage;
  final VoidCallback? onCancel;

  const _LoadingOverlay({required this.stage, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final title = stage == _SaveStage.processing ? 'Processing Image...' : 'Saving Blog...';
    final subtitle = stage == _SaveStage.processing
        ? 'Optimizing and compressing thumbnail'
        : 'Uploading and updating records';

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFE8433D)),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
