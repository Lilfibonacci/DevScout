import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test font loading and image export', (tester) async {
    final fontLoader = FontLoader('Morabba');
    final fontData = File('assets/fonts/Morabba-Regular.ttf').readAsBytesSync();
    fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: repaintKey,
          child: Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: Text(
                'رادار فرصت‌های شغلی DevScout',
                style: TextStyle(fontFamily: 'Morabba', fontSize: 24, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/test_render.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    print('SUCCESS: /tmp/test_render.png generated (${File('/tmp/test_render.png').lengthSync()} bytes)');
  });
}
