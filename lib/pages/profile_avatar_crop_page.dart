import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, Image;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-screen avatar cropper with 1:1 aspect and circular preview overlay.
/// - Uses InteractiveViewer for pan/zoom
/// - Captures a square crop via RepaintBoundary (PNG)
/// - Returns Uint8List? via Navigator.pop on Save/Cancel
class ProfileAvatarCropPage extends StatefulWidget {
  final Uint8List initialBytes;
  const ProfileAvatarCropPage({super.key, required this.initialBytes});

  @override
  State<ProfileAvatarCropPage> createState() => _ProfileAvatarCropPageState();
}

class _ProfileAvatarCropPageState extends State<ProfileAvatarCropPage> {
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
      // Use devicePixelRatio to keep result crisp
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
    } catch (e) {
      // Silently return null if capture failed
      Navigator.of(context).pop<Uint8List?>(null);
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
        title: const Text('Crop Photo'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onCancel,
        ),
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
          final size = (constraints.maxWidth < constraints.maxHeight)
              ? constraints.maxWidth
              : constraints.maxHeight - 80; // leave some space for app bar
          final square = size.clamp(240.0, 600.0);
          return SizedBox(
            width: square,
            height: square,
            child: Stack(children: [
              // RepaintBoundary captures only the image area, not the overlay
              RepaintBoundary(
                key: _boundaryKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      clipBehavior: Clip.hardEdge,
                      child: Center(
                        child: Image.memory(
                          widget.initialBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Circular preview overlay (not captured)
              IgnorePointer(
                child: CustomPaint(
                  painter: _CircleMaskPainter(borderColor: Colors.white.withValues(alpha: 0.15)),
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

class _CircleMaskPainter extends CustomPainter {
  final Color borderColor;
  const _CircleMaskPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Dim outside the circle
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final clear = Paint()..blendMode = BlendMode.clear;

    // Draw dim layer
    final layer = Path()..addRect(rect);
    canvas.saveLayer(rect, Paint());
    canvas.drawPath(layer, overlay);
    // Clear a circle area in the middle
    canvas.drawCircle(center, radius, clear);

    // Commit layer
    canvas.restore();

    // Circle border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    canvas.drawCircle(center, radius - 1, border);
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => oldDelegate.borderColor != borderColor;
}
