// Hanagram — native platform image (dart:io File ile)
import 'dart:io';
import 'package:flutter/widgets.dart';

class PlatformImage extends StatelessWidget {
  const PlatformImage({
    super.key,
    required this.file,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  final File file;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
