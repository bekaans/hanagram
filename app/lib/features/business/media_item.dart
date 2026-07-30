// Hanagram — medya modeli ve kart görünümü.
//
// product_item.dart kalıbına göre. Medya meta verisini tutar;
// gerçek dosya platformdaki image_picker tarafından yüklenir.
import '../../core/web_compat.dart';
import '../../core/platform_image.dart';

import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class MediaData {
  final String id;
  final String ownerId;
  final String type;
  final String filePath;
  final String thumbnailPath;
  final String mimeType;
  final int fileSize;
  final int width;
  final int height;
  final int durationMs;
  final String caption;
  final int createdAt;

  const MediaData({
    required this.id,
    required this.ownerId,
    this.type = 'photo',
    this.filePath = '',
    this.thumbnailPath = '',
    this.mimeType = '',
    this.fileSize = 0,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.caption = '',
    this.createdAt = 0,
  });

  factory MediaData.fromJson(Map<String, dynamic> j) {
    return MediaData(
      id: j['id'] as String? ?? '',
      ownerId: j['ownerId'] as String? ?? '',
      type: j['type'] as String? ?? 'photo',
      filePath: j['filePath'] as String? ?? '',
      thumbnailPath: j['thumbnailPath'] as String? ?? '',
      mimeType: j['mimeType'] as String? ?? '',
      fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
      width: (j['width'] as num?)?.toInt() ?? 0,
      height: (j['height'] as num?)?.toInt() ?? 0,
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      caption: j['caption'] as String? ?? '',
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isVideo => type == 'video';

  String get fileSizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get durationLabel {
    if (durationMs <= 0) return '';
    final s = durationMs ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

/// Medya ızgarasındaki tek bir kutucuk.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.media,
    required this.onTap,
  });

  final MediaData media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final path = media.thumbnailPath.isNotEmpty
        ? media.thumbnailPath
        : media.filePath;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HgRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path.isEmpty)
              _placeholder(c)
            else if (path.startsWith('http'))
              Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(c),
              )
            else
              PlatformImage(
                file: File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(c),
              ),
            if (media.isVideo)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(HgRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        media.durationLabel,
                        style: HgText.caption
                            .copyWith(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            if (media.caption.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black45],
                    ),
                  ),
                  child: Text(
                    media.caption,
                    style: HgText.caption
                        .copyWith(color: Colors.white, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(HgColors c) {
    return Container(
      color: c.surfaceAlt,
      child: Icon(
        media.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: c.textFaint,
        size: 28,
      ),
    );
  }
}
