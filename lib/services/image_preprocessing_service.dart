import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

class PreparedImage {
  const PreparedImage({
    required this.sourceBytes,
    required this.image,
    required this.tensor,
    required this.scale,
    required this.padLeft,
    required this.padTop,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.pixelScaleFactor,
  });

  final Uint8List sourceBytes;
  final img.Image image;
  final Float32List tensor;
  final double scale;
  final int padLeft;
  final int padTop;
  final int resizedWidth;
  final int resizedHeight;
  final int sourceWidth;
  final int sourceHeight;
  final double pixelScaleFactor;
}

class ImagePreprocessingService {
  static const int inputSize = 640;
  static const int maxLongSide = 640;

  Future<PreparedImage> preprocess(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final sourceWidth = descriptor.width;
    final sourceHeight = descriptor.height;
    final downsample = math.min(
      1.0,
      maxLongSide / math.max(sourceWidth, sourceHeight),
    );
    final width = math.max(1, (sourceWidth * downsample).round());
    final height = math.max(1, (sourceHeight * downsample).round());
    final codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );

    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) {
          throw const FormatException('The image could not be decoded.');
        }
        final decoded = img.decodePng(png.buffer.asUint8List());
        if (decoded == null) {
          throw const FormatException(
            'Unsupported image format. Choose a JPEG or PNG image.',
          );
        }
        return _letterbox(
          bytes,
          decoded,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }

  PreparedImage _letterbox(
    Uint8List sourceBytes,
    img.Image source, {
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final scale = inputSize / math.max(source.width, source.height);
    final resizedWidth = (source.width * scale).round();
    final resizedHeight = (source.height * scale).round();
    final padLeft = ((inputSize - resizedWidth) / 2 - 0.1).round();
    final padTop = ((inputSize - resizedHeight) / 2 - 0.1).round();
    final resized = img.copyResize(
      source,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );
    final letterboxed = img.Image(width: inputSize, height: inputSize);
    img.fill(letterboxed, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(letterboxed, resized, dstX: padLeft, dstY: padTop);

    final planeSize = inputSize * inputSize;
    final tensor = Float32List(3 * planeSize);
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = letterboxed.getPixel(x, y);
        final offset = y * inputSize + x;
        tensor[offset] = pixel.r / 255.0;
        tensor[planeSize + offset] = pixel.g / 255.0;
        tensor[2 * planeSize + offset] = pixel.b / 255.0;
      }
    }

    return PreparedImage(
      sourceBytes: sourceBytes,
      image: source,
      tensor: tensor,
      scale: scale,
      padLeft: padLeft,
      padTop: padTop,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      pixelScaleFactor: math.max(
        sourceWidth / source.width,
        sourceHeight / source.height,
      ),
    );
  }
}
