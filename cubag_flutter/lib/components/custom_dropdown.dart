import 'package:flutter/material.dart';

const _kOrange = Color(0xFFf08232);

class CustomDropdown<T> extends StatefulWidget {
  final T value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? hint;
  final Widget? prefixIcon;
  final double? width;
  final bool dense;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.prefixIcon,
    this.width,
    this.dense = false,
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class DropdownItem<T> {
  final T value;
  final String label;
  final Widget? leading;

  const DropdownItem({required this.value, required this.label, this.leading});
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  OverlayEntry? _overlay;
  final _link = LayerLink();
  bool _open = false;

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _open = true;
      _overlay = _buildOverlay();
      Overlay.of(context).insert(_overlay!);
    }
    setState(() {});
  }

  void _close({bool fromDispose = false}) {
    _overlay?.remove();
    _overlay = null;
    _open = false;
    if (mounted && !fromDispose) setState(() {});
  }

  void _select(T val) {
    widget.onChanged(val);
    _close();
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black.withAlpha(40),
              child: Container(
                width: widget.width ?? size.width,
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFe2e8f0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    children: widget.items.map((item) {
                      final selected = item.value == widget.value;
                      return InkWell(
                        onTap: () => _select(item.value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          color: selected ? _kOrange.withAlpha(15) : Colors.transparent,
                          child: Row(children: [
                            if (item.leading != null) ...[item.leading!, const SizedBox(width: 10)],
                            Expanded(child: Text(item.label, style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? _kOrange : const Color(0xFF0f172a),
                            ))),
                            if (selected) const Icon(Icons.check, size: 14, color: _kOrange),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _close(fromDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLabel = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => DropdownItem<T>(value: widget.value, label: widget.hint ?? ''),
    ).label;

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.width ?? 120,
            maxWidth: widget.width ?? double.infinity,
          ),
          child: Container(
            height: widget.dense ? 40 : 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _open ? _kOrange : Colors.grey.shade300,
                width: _open ? 2.0 : 1.5,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  currentLabel.isEmpty ? (widget.hint ?? '') : currentLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: currentLabel.isEmpty ? Colors.grey : const Color(0xFF0f172a),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748b)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
