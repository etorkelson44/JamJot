import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = {};

/// Web: embed the sheet music (PDF or image) right in the practice screen.
Widget buildScoreFrame(String url) {
  final viewType = 'jamjot-score-${url.hashCode}';
  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = web.document.createElement('iframe')
          as web.HTMLIFrameElement;
      el.src = url;
      el.style.border = 'none';
      el.style.width = '100%';
      el.style.height = '100%';
      return el;
    });
    _registered.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}
