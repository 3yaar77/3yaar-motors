import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, Image;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-screen image cropper with pan/zoom and fixed aspect ratio.
/// Returns PNG bytes (Uint8List) via Navigator.pop on Save, or null on Cancel.
class ImageCropPage extends StatefulWidget {
  final Uint8List initialBytes;
  final double aspectRatio; // width / height
  const ImageCropPage({super.key, required this.initialBytes, this.aspectRatio = 4 / 3});

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _onCancel() async => Navigator.of(context).pop<Uint8List?>(null);

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.of(context).pop<Uint8List?>(null);
        return;
      }
      final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 4.0);
      final ui.Image img = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Navigator.of(context).pop<Uint8List?>(null);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List?>(bytes);
    } catch (_) {
      if (mounted) Navigator.of(context).pop<Uint8List?>(null);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Crop Image'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _onCancel),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _onSave,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(_saving ? 'Saving...' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight - 96; // leave space for app bar
          // Compute crop area that fits and respects aspect ratio
          double cropW = maxW * 0.9;
          double cropH = cropW / widget.aspectRatio;
          if (cropH > maxH * 0.9) {
            cropH = maxH * 0.9;
            cropW = cropH * widget.aspectRatio;
          }
          final borderRadius = 14.0;
          return SizedBox(
            width: cropW,
            height: cropH,
            child: Stack(children: [
              // RepaintBoundary captures only the image area, not the overlay
              RepaintBoundary(
                key: _boundaryKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 6,
                      clipBehavior: Clip.hardEdge,
                      child: Center(
                        child: Image.memory(widget.initialBytes, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              // Rectangular overlay (not captured)
              IgnorePointer(
                child: CustomPaint(
                  painter: _RectMaskPainter(borderRadius: borderRadius, borderColor: Colors.white.withValues(alpha: 0.15)),
                  child: const SizedBox.expand(),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class _RectMaskPainter extends CustomPainter {
  final double borderRadius;
  final Color borderColor;
  const _RectMaskPainter({required this.borderRadius, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final clear = Paint()..blendMode = BlendMode.clear;

    // Dim outside the rounded-rect crop area
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, overlay);
    canvas.drawRRect(rrect, clear);
    canvas.restore();

    // Border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    canvas.drawRRect(rrect.deflate(1), border);
  }

  @override
  bool shouldRepaint(covariant _RectMaskPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.borderColor != borderColor;
}

/// Convenience helper to show the cropper and return cropped bytes.
Future<Uint8List?> showImageCropper(BuildContext context, Uint8List initialBytes, {double aspectRatio = 4 / 3}) async {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: ImageCropPage(initialBytes: initialBytes, aspectRatio: aspectRatio),
      ),
    ),
  );
}
