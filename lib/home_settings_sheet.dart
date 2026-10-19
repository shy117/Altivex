import 'package:flutter/material.dart';

/// A fixed header keeps dismissal available even after the settings are scrolled.
class HomeSettingsSheet extends StatefulWidget {
  const HomeSettingsSheet({super.key, required this.children});
  final List<Widget> children;
  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet> {
  double _drag = 0;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              GestureDetector(
                key: const Key('home-settings-header'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _drag = 0,
                onVerticalDragUpdate: (details) {
                  _drag += details.delta.dy;
                  if (_drag > 48) {
                    _drag = double.negativeInfinity;
                    Navigator.maybePop(context);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '高度计设置',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭设置',
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: colors.onSurfaceVariant,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(height: 1, color: colors.outlineVariant),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('home-settings-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
