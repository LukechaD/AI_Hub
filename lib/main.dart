import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'constants/app_colors.dart';
import 'providers/chat_provider.dart';
import 'ui/screens/terminal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1300, 850),
      minimumSize: Size(400, 600),
      center: true,
      backgroundColor: kTermBlack,
      title: "AI > Terminal",
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ChatProvider())],
      child: const CyberTerminalApp(),
    ),
  );
}

class CyberTerminalApp extends StatelessWidget {
  const CyberTerminalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kTermBlack,
          fontFamily: 'monospace',
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
              primary: kTermGreen, surface: kTermBlack, onSurface: kTermGreen),
          scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(kTermGreen.withOpacity(0.5)),
              thickness: WidgetStateProperty.all(4))),
      home: const TerminalScreen(),
    );
  }
}
