import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget buildCorsImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: fit,
    placeholder: placeholder != null ? (context, url) => placeholder : null,
    errorWidget: errorWidget != null ? (context, url, error) => errorWidget : null,
  );
}
