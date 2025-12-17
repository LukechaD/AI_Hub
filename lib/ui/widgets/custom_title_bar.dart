import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../constants/app_colors.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});
  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 36,
      color: kTermBlack,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Text("AI > Terminal",
              style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          Expanded(
              child:
                  DragToMoveArea(child: Container(color: Colors.transparent))),
          _WindowButton(
              icon: Icons.remove,
              onPressed: () async => await windowManager.minimize()),
          _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              }),
          _WindowButton(
              icon: Icons.close,
              onPressed: () async => await windowManager.close(),
              isClose: true),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  const _WindowButton(
      {required this.icon, required this.onPressed, this.isClose = false});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red : Colors.white.withOpacity(0.1),
        child: Container(
            width: 46,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: Colors.white)),
      ),
    );
  }
}
