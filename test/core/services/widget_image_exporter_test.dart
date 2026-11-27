import 'dart:ui' as ui;

import 'package:daftariapp/core/services/image_exporter/widget_image_exporter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('off-screen export encodes PNG at 2.5x and can be repeated', (
    tester,
  ) async {
    final exporter = WidgetImageExporter();
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() async {
        final bytes = await exporter.export(
          const SizedBox(
            height: 100,
            child: ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        );
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1050);
        expect(frame.image.height, 250);
        frame.image.dispose();
        codec.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('oversized export fails before native allocation and recovers', (
    tester,
  ) async {
    final exporter = WidgetImageExporter();
    await tester.runAsync(() async {
      await expectLater(
        exporter.export(const SizedBox(height: 4000)),
        throwsStateError,
      );
      expect(await exporter.export(const SizedBox(height: 20)), isNotEmpty);
    });
  });
}
