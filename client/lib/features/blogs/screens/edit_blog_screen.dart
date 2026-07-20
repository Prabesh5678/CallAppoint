import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/blog_provider.dart';

class EditBlogScreen extends ConsumerStatefulWidget {
  final String? blogId;

  const EditBlogScreen({super.key, this.blogId});

  @override
  ConsumerState<EditBlogScreen> createState() => _EditBlogScreenState();
}

class _EditBlogScreenState extends ConsumerState<EditBlogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && widget.blogId != null) {
      final blogsAsync = ref.watch(allBlogsProvider);
      blogsAsync.whenData((blogs) {
        final blog = blogs.firstWhere((b) => b.id == widget.blogId);
        _titleController.text = blog.title;
        _contentController.text = blog.content;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final actions = ref.read(blogActionsProvider);
      if (widget.blogId == null) {
        await actions.createBlog(_titleController.text, _contentController.text);
      } else {
        await actions.updateBlog(
          widget.blogId!,
          _titleController.text,
          _contentController.text,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving blog: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.blogId == null ? 'Create Blog' : 'Edit Blog'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter a catchy title',
                border: OutlineInputBorder(),
                counterText: '', // Hide default counter
              ),
              maxLength: 200,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a title';
                if (value.length < 5) return 'Title must be at least 5 characters long';
                if (value.length > 200) return 'Title cannot exceed 200 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Share your medical knowledge...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              maxLength: 10000,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter content';
                if (value.length < 20) return 'Content must be at least 20 characters long';
                if (value.length > 10000) return 'Content cannot exceed 10000 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
