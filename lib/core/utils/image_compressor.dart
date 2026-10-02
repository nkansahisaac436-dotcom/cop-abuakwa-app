import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressor {
  ImageCompressor._();

  /// Compresses a photo for posts/projects: max 1600px longest side, JPEG 80% quality.
  static Future<Uint8List> compressPostImage(Uint8List bytes, {int maxDimension = 1600, int quality = 80}) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image resized = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width >= image.height) {
        resized = img.copyResize(image, width: maxDimension);
      } else {
        resized = img.copyResize(image, height: maxDimension);
      }
    }

    final compressed = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(compressed);
  }

  /// Compresses an avatar photo: square crop and max 512px, JPEG 85% quality.
  static Future<Uint8List> compressAvatar(Uint8List bytes, {int size = 512, int quality = 85}) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Crop to square from center
    final minDim = image.width < image.height ? image.width : image.height;
    final xOffset = (image.width - minDim) ~/ 2;
    final yOffset = (image.height - minDim) ~/ 2;

    final square = img.copyCrop(image, x: xOffset, y: yOffset, width: minDim, height: minDim);
    final resized = img.copyResize(square, width: size, height: size);

    final compressed = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(compressed);
  }
}
