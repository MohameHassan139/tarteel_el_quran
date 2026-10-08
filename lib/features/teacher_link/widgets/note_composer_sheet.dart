import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';

/// Bottom sheet for writing a note to a student, with one-tap templates.
/// [onSend] returns true when the note was delivered (sheet then closes).
Future<void> showNoteComposerSheet({
  required BuildContext context,
  required String studentName,
  required Future<bool> Function(String text) onSend,
  String initialText = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NoteComposerSheet(
      studentName: studentName,
      initialText: initialText,
      onSend: onSend,
    ),
  );
}

const List<String> kNoteTemplateKeys = [
  'student_tpl_great',
  'student_tpl_review',
  'student_tpl_ward',
  'student_tpl_miss',
];

class _NoteComposerSheet extends StatefulWidget {
  final String studentName;
  final String initialText;
  final Future<bool> Function(String text) onSend;

  const _NoteComposerSheet({
    required this.studentName,
    required this.initialText,
    required this.onSend,
  });

  @override
  State<_NoteComposerSheet> createState() => _NoteComposerSheetState();
}

class _NoteComposerSheetState extends State<_NoteComposerSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(_text.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  void _applyTemplate(String key) {
    final tpl = key.tr;
    final current = _text.text;
    final next = current.trim().isEmpty ? tpl : '${current.trimRight()} $tpl';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[500], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.studentName.isEmpty
                          ? 'teacher_link_write_note_title'.tr
                          : '${'teacher_link_write_note_title'.tr} • ${widget.studentName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('student_note_templates'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kNoteTemplateKeys
                    .map((k) => ActionChip(
                          label: Text(k.tr, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                          onPressed: () => _applyTemplate(k),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _text,
                autofocus: widget.initialText.isNotEmpty,
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'teacher_link_note_hint'.tr,
                  filled: true,
                  fillColor: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text('teacher_link_send_note'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
