import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const ChatScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loadedHistory = false;
  bool _isUploading = false;
  PlatformFile? _selectedFile;

  void _send() {
    if (_selectedFile != null) {
      _uploadAndSendFile();
      return;
    }
    if (_controller.text.trim().isEmpty) return;
    ref
        .read(chatSocketProvider(widget.appointmentId))
        .send(_controller.text.trim());
    _controller.clear();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    // Limit to 10MB (10 * 1024 * 1024 bytes)
    const maxSizeBytes = 10 * 1024 * 1024;

    if (file.size > maxSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File too large. Maximum size is 10MB.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _selectedFile = file);
  }

  Future<void> _uploadAndSendFile() async {
    if (_selectedFile == null) return;

    final file = _selectedFile!;
    setState(() {
      _isUploading = true;
      _selectedFile = null;
    });

    try {
      final bytes = file.bytes;
      if (bytes == null) return;

      final appointment = ref.read(appointmentDetailProvider(widget.appointmentId)).value;
      if (appointment == null) {
        throw Exception('Appointment details not loaded. Please try again.');
      }

      final socket = ref.read(chatSocketProvider(widget.appointmentId));
      final path = await socket.uploadFile(
        widget.appointmentId,
        bytes,
        file.name,
        doctorId: appointment.doctorId,
        patientId: appointment.patientId,
      );

      if (path != null) {
        final type = file.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'image';
        socket.send(
          _controller.text.trim().isEmpty ? 'Sent a ${type.toUpperCase()}: ${file.name}' : _controller.text.trim(),
          fileUrl: path,
          fileName: file.name,
          type: type,
        );
        _controller.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(chatHistoryProvider(widget.appointmentId));
    final socket = ref.watch(chatSocketProvider(widget.appointmentId));
    final currentUser = ref.watch(currentUserProvider);
    // Ensure appointment details are loaded for file upload permissions
    ref.watch(appointmentDetailProvider(widget.appointmentId));

    ref.listen(chatHistoryProvider(widget.appointmentId), (prev, next) {
      next.whenData((history) {
        if (!_loadedHistory) {
          setState(() {
            _messages.addAll(history);
            _loadedHistory = true;
          });
          _scrollToBottom();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.appointmentId.substring(0, 8)}'),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_copy_outlined),
            tooltip: 'Media & Reports',
            onPressed: () => context.push('/chat/${widget.appointmentId}/attachments'),
          ),
          IconButton(
            icon: const Icon(Icons.video_call_outlined),
            onPressed: () => context.push('/video/${widget.appointmentId}'),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(),
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_selectedFile!.extension?.toLowerCase() == 'pdf')
                    const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40)
                  else if (_selectedFile!.bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedFile!.bytes!,
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<ChatMessage>(
              stream: socket.messages,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final incoming = snapshot.data!;
                  if (!_messages.any((m) => m.id == incoming.id)) {
                    _messages.add(incoming);
                    _scrollToBottom();
                  }
                }
                return historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (_) => ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg.senderId == currentUser?.id;
                      final showDate = index == 0 ||
                          _messages[index].sentAt.day != _messages[index-1].sentAt.day;

                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                DateFormat('MMMM d, yyyy').format(msg.sentAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMine ? 16 : 0),
                                  bottomRight: Radius.circular(isMine ? 0 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (msg.type == ChatMessageType.image && msg.fileUrl != null)
                                    FutureBuilder<String>(
                                      future: socket.getSecureUrl(msg.fileUrl!),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                          return GestureDetector(
                                            onTap: () => _showFullImage(snapshot.data!),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: snapshot.data!,
                                                placeholder: (context, url) => const SizedBox(
                                                  height: 200,
                                                  width: 200,
                                                  child: Center(child: CircularProgressIndicator()),
                                                ),
                                                errorWidget: (context, url, error) => const Icon(Icons.error),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox(
                                          height: 60,
                                          width: 60,
                                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        );
                                      },
                                    ),
                                  if (msg.type == ChatMessageType.pdf && msg.fileUrl != null)
                                    InkWell(
                                      onTap: () async {
                                        final secureUrl = await socket.getSecureUrl(msg.fileUrl!);
                                        if (secureUrl.isNotEmpty) {
                                          launchUrl(Uri.parse(secureUrl), mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.picture_as_pdf, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                msg.fileName ?? 'Document.pdf',
                                                style: TextStyle(
                                                  color: isMine ? Colors.white : null,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (msg.message.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        msg.message,
                                        style: TextStyle(
                                          color: isMine ? Colors.white : null,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('h:mm a').format(msg.sentAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMine
                                          ? Colors.white.withOpacity(0.7)
                                          : theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: theme.colorScheme.primary),
                      onPressed: _isUploading ? null : _pickFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
