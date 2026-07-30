// Hanagram — medya galerisi ekranı
//
// Kullanıcının/işletmenin tüm medyalarını ızgara biçiminde gösterir.
// Yükleme için image_picker kullanılır; seçilen dosya yerel olarak saklanır,
// ardından çekirdeğe meta veri olarak kaydedilir.
import '../../core/web_compat.dart';
import '../../core/platform_image.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/media_service.dart';
import 'package:hanagram_design/design.dart';
import 'media_item.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  List<MediaData> _items = const [];
  bool _isLoading = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });
    final result = await MediaService.listMedia();
    _items = result.map((e) => MediaData.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xfile == null) return;
    await _registerMedia(xfile, 'photo');
  }

  Future<void> _pickVideo() async {
    final xfile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (xfile == null) return;
    await _registerMedia(xfile, 'video');
  }

  Future<void> _registerMedia(dynamic xfile, String type) async {
    final app = AppScope.of(context);
    final authorId = app.session!.userId;
    final file = File(xfile.path);
    final stat = await file.stat();

    final publicUrl = await MediaService.uploadMedia(
      file,
      authorId,
      type: type == 'video' ? 'video' : 'image',
    );

    if (publicUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yükleme başarısız, tekrar deneyin.')),
        );
      }
      return;
    }

    await MediaService.registerMedia(
      publicUrl: publicUrl,
      type: type,
      mimeType: type == 'video' ? 'video/mp4' : 'image/jpeg',
      fileSize: stat.size,
    );
    _loadMedia();
  }

  void _showPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final c = HgTheme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(HgSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Medya ekle',
                    style: HgText.title.copyWith(color: c.text)),
                const SizedBox(height: HgSpace.lg),
                ListTile(
                  leading: Icon(Icons.photo_outlined, color: c.violet),
                  title: Text('Fotoğraf seç',
                      style: HgText.body.copyWith(color: c.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.videocam_outlined, color: c.coral),
                  title: Text('Video seç',
                      style: HgText.body.copyWith(color: c.text)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openViewer(MediaData media) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MediaViewer(
          media: media,
          onDelete: () => _deleteMedia(media),
        ),
      ),
    ).then((_) {
      if (mounted) _loadMedia();
    });
  }

  Future<void> _deleteMedia(MediaData media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medyayı sil'),
        content: const Text('Bu medyayı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await MediaService.deleteMediaRecord(media.id);
    if (mounted) _loadMedia();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Medya galerisi',
            style: HgText.title.copyWith(color: c.text)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPicker,
        backgroundColor: c.violet,
        child: Icon(Icons.add_photo_alternate_outlined, color: c.onBrand),
      ),
      body: _buildContent(c),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Medya yok',
        message: 'İlk fotoğraf veya videoyu eklemek için + butonuna dokunun.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMedia,
      child: GridView.builder(
        padding: const EdgeInsets.all(HgSpace.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: HgSpace.sm,
          crossAxisSpacing: HgSpace.sm,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final media = _items[index];
          return MediaThumb(
            media: media,
            onTap: () => _openViewer(media),
          );
        },
      ),
    );
  }
}

// ─── Tam ekran görüntüleyici ───

class _MediaViewer extends StatelessWidget {
  const _MediaViewer({
    required this.media,
    this.onDelete,
  });

  final MediaData media;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final path = media.filePath;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: media.caption.isNotEmpty
            ? Text(media.caption,
                style: HgText.body.copyWith(color: Colors.white))
            : null,
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
        ],
      ),
      body: Center(
        child: path.isEmpty
            ? const Icon(Icons.broken_image_outlined,
                color: Colors.white38, size: 64)
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: media.isVideo
                    ? const Icon(Icons.videocam_outlined,
                        color: Colors.white54, size: 64)
                    : (path.startsWith('http')
                        ? Image.network(
                            path,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                                size: 64),
                          )
                        : PlatformImage(file: File(path), fit: BoxFit.contain)),
              ),
      ),
    );
  }
}
