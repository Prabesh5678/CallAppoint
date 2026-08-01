import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/centered_constrained_box.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';

class ChatAttachmentsScreen extends ConsumerWidget {
  final String appointmentId;
  const ChatAttachmentsScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(chatHistoryProvider(appointmentId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media & Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Media', icon: Icon(Icons.image)),
              Tab(text: 'Documents', icon: Icon(Icons.description)),
            ],
          ),
        ),
        body: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (messages) {
            final media = messages.where((m) => m.type == ChatMessageType.image).toList();
            final docs = messages.where((m) => m.type == ChatMessageType.pdf).toList();

            return CenteredConstrainedBox(
              maxWidth: 1000,
              child: TabBarView(
                children: [
                  _MediaGrid(media: media),
                  _DocsList(docs: docs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  final List<ChatMessage> media;
  const _MediaGrid({required this.media});

  void _showFullImage(BuildContext context, String imageUrl) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (media.isEmpty) {
      return const Center(child: Text('No media shared yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final msg = media[index];
        return FutureBuilder<String>(
          future: ref.read(chatSocketProvider(msg.fileUrl!.split('/')[1])).getSecureUrl(msg.fileUrl!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(color: Colors.black12);
            }
            return GestureDetector(
              onTap: () => _showFullImage(context, snapshot.data!),
              child: CachedNetworkImage(
                imageUrl: snapshot.data!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            );
          },
        );
      },
    );
  }
}

class _DocsList extends ConsumerWidget {
  final List<ChatMessage> docs;
  const _DocsList({required this.docs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (docs.isEmpty) {
      return const Center(child: Text('No documents shared yet'));
    }

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final msg = docs[index];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
          title: Text(msg.fileName ?? 'Report.pdf'),
          subtitle: Text(DateFormat('MMM dd, yyyy • h:mm a').format(msg.sentAt)),
          onTap: () async {
            final appointmentId = msg.fileUrl!.split('/')[1];
            final secureUrl = await ref.read(chatSocketProvider(appointmentId)).getSecureUrl(msg.fileUrl!);
            if (secureUrl.isNotEmpty) {
              launchUrl(Uri.parse(secureUrl), mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }
}
