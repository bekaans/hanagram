// Hanagram — web image (placeholder — dosya okuma stub'da desteklenmez)
import 'package:flutter/material.dart';

class PlatformImage extends StatelessWidget {
  const PlatformImage({
    super.key,
    required this.file,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  /// Web'de dosya stub File nesnesi alınır ama okunamaz, placeholder gösterilir.
  final dynamic file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white38, size: 32),
      ),
    );
  }
}
