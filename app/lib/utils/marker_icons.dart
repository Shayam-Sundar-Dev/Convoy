import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// mapbox_maps_flutter's PointAnnotationManager takes marker icons as raw
/// image bytes, not widgets — there's no built-in "colored circle with a
/// letter" marker like some other map SDKs offer. This renders one with
/// dart:ui's Canvas and returns PNG bytes, so vehicle pins can show an
/// initial instead of being plain dots.
Future<Uint8List> buildLabelMarker({
  required String letter,
  required Color background,
  required Color foreground,
  required Color ring,
  double size = 84,
  bool emphasized = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final radius = size / 2;
  final center = Offset(radius, radius);

  final fill = Paint()..color = background;
  canvas.drawCircle(center, radius - 3, fill);

  final stroke = Paint()
    ..color = ring
    ..style = PaintingStyle.stroke
    ..strokeWidth = emphasized ? 3.5 : 2.5;
  canvas.drawCircle(center, radius - 3, stroke);

  final textPainter = TextPainter(
    text: TextSpan(
      text: letter.isNotEmpty ? letter[0].toUpperCase() : '?',
      style: TextStyle(
        color: foreground,
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Renders a modern, high-visibility GPS location puck for the map.
/// Comprises an outer glowing radar halo, a crisp white disc, and a vibrant cyan core with center pinpoint.
Future<Uint8List> buildCurrentLocationMarker({
  double size = 72,
  Color color = const Color(0xFF00C2FF), // Vibrant neon GPS cyan
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final radius = size / 2;
  final center = Offset(radius, radius);

  // 1. Soft glowing outer pulse halo
  final haloPaint = Paint()
    ..color = color.withAlpha(45)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius - 2, haloPaint);

  // 2. Halo boundary ring
  final haloStroke = Paint()
    ..color = color.withAlpha(120)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  canvas.drawCircle(center, radius - 2, haloStroke);

  // 3. Crisp white disc ring
  final whiteBorder = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius * 0.52, whiteBorder);

  // 4. Vibrant cyan GPS core
  final corePaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius * 0.40, corePaint);

  // 5. White center highlight pinpoint
  final centerDot = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(center, radius * 0.15, centerDot);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Renders a sleek automotive car marker for convoy vehicles.
/// Groups passengers, highlights lead vehicle, and indicates passenger count.
Future<Uint8List> buildVehicleCarMarker({
  required String vehicleName,
  required int passengerCount,
  required bool isLead,
  required bool isStale,
  double width = 120,
  double height = 62,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final mainHeight = height - 10;
  final pillRect = Rect.fromLTWH(2, 2, width - 4, mainHeight);
  final pillRRect = RRect.fromRectAndRadius(pillRect, const Radius.circular(13));

  final pointerPath = Path()
    ..moveTo(width / 2 - 8, mainHeight + 1)
    ..lineTo(width / 2, height - 1)
    ..lineTo(width / 2 + 8, mainHeight + 1)
    ..close();

  final combinedPath = Path()
    ..addRRect(pillRRect)
    ..addPath(pointerPath, Offset.zero);

  // 1. Outer Glow / Shadow
  final shadowPaint = Paint()
    ..color = isLead
        ? const Color(0xFFF5A623).withAlpha(80)
        : Colors.black.withAlpha(140)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  canvas.drawPath(combinedPath, shadowPaint);

  // 2. Background Fill
  final bgPaint = Paint()
    ..color = isStale
        ? const Color(0xFF1E232B)
        : (isLead ? const Color(0xFF161A22) : const Color(0xFF10141C))
    ..style = PaintingStyle.fill;
  canvas.drawPath(combinedPath, bgPaint);

  // 3. Border Stroke
  final strokePaint = Paint()
    ..color = isStale
        ? const Color(0xFF424C5C)
        : (isLead ? const Color(0xFFF5A623) : const Color(0xFF2E3847))
    ..style = PaintingStyle.stroke
    ..strokeWidth = isLead ? 2.2 : 1.5;
  canvas.drawPath(combinedPath, strokePaint);

  // 4. Car Icon Badge Container
  const iconContainerSize = 34.0;
  const iconLeft = 8.0;
  final iconTop = (mainHeight - iconContainerSize) / 2 + 1;
  final iconRect = Rect.fromLTWH(iconLeft, iconTop, iconContainerSize, iconContainerSize);
  final iconRRect = RRect.fromRectAndRadius(iconRect, const Radius.circular(9));

  final iconBgPaint = Paint()
    ..color = isStale
        ? const Color(0xFF2B323E)
        : (isLead ? const Color(0xFFF5A623) : const Color(0xFF1B222E))
    ..style = PaintingStyle.fill;
  canvas.drawRRect(iconRRect, iconBgPaint);

  if (!isStale) {
    final iconBorderPaint = Paint()
      ..color = isLead ? const Color(0xFFF5A623) : const Color(0xFF333E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(iconRRect, iconBorderPaint);
  }

  // 5. Automotive Car Icon
  final carIconPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.directions_car_rounded.codePoint),
      style: TextStyle(
        fontFamily: Icons.directions_car_rounded.fontFamily,
        package: Icons.directions_car_rounded.fontPackage,
        fontSize: 19,
        color: isStale
            ? const Color(0xFF7E8B9B)
            : (isLead ? const Color(0xFF121417) : const Color(0xFFF5A623)),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  carIconPainter.paint(
    canvas,
    Offset(
      iconLeft + (iconContainerSize - carIconPainter.width) / 2,
      iconTop + (iconContainerSize - carIconPainter.height) / 2,
    ),
  );

  // 6. Text Details (Vehicle Name & Passenger/Lead Badge)
  final textLeft = iconLeft + iconContainerSize + 7;
  final availableTextWidth = width - textLeft - 8;

  // Vehicle Name Text
  final displayName = vehicleName.trim().isNotEmpty ? vehicleName.trim() : 'Vehicle';
  final namePainter = TextPainter(
    text: TextSpan(
      text: displayName,
      style: TextStyle(
        color: isStale ? const Color(0xFF8C98A8) : Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    maxLines: 1,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: availableTextWidth);
  namePainter.paint(canvas, Offset(textLeft, iconTop + 1));

  // Subtitle / Badge
  String badgeText;
  if (isLead && passengerCount <= 1) {
    badgeText = '★ LEAD';
  } else if (isLead) {
    badgeText = '★ $passengerCount pax';
  } else if (passengerCount > 1) {
    badgeText = '$passengerCount pax';
  } else {
    badgeText = '1 pax';
  }

  final badgePainter = TextPainter(
    text: TextSpan(
      text: badgeText,
      style: TextStyle(
        color: isStale
            ? const Color(0xFF707D8E)
            : (isLead ? const Color(0xFFF5A623) : const Color(0xFF98A6B8)),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: availableTextWidth);

  // Small background pill for badge
  final badgePillRect = Rect.fromLTWH(
    textLeft - 2,
    iconTop + 18,
    badgePainter.width + 8,
    14,
  );
  final badgePillRRect = RRect.fromRectAndRadius(badgePillRect, const Radius.circular(4));
  final badgeBgPaint = Paint()
    ..color = isLead
        ? const Color(0xFFF5A623).withAlpha(35)
        : const Color(0xFF1E2532)
    ..style = PaintingStyle.fill;
  canvas.drawRRect(badgePillRRect, badgeBgPaint);

  badgePainter.paint(canvas, Offset(textLeft + 2, iconTop + 19));

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

