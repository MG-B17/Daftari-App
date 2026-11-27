import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class WidgetImageExporter {
  Future<Uint8List> export(Widget widget, {double width = 420}) async {
    final pipeline = PipelineOwner();
    final focus = FocusManager();
    final owner = BuildOwner(focusManager: focus);
    final boundary = RenderRepaintBoundary();
    final overflow = RenderConstrainedOverflowBox(
      minWidth: width,
      maxWidth: width,
      minHeight: 0,
      maxHeight: double.infinity,
      child: boundary,
    );
    final position = RenderPositionedBox(
      alignment: Alignment.topCenter,
      child: overflow,
    );
    final view = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tightFor(width: width, height: 1),
        physicalConstraints: BoxConstraints.tightFor(width: width, height: 1),
      ),
      child: position,
    );
    RenderObjectToWidgetElement<RenderBox>? root;
    ui.Image? image;
    try {
      pipeline.rootNode = view;
      view.prepareInitialFrame();
      root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: widget,
      ).attachToRenderTree(owner);
      owner.buildScope(root);
      owner.finalizeTree();
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
      // Bound native allocation even if malformed imported data is enormous.
      if (boundary.size.height * 2.5 > 8192) {
        throw StateError('Statement image exceeds export bounds');
      }
      image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image?.dispose();
      if (root != null) {
        RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
            .attachToRenderTree(owner, root);
        owner.buildScope(root);
        owner.finalizeTree();
      }
      pipeline.rootNode = null;
      view.child = null;
      position.child = null;
      overflow.child = null;
      boundary.dispose();
      overflow.dispose();
      position.dispose();
      view.dispose();
      pipeline.dispose();
      focus.dispose();
    }
  }
}
