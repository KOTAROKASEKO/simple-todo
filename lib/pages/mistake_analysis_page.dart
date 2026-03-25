import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Full-screen page to view a single AI mistake analysis rendered as Markdown.
/// Open from the Mistakes tab drawer (history) or after tapping AI — then runs
/// analysis and shows loading until done.
class MistakeAnalysisPage extends StatefulWidget {
  const MistakeAnalysisPage({
    super.key,
    required this.analysesRef,
    this.initialAnalysisId,
    this.pendingMistakes,
  });

  final CollectionReference<Map<String, dynamic>> analysesRef;
  /// When opening from drawer, pass the analysis doc id to show.
  final String? initialAnalysisId;
  /// When opening from AI FAB, pass the list of mistakes; page will call AI and show loading.
  final List<Map<String, dynamic>>? pendingMistakes;

  @override
  State<MistakeAnalysisPage> createState() => _MistakeAnalysisPageState();
}

class _MistakeAnalysisPageState extends State<MistakeAnalysisPage> {
  String? _analysisId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialAnalysisId != null) {
      _analysisId = widget.initialAnalysisId;
    } else if (widget.pendingMistakes != null) {
      _runAnalysis();
    }
  }

  Future<void> _runAnalysis() async {
    final mistakes = widget.pendingMistakes!;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('analyzeMistakes')
          .call(<String, dynamic>{'mistakes': mistakes});
      if (!mounted) return;
      final data = result.data;
      String analysis;
      if (data is Map && data['analysis'] is String) {
        analysis = data['analysis'] as String;
      } else {
        analysis = 'No analysis text returned from AI.';
      }
      final docRef = await widget.analysesRef.add({
        'content': analysis,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _analysisId = docRef.id;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text(
            'AI analysis',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          iconTheme: IconThemeData(color: Colors.grey.shade700),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Analysis failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_analysisId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text(
            'AI analysis',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          iconTheme: IconThemeData(color: Colors.grey.shade700),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing mistakes...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'AI analysis',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.analysesRef.doc(_analysisId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This analysis could not be found.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
            );
          }
          final content = doc.data()?['content'] is String
              ? doc.data()!['content'] as String
              : '';
          return SafeArea(
            child: Markdown(
              data: content.isEmpty ? '_No content_' : content,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Colors.grey.shade800,
                ),
                h1: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
                h2: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                h3: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                listBullet: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
                blockquote: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
