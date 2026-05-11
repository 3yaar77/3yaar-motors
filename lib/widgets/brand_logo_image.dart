import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// BrandLogoImage renders a network image that may be PNG/JPEG.
/// - Avoids SVG network rendering for reliability; if URL is SVG, shows text initials instead.
/// - On load error, shows brand initials (fallback) instead of a car icon.
class BrandLogoImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final String? label; // brand name for text fallback
  const BrandLogoImage(
      {super.key, required this.url, this.fit = BoxFit.contain, this.label});

  bool get _isSvg {
    final u = url.toLowerCase();
    return u.endsWith('.svg') || u.contains('.svg');
  }

  bool get _isWikimedia => url.contains('upload.wikimedia.org');

  // Convert a Wikimedia SVG URL to PNG thumbnail for better web reliability.
  // Example:
  // https://upload.wikimedia.org/wikipedia/commons/4/44/BMW.svg
  // -> https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/BMW.svg/240px-BMW.svg.png
  String? _wikimediaPngThumb(String u) {
    try {
      final uri = Uri.parse(u);
      if (!uri.host.contains('upload.wikimedia.org')) return null;
      final seg = [...uri.pathSegments];
      final wikipediaIdx = seg.indexOf('wikipedia');
      if (wikipediaIdx < 0 || wikipediaIdx + 1 >= seg.length) return null;
      // Insert 'thumb' right after the language or 'commons' segment.
      final afterLangIdx = wikipediaIdx + 1;
      if (afterLangIdx >= seg.length) return null;
      // Ensure we have at least 3 more segments: hash1/hash2/file.svg
      if (afterLangIdx + 3 >= seg.length) return null;
      final fileName = seg.last;
      if (!fileName.toLowerCase().endsWith('.svg')) return null;
      final base = [
        ...seg.sublist(0, afterLangIdx + 1),
        'thumb',
        ...seg.sublist(afterLangIdx + 1),
      ];
      final pngTail = '${fileName.replaceAll('%20', ' ')}';
      final thumbName = '240px-$pngTail.png';
      final newSeg = [...base, thumbName];
      final newUri = uri.replace(pathSegments: newSeg);
      return newUri.toString();
    } catch (_) {
      return null;
    }
  }

  String _brandName(String? name) =>
      (name == null || name.trim().isEmpty) ? 'Brand' : name.trim();

  Widget _textFallback() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _brandName(label),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    if (u.isEmpty) return _textFallback();
    // Prefer PNG thumbnail for Wikimedia SVGs to avoid web CORS/decoding issues.
    if (_isSvg && _isWikimedia) {
      final thumb = _wikimediaPngThumb(u);
      if (thumb != null) {
        return Image.network(thumb, fit: fit, errorBuilder: (ctx, err, st) {
          // Fallback to direct SVG loader; if that fails, show text.
          return _SvgNetwork(url: u, fit: fit, label: label);
        });
      }
    }
    // If it's an SVG, render the SVG from network with proper fallback.
    if (_isSvg) return _SvgNetwork(url: u, fit: fit, label: label);
    return Image.network(u, fit: fit, errorBuilder: (ctx, err, st) => _textFallback());
  }
}

class _SvgNetwork extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final String? label;
  const _SvgNetwork({required this.url, required this.fit, this.label});

  String _brandName(String? name) =>
      (name == null || name.trim().isEmpty) ? 'Brand' : name.trim();

  Future<Uint8List> _loadBytes(String u) async {
    final data = await NetworkAssetBundle(Uri.parse(u)).load(u);
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _loadBytes(url.trim()),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_brandName(label),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          );
        }
        final bytes = snap.data;
        if (bytes == null) {
          return const SizedBox.shrink();
        }
        return SvgPicture.memory(bytes, fit: fit);
      },
    );
  }
}
