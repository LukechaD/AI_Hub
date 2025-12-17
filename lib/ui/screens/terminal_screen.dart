import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/terminal_message.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _attachedImage;
  String _selectedFamily = 'Google';
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkInitialRequirements());
  }

  void _checkInitialRequirements() async {
    final provider = context.read<ChatProvider>();
    final family = provider.getModelFamily(provider.selectedModel);
    setState(() {
      _selectedFamily = family;
    });
    // Перевірка оновлень при старті
    _checkForUpdates();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _attachedImage = result.files.single.path);
    }
  }

  void _onDragDone(DropDoneDetails details) {
    if (details.files.isNotEmpty) {
      final file = details.files.first;
      final ext = file.path.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
        setState(() => _attachedImage = file.path);
      }
    }
  }

  // ==========================================
  // ЛОГІКА ОНОВЛЕННЯ (ПРОСТА ВЕРСІЯ)
  // ==========================================
  Future<void> _checkForUpdates() async {
    // Впиши сюди свій GitHub
    const String userName = "Dmytro10101";
    const String repoName = "ai_hub_flutter";

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/$userName/$repoName/releases/latest'));

      if (response.statusCode == 200) {
        final releaseData = jsonDecode(utf8.decode(response.bodyBytes));
        String latestVersion =
            releaseData['tag_name'].toString().replaceAll('v', '');
        String url = releaseData['html_url']; // Посилання на сторінку релізу

        if (latestVersion != currentVersion) {
          _showUpdateDialog(currentVersion, latestVersion, url);
        }
      }
    } catch (e) {
      debugPrint("Update check error: $e");
    }
  }

  void _showUpdateDialog(String current, String latest, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTermDarkGrey,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: kTermGreen),
            borderRadius: BorderRadius.circular(12)),
        title: const Text("UPDATE AVAILABLE", style: kTermStyle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Current: $current",
                style: const TextStyle(color: Colors.grey)),
            Text("Latest:  $latest",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              "A new version is available on GitHub.\nClick DOWNLOAD to get the file for your OS.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("LATER",
                  style:
                      TextStyle(color: Colors.grey, fontFamily: 'monospace'))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: const Text("DOWNLOAD", style: kTermStyle)),
        ],
      ),
    );
  }
  // ==========================================

  void _showAPISettings(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final keyControllers = <String, TextEditingController>{};
    for (final family in LLM_FAMILIES) {
      final existing = provider.apiConfigs[family.name];
      keyControllers[family.name] =
          TextEditingController(text: existing?.apiKey ?? '');
    }
    showDialog(
      context: context,
      barrierColor: kTermBlack.withOpacity(0.9),
      builder: (ctx) => AlertDialog(
        backgroundColor: kTermDarkGrey,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: kTermGreen),
            borderRadius: BorderRadius.circular(12)),
        title: const Text("SYSTEM CONFIG // API KEYS", style: kTermStyle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LLM_FAMILIES
                .map((family) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: keyControllers[family.name],
                        obscureText: true,
                        style: const TextStyle(
                            color: Colors.white, fontFamily: 'monospace'),
                        cursorColor: kTermGreen,
                        decoration: InputDecoration(
                          labelText: family.name.toUpperCase(),
                          labelStyle: TextStyle(
                              color: kTermGreen.withOpacity(0.7),
                              fontFamily: 'monospace'),
                          filled: true,
                          fillColor: Colors.black,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: kTermGreen.withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kTermGreen)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              child: const Text("[ CHECK UPDATES ]",
                  style: TextStyle(
                      color: Colors.blueAccent, fontFamily: 'monospace')),
              onPressed: () {
                Navigator.pop(ctx);
                _checkForUpdates();
              }),
          TextButton(
              child: const Text("[ SAVE ]", style: kTermStyle),
              onPressed: () {
                keyControllers.forEach((name, ctrl) {
                  if (ctrl.text.isNotEmpty) {
                    context
                        .read<ChatProvider>()
                        .saveAPIKey(name, ctrl.text.trim());
                  }
                });
                Navigator.pop(ctx);
              })
        ],
      ),
    );
  }

  Widget _buildEmbeddedDropdown(
      BuildContext context, ChatProvider provider, bool isSmallScreen) {
    String display = provider.selectedModel;
    for (var fam in LLM_FAMILIES) {
      for (var m in fam.models) {
        if (m.id == provider.selectedModel) display = m.displayName;
      }
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: kTermDarkGrey,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.selectedModel,
          icon: const Icon(Icons.arrow_drop_down, color: kTermGreen),
          style: kTermStyle,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: kTermDarkGrey,
          onChanged: (String? newValue) {
            if (newValue != null) {
              provider.selectModel(newValue);
              final newFamily = provider.getModelFamily(newValue);
              if (newFamily != _selectedFamily) {
                setState(() => _selectedFamily = newFamily);
              }
            }
          },
          selectedItemBuilder: (BuildContext context) {
            return _buildDropdownItems(provider).map<Widget>((item) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  display,
                  style: kTermStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 13 : 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList();
          },
          items: _buildDropdownItems(provider),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(ChatProvider provider) {
    List<DropdownMenuItem<String>> items = [];
    final family = LLM_FAMILIES.firstWhere((f) => f.name == _selectedFamily,
        orElse: () => LLM_FAMILIES[0]);
    for (var model in family.models) {
      items.add(DropdownMenuItem<String>(
        value: model.id,
        child: Text(model.displayName, style: kTermStyle),
      ));
    }
    return items;
  }

  Widget _buildInputField(double screenWidth) {
    final provider = context.watch<ChatProvider>();
    bool isSmallScreen = screenWidth < 800;
    double dropdownWidth =
        isSmallScreen ? (screenWidth * 0.30).clamp(80.0, 140.0) : 160.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_attachedImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 10),
            child: Row(children: [
              const Icon(Icons.attach_file, color: kTermGreen, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text("img: ${_attachedImage!.split('/').last}",
                    style: TextStyle(
                        color: kTermGreen.withOpacity(0.7), fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              InkWell(
                  onTap: () => setState(() => _attachedImage = null),
                  child: const Icon(Icons.close, color: Colors.red, size: 16))
            ]),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
              color: kTermBlack,
              border: Border.all(color: kTermGreen, width: 2.0),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: kTermGreen.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1),
              ]),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: dropdownWidth,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 50,
                decoration: const BoxDecoration(
                    border: Border(
                        right: BorderSide(color: kTermDivider, width: 1))),
                child: Center(
                    child: _buildEmbeddedDropdown(
                        context, provider, isSmallScreen)),
              ),
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): () =>
                        _sendMessage(),
                  },
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: kTermStyle.copyWith(
                        color: Colors.white, fontSize: 16, height: 1.3),
                    cursorColor: kTermGreen,
                    maxLines: 6,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: isSmallScreen
                          ? "> ..."
                          : "> Enter query... (Shift+Enter for line)",
                      hintStyle: TextStyle(
                          color: kTermGreen.withOpacity(0.3),
                          fontFamily: 'monospace',
                          fontSize: isSmallScreen ? 14 : 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      isDense: true,
                    ),
                    onChanged: (text) {},
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_outlined, color: kTermGreen),
                      onPressed: _pickImage,
                      tooltip: "Attach Image",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.send, color: kTermGreen),
                      onPressed: _sendMessage,
                      tooltip: "Send",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() async {
    final provider = context.read<ChatProvider>();
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImage == null) return;
    _textController.clear();
    final imgPath = _attachedImage;
    setState(() => _attachedImage = null);
    _focusNode.requestFocus();
    await provider.sendMessage(text, imagePath: imgPath);
  }

  Widget _buildSidebarContent(ChatProvider provider) {
    return Container(
      width: 260,
      color: kTermBlack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 10, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("AI > Terminal",
                    style: TextStyle(
                        color: kTermGreen,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add, color: kTermGreen, size: 28),
                  onPressed: () => provider.startNewChat(),
                  tooltip: "New Session",
                ),
              ],
            ),
          ),
          Divider(color: kTermGreyLine, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: provider.chatSessions.length,
              itemBuilder: (ctx, index) {
                final session = provider.chatSessions[index];
                final isActive = provider.currentSession?.id == session.id;
                String title =
                    session.title.isEmpty ? "New Session" : session.title;
                if (title.length > 25) title = "${title.substring(0, 25)}...";

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: isActive
                      ? BoxDecoration(
                          color: kTermGreen.withOpacity(0.1),
                          border: const Border(
                              left: BorderSide(color: kTermGreen, width: 3)))
                      : null,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(title,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontFamily: 'monospace',
                            fontSize: 15)),
                    onTap: () {
                      provider.loadSession(session);
                      if (Scaffold.of(ctx).hasDrawer &&
                          Scaffold.of(ctx).isDrawerOpen) {
                        Navigator.pop(ctx);
                      }
                    },
                    trailing: isActive
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.redAccent),
                            onPressed: () => provider.deleteSession(session.id),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    final double sidePadding = isMobile ? 10 : 40;

    Widget mainContent = Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: kTermGreen),
                    borderRadius: BorderRadius.circular(8),
                    color: kTermBlack,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (screenWidth > 400)
                        Text("FAMILY: ",
                            style: kTermStyle.copyWith(
                                color: Colors.grey, fontSize: 13)),
                      Flexible(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFamily,
                            dropdownColor: kTermDarkGrey,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: kTermGreen),
                            style: kTermStyle,
                            isDense: true,
                            isExpanded: false,
                            borderRadius: BorderRadius.circular(12),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedFamily = val;
                                  final first = LLM_FAMILIES
                                      .firstWhere((f) => f.name == val)
                                      .models
                                      .first
                                      .id;
                                  provider.selectModel(first);
                                });
                              }
                            },
                            items: LLM_FAMILIES
                                .map((f) => DropdownMenuItem(
                                      value: f.name,
                                      child: Text(
                                        f.name.toUpperCase(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: kTermGreen, size: 28),
                onPressed: () => _showAPISettings(context),
                tooltip: "Config",
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: SelectionArea(
              child: provider.currentSession == null
                  ? const Center(
                      child: Text("wake_the_f...up_samurai",
                          style: TextStyle(
                              color: Color(0xFF333333), fontSize: 20)))
                  : ListView.builder(
                      reverse: true,
                      padding:
                          EdgeInsets.fromLTRB(sidePadding, 20, sidePadding, 20),
                      itemCount: provider.messages.length,
                      itemBuilder: (ctx, index) {
                        final msg = provider.messages[index];
                        return TerminalMessage(message: msg);
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(sidePadding, 10, sidePadding, 20),
          child: _buildInputField(screenWidth),
        ),
      ],
    );

    Widget body;
    if (isMobile) {
      body = Scaffold(
        appBar: AppBar(
          backgroundColor: kTermBlack,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: kTermGreen),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text("AI > Terminal",
              style: TextStyle(color: kTermGreen, fontFamily: 'monospace')),
          centerTitle: true,
        ),
        drawer: Drawer(
          child: _buildSidebarContent(provider),
        ),
        body: mainContent,
      );
    } else {
      body = Scaffold(
        body: Column(
          children: [
            const CustomTitleBar(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebarContent(provider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: VerticalDivider(
                        width: 1, thickness: 1, color: kTermGreyLine),
                  ),
                  Expanded(child: mainContent),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return DropTarget(
        onDragDone: _onDragDone,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            body,
            if (_isDragging)
              Container(
                color: kTermBlack.withOpacity(0.9),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, color: kTermGreen, size: 60),
                      SizedBox(height: 20),
                      Text("DROP TO ATTACH",
                          style: TextStyle(
                              color: kTermGreen,
                              fontSize: 24,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      return body;
    }
  }
}
