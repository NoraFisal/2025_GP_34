import 'package:flutter/material.dart';

/// A tiny side tab that expands into a rounded panel with menu items.
/// Put it as the LAST child of the page's Stack so it stays on top.
class MiniSideNav extends StatefulWidget {
  const MiniSideNav({
    super.key,
    required this.top,
    required this.left,
    this.items = const [
      'Home',
      'Teams',
      'Tournaments',
      'Messages',
      'Profile',
      'Contact'
    ],
    required this.onSelect,
  });

  /// Position (relative to the page Stack)
  final double top;
  final double left;

  /// Menu labels
  final List<String> items;

  /// Called when an item is tapped
  final ValueChanged<String> onSelect;

  @override
  State<MiniSideNav> createState() => _MiniSideNavState();
}

class _MiniSideNavState extends State<MiniSideNav>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  // Sizes
  static const double _collapsedWidth = 32;
  static const double _collapsedHeight = 82;
  static const double _panelWidth = 190;
  static const double _panelMinHeight = 240;
  static const double _radius = 16;
  static const Color _red = Color(0xFF9E2819);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOut,
          width: _open ? _panelWidth : _collapsedWidth,
          height: _open
              ? (_panelMinHeight + (widget.items.length * 38))
                  .clamp(_panelMinHeight, 360)
                  .toDouble()
              : _collapsedHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_open) _buildPanel(context),
              Positioned(
                top: 0,
                left: 0,
                child: _CollapsedGrabber(
                  onTap: () => setState(() => _open = !_open),
                  open: _open,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(left: 18),
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 10),
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6)),
            BoxShadow(
                color: Color(0x66FFFFFF),
                blurRadius: 10,
                spreadRadius: -6),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر الإغلاق
            Row(
              children: [
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _open = false),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // عناصر القائمة
            ...widget.items.map(
              (label) => _NavItem(
                text: label,
                onTap: () {
                  setState(() => _open = false);
                  widget.onSelect(label);

                  

                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedGrabber extends StatelessWidget {
  const _CollapsedGrabber({required this.onTap, required this.open});

  final VoidCallback onTap;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 82,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 26,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF9E2819),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Icon(
              open ? Icons.chevron_left : Icons.chevron_right,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
