import 'package:flutter/material.dart';

/// Shared responsive avatar displaying capital first grapheme of name,
/// falling back to email first grapheme, or a person icon.
class InitialAvatar extends StatelessWidget {
  final String name;
  final String? email;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;

  const InitialAvatar({
    super.key,
    required this.name,
    this.email,
    this.radius = 24.0,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
  });

  String? _getInitial() {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName.characters.first.toUpperCase();
    }
    final trimmedEmail = email?.trim() ?? '';
    if (trimmedEmail.isNotEmpty) {
      return trimmedEmail.characters.first.toUpperCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF0F8780); // kMboisTeal
    final fg = foregroundColor ?? Colors.white;
    final initial = _getInitial();

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: initial != null
          ? Padding(
              padding: EdgeInsets.all(radius * 0.15),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initial,
                  style:
                      textStyle ??
                      TextStyle(
                        color: fg,
                        fontSize: radius * 0.9,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                ),
              ),
            )
          : Icon(Icons.person, size: radius * 1.1, color: fg),
    );
  }
}
