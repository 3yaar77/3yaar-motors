import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autoreel/theme.dart';

/// RealUaePlate: A highly realistic UAE license plate UI component.
/// - Face: #E9EDF2 light grey (no glow), full width
/// - Borders: 2px black outer, 1px dark grey inner, radius 4
/// - Layout: Left/logo area (fixed width), optional code, large number on right
/// - Dubai style: left shows "Dubai" (logo/text placeholder), code next, number right
/// - Abu Dhabi style: left shows small code + red logo area + emirate text, number right
/// - Other emirates: left shows "UAE" + emirate name, code then number
/// - Typography: condensed/bold, number letterSpacing 2
class RealUaePlate extends StatelessWidget {
  final String emirate; // e.g., Dubai, Abu Dhabi, Sharjah
  final String? code; // e.g., A or 8
  final String? number; // e.g., 12345
  final String? plateNumber; // Fallback source, e.g., "A 12345"
  final double height; // Required explicit height per spec

  const RealUaePlate({super.key, required this.emirate, this.code, this.number, this.plateNumber, required this.height});

  (String code, String number) _split(String? c, String? n, String? p) {
    if ((c != null && c.isNotEmpty) && (n != null && n.isNotEmpty)) return (c, n);
    final src = (p ?? '').trim();
    if (src.isEmpty) return ('', '');
    final parts = src.split(RegExp(r"\s+"));
    if (parts.length >= 2) return (parts.first, parts.sublist(1).join(' '));
    return ('', src);
  }

  bool get _isDubai => emirate.toLowerCase().contains('dubai');
  bool get _isAbuDhabi => emirate.toLowerCase().contains('abu dhabi');

  @override
  Widget build(BuildContext context) {
    final (c, n) = _split(code, number, plateNumber);

    // Sizes
    final double h = height; // 62 for cards, 95 for details
    final double radius = 4;
    final double innerRadius = 3;
    final double leftAreaWidth = _isDubai || _isAbuDhabi ? 72 : 66;
    final EdgeInsets contentPad = const EdgeInsets.symmetric(horizontal: 10);

    // Typography
    final TextStyle codeStyle = GoogleFonts.barlowCondensed(
      fontSize: h >= 90 ? 28 : 22,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1,
    );
    final TextStyle numberStyle = GoogleFonts.barlowCondensed(
      fontSize: h >= 90 ? 50 : 34,
      fontWeight: FontWeight.w900,
      color: Colors.black,
      letterSpacing: 2,
      height: 1,
    );
    final TextStyle smallLabel = const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black, height: 1);
    final TextStyle emirateLabel = const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black, height: 1.05);

    // Left emblem area per emirate
    Widget leftArea() {
      if (_isDubai) {
        return SizedBox(
          width: leftAreaWidth,
          child: Center(
            child: Text('Dubai',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
        );
      }
      if (_isAbuDhabi) {
        return SizedBox(
          width: leftAreaWidth,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Thin red accent bar + text
            Container(width: 4, height: h * 0.55, decoration: const BoxDecoration(color: MarketplaceColors.plateAbuDhabiAccent)),
            const SizedBox(width: 6),
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c.isNotEmpty)
                  Text(c, style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, height: 1)),
                Text('Abu Dhabi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black)),
              ]),
            ),
          ]),
        );
      }
      // Other emirates
      return SizedBox(
        width: leftAreaWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('UAE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, height: 1)),
          const SizedBox(height: 2),
          Text(emirate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: emirateLabel),
        ]),
      );
    }

    // Middle: For Dubai/others show code next to left; for Abu Dhabi we already show code in left
    final Widget midCode = !_isAbuDhabi && c.isNotEmpty
        ? Padding(padding: const EdgeInsets.only(left: 6, right: 8), child: Text(c, style: codeStyle))
        : const SizedBox(width: 0, height: 0);

    // Right: large number, aligned left for readability but taking remaining space
    final Widget rightNumber = Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(n, maxLines: 1, overflow: TextOverflow.visible, style: numberStyle),
        ),
      ),
    );

    final plateCore = Container(
      padding: contentPad,
      color: MarketplaceColors.plateFace,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        leftArea(),
        const SizedBox(width: 8),
        midCode,
        rightNumber,
      ]),
    );

    // Outer/inner border stack
    return SizedBox(
      height: h,
      width: double.infinity,
      child: Stack(children: [
        // Outer border + radius + shadow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: MarketplaceColors.plateFace,
              border: Border.all(color: MarketplaceColors.plateBorder, width: 2),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                // Soft shadow under plate
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
          ),
        ),
        // Inner border inset by 2px
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: MarketplaceColors.plateFace,
              border: Border.all(color: MarketplaceColors.realPlateInnerBorder, width: 1),
              borderRadius: BorderRadius.circular(innerRadius),
            ),
          ),
        ),
        // Content with the same inner insets
        Positioned.fill(child: Container(margin: const EdgeInsets.all(2), child: plateCore)),
      ]),
    );
  }
}
