// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildCorsImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  // Use a unique view type for each unique URL to avoid factory registration collisions
  final viewType = 'cors-image-${url.hashCode}';
  
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final img = html.ImageElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
        
      if (fit == BoxFit.cover) {
        img.style.objectFit = 'cover';
      } else if (fit == BoxFit.contain) {
        img.style.objectFit = 'contain';
      } else if (fit == BoxFit.fill) {
        img.style.objectFit = 'fill';
      }
      return img;
    },
  );
  
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
