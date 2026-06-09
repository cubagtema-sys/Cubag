import 'package:flutter/material.dart';

/// Mobile bottom navigation shell for regular (non-admin) members.
/// We have now migrated this into AppLayout directly, so this acts
/// as a simple pass-through to avoid breaking router dependencies.
class UserShell extends StatelessWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
