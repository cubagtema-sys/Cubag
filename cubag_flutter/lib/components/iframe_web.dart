// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildIframe(String mmsi) {
  final viewType = 'marinetraffic-$mmsi';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.IFrameElement()
      ..src = 'https://www.marinetraffic.com/en/ais/embed/mmsi:$mmsi/zoom:8/maptype:1/show_vessels:true'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );
  return HtmlElementView(viewType: viewType);
}
