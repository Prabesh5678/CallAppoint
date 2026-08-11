import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';

class AnatomyViewer extends StatefulWidget {
  final String? organ;

  const AnatomyViewer({super.key, this.organ});

  @override
  State<AnatomyViewer> createState() => _AnatomyViewerState();
}

class _AnatomyViewerState extends State<AnatomyViewer> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    // If an organ is provided, use the query param, otherwise just open the home page
    final String url = widget.organ != null
        ? "https://anatomy-livid.vercel.app/?organ=${widget.organ}"
        : "https://anatomy-livid.vercel.app/";

    final String title = widget.organ != null
        ? '${widget.organ![0].toUpperCase()}${widget.organ!.substring(1)} 3D Model'
        : '3D Anatomy Explorer';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            key: ValueKey(url), // Ensures a fresh load when the organ changes
            initialUrlRequest: URLRequest(url: WebUri(url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              useWideViewPort: true,
              isInspectable: true,
            ),
            onProgressChanged: (controller, progress) {
              setState(() => _progress = progress / 100);
            },
            onLoadStop: (controller, url) {
              setState(() => _progress = 1.0);
            },
            onLoadError: (controller, url, code, message) {
              setState(() => _progress = 1.0);
            },
          ),
          if (_progress < 1.0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white,
                color: Theme.of(context).primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
