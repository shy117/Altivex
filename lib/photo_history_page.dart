import 'package:flutter/material.dart';

import 'photo_store.dart';
import 'photo_gallery.dart';

class PhotoHistoryPage extends StatefulWidget {
  const PhotoHistoryPage({
    super.key,
    required this.store,
    required this.gallery,
    required this.openPhoto,
  });
  final PhotoStore store;
  final PhotoGallery gallery;
  final Future<void> Function(PhotoRecord) openPhoto;
  @override
  State<PhotoHistoryPage> createState() => _PhotoHistoryPageState();
}

class _PhotoHistoryPageState extends State<PhotoHistoryPage> {
  bool _busy = false;
  Future<void> _delete(PhotoRecord record) async {
    var removeGallery = false;
    final uris = [record.photoUri, record.originalUri].nonNulls.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('删除照片？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将删除应用内照片和拍摄记录。'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('同时删除系统相册副本'),
                subtitle: !widget.gallery.canDeleteSavedCopies
                    ? const Text('当前平台暂不支持删除相册副本')
                    : uris.isEmpty
                    ? const Text('没有可删除的已保存副本')
                    : null,
                value: removeGallery,
                onChanged:
                    uris.isNotEmpty && widget.gallery.canDeleteSavedCopies
                    ? (v) => update(() => removeGallery = v ?? false)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (removeGallery) await widget.gallery.deleteSavedCopies(uris);
      await widget.store.remove(record);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除未完成，已保留拍摄记录，可重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('拍摄记录')),
      body: widget.store.records.isEmpty
          ? const Center(child: Text('还没有拍摄记录'))
          : ListView.builder(
              itemCount: widget.store.records.length,
              itemBuilder: (context, index) {
                final record = widget.store.records[index];
                final name = record.photoName ?? record.originalName!;
                return ListTile(
                  leading: SizedBox(
                    width: 64,
                    height: 64,
                    child: Image.file(
                      widget.store.file(name),
                      cacheWidth: 128,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  title: Text(
                    record.createdAt.toLocal().toString().substring(0, 19),
                  ),
                  subtitle: Text(
                    record.processingFailed
                        ? '处理失败 · 原图已保留'
                        : record.saved
                        ? '已保存到相册'
                        : '尚未保存到相册',
                  ),
                  onTap: _busy
                      ? null
                      : () async {
                          await widget.openPhoto(record);
                          if (mounted) setState(() {});
                        },
                  trailing: IconButton(
                    tooltip: '删除照片',
                    onPressed: _busy ? null : () => _delete(record),
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            ),
    ),
  );
}
