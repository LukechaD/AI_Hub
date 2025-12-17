import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../constants/app_colors.dart';

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);

  @override
  Widget? visitElement(md.Element element, TextStyle? preferredStyle) {
    String codeText = element.textContent;
    if (!codeText.contains('\n')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: kTermGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4)),
        child: Text(codeText,
            style:
                kTermStyle.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kTermGreen.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: kTermGreen.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8), topRight: Radius.circular(8))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CODE",
                    style: kTermStyle.copyWith(
                        fontSize: 12, color: kTermGreen.withOpacity(0.6))),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: codeText));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Copied!"),
                        duration: Duration(seconds: 1)));
                  },
                  child: const Row(children: [
                    Icon(Icons.copy, size: 14, color: kTermGreen),
                    SizedBox(width: 6),
                    Text("COPY",
                        style: TextStyle(
                            color: kTermGreen,
                            fontFamily: 'monospace',
                            fontSize: 12))
                  ]),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SelectableText(codeText,
                style: kTermStyle.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.4,
                    color: const Color(0xFFE0E0E0))),
          ),
        ],
      ),
    );
  }
}
