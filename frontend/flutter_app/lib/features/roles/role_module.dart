import "package:flutter/material.dart";

class RoleModule {
  RoleModule({
    required this.key,
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String key;
  final String title;
  final IconData icon;
  final Widget Function() builder;
}