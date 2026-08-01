// Hanagram — Hizmete ait tüm medya (fotoğraf ve videoları) ızgara halinde gösterir.
// Profil sayfasında "+40" göstergesine dokunulduğunda açılır.

import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/service_catalog.dart';

class ServiceMediaScreen extends StatefulWidget {
  const ServiceMediaScreen({super.key, required this.service});
  final BusinessService service;

  @override
  State<ServiceMediaScreen> createState() => _ServiceMediaScreenState();
}

class _ServiceMediaScreenState extends State<ServiceMediaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _media = [];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final media = await ServiceCatalog.getServiceMedia(
        widget.service.id,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _media = media;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(widget.service.name),
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_media.isEmpty) {
      return EmptyState(
        icon: Icons.perm_media_outlined,
        title: 'Henüz medya yok',
        message: 'Bu hizmete ait video veya fotoğraf eklenmemiş.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: GridView.builder(
        padding: const EdgeInsets.all(HgSpace.sm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _media.length,
        itemBuilder: (context, index) {
          final item = _media[index];
          final filePath = item['file_path'] as String? ?? '';
          final isVideo = item['type'] == 'video';

          return _MediaGridCell(
            filePath: filePath,
            isVideo: isVideo,
            colors: c,
          );
        },
      ),
    );
  }
}

class _MediaGridCell extends StatelessWidget {
  const _MediaGridCell({
    required this.filePath,
    required this.isVideo,
    required this.colors,
  });

  final String filePath;
  final bool isVideo;
  final HgColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HgRadius.sm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),
          if (isVideo) _buildVideoOverlay(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (filePath.isEmpty) {
      return _buildPlaceholder();
    }

    if (filePath.startsWith('http')) {
      return Image.network(
        filePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // Yerel dosya yolu — Image.file web'de çalışmayacağı için placeholder göster
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: colors.surfaceAlt,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colors.textFaint,
        ),
      ),
    );
  }

  Widget _buildVideoOverlay() {
    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(HgRadius.sm),
        ),
        child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
      ),
    );
  }
}