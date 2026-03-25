import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Full-screen page to add a mistake: what kind, why, how to prevent.
class AddMistakePage extends StatefulWidget {
  const AddMistakePage({
    super.key,
    required this.mistakesRef,
  });

  final CollectionReference<Map<String, dynamic>> mistakesRef;

  @override
  State<AddMistakePage> createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  final TextEditingController _whatController = TextEditingController();
  final TextEditingController _whyController = TextEditingController();
  final TextEditingController _howToPreventController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _whatController.dispose();
    _whyController.dispose();
    _howToPreventController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final what = _whatController.text.trim();
    if (what.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what kind of mistake it was.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.mistakesRef.add({
        'what': what,
        'why': _whyController.text.trim(),
        'howToPrevent': _howToPreventController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add mistake'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _whatController,
              decoration: const InputDecoration(
                labelText: 'What kind of mistake',
                hintText: 'e.g. Skipped a meeting, forgot a deadline',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _whyController,
              decoration: const InputDecoration(
                labelText: 'Why did you do it',
                hintText: 'e.g. Didn’t check calendar in the morning',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _howToPreventController,
              decoration: const InputDecoration(
                labelText: 'How to prevent it',
                hintText: 'e.g. Review calendar every morning',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}
