import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareContent(
  BuildContext context, {
  String? text,
  String? photoPath,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null
      ? const Rect.fromLTWH(0, 0, 1, 1)
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: photoPath == null ? null : [XFile(photoPath)],
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开分享，请稍后重试')));
    }
  }
}
