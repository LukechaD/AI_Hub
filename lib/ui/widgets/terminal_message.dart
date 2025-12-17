import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../constants/app_colors.dart';
import '../../models/chat_models.dart';
import 'markdown_builders.dart';

class TerminalMessage extends StatelessWidget {
  final ChatMessage message;
  const TerminalMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.imagePath != null)
            Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: kTermGreen.withOpacity(0.5))),
                child: Image.file(File(message.imagePath!), height: 200)),
          if (isUser)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                  child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: kTermDarkGrey,
                          border:
                              Border.all(color: kTermGreen.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(message.text,
                          style: kTermStyle.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 16,
                              height: 1.4)))),
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(right: 12.0, top: 6.0),
                  child: Text(">",
                      style: TextStyle(
                          color: kTermGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))),
              Expanded(
                  child: message.isFinal
                      ? MarkdownBody(
                          data: message.text,
                          builders: {
                            'code': CodeElementBuilder(context),
                            'pre': CodeElementBuilder(context)
                          },
                          styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: kTermGreen,
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  height: 1.5),
                              code: const TextStyle(
                                  backgroundColor: Colors.transparent,
                                  fontFamily: 'monospace'),
                              codeblockDecoration: const BoxDecoration(
                                  color: Colors.transparent)))
                      : Text(message.text,
                          style: const TextStyle(
                              color: kTermGreen,
                              fontFamily: 'monospace',
                              fontSize: 16))),
            ]),
        ],
      ),
    );
  }
}
