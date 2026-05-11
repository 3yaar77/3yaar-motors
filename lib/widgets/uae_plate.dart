import 'package:flutter/material.dart';
import 'package:autoreel/theme.dart';

/// UAE license plate widget (realistic, reusable)
/// - Light grey face (#F4F4F4) with 2px solid black border and 6px radius
/// - Left emirate box: shows "UAE" and emirate name; optional red accent for Abu Dhabi
/// - Middle: code letter
/// - Right: large bold number with letterSpacing 1.5
/// - Two size presets: card (compact) and detail (large)

enum UaePlateSize { card, detail }

class UaePlate extends StatelessWidget {
  final String emirate;
  final String? code; // Optional explicit code (e.g., 'A')
  final String? number; // Optional explicit number (e.g., '12345')
  final String? plateNumber; // Fallback source (e.g., 'A 12345')
  final UaePlateSize size;
  final double? height; // Override default height if provided
  final EdgeInsetsGeometry padding;

  const UaePlate({
    super.key,
    required this.emirate,
    this.code,
    this.number,
    this.plateNumber,
    this.size = UaePlateSize.card,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  (String code, String number) _split(String? code, String? number, String? plate) {
    if ((code != null && code.isNotEmpty) && (number != null && number.isNotEmpty)) {
      return (code, number);
    }
    final src = (plate ?? '').trim();
    if (src.isEmpty) return ('', '');
    final parts = src.split(RegExp(r"\s+"));
    if (parts.length >= 2) return (parts.first, parts.sublist(1).join(' '));
    return ('', src);
  }

  @override
  Widget build(BuildContext context) {
    final (c, n) = _split(code, number, plateNumber);

    // Typography per size
    final bool isDetail = size == UaePlateSize.detail;
    final double codeSize = isDetail ? 22 : 18; // middle letter
    final double numberSize = isDetail ? 38 : 26; // right large number

    final double targetHeight = height ?? (isDetail ? 110 : 64);

    final plateFace = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: MarketplaceColors.plateFace,
        border: Border.all(color: MarketplaceColors.plateBorder, width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Left emirate box (fixed width)
        SizedBox(
          width: 62,
          child: Stack(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: MarketplaceColors.plateEmirateBoxBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('UAE',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, height: 1, fontWeight: FontWeight.w900, color: Colors.black)),
                const SizedBox(height: 2),
                Text(
                  emirate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, height: 1.1, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ]),
            ),
            // Optional thin red accent for Abu Dhabi only
            if (emirate.toLowerCase().contains('abu dhabi'))
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, decoration: const BoxDecoration(color: MarketplaceColors.plateAbuDhabiAccent, borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)))),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        // Middle code letter
        if (c.isNotEmpty)
          Text(
            c,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: codeSize, height: 1),
          ),
        if (c.isNotEmpty) const SizedBox(width: 10),
        // Right number (expanded + fitted)
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                n,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: numberSize, height: 1),
              ),
            ),
          ),
        ),
      ]),
    );

    return SizedBox(height: targetHeight, width: double.infinity, child: plateFace);
  }
}
