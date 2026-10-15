import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/workspace_repository.dart';

class WorkspaceAnnotationPanel extends StatefulWidget {
  const WorkspaceAnnotationPanel({
    super.key,
    required this.workspace,
    required this.recordingId,
  });

  final LocalWorkspace workspace;
  final String recordingId;

  @override
  State<WorkspaceAnnotationPanel> createState() =>
      _WorkspaceAnnotationPanelState();
}

class _WorkspaceAnnotationPanelState extends State<WorkspaceAnnotationPanel> {
  late final WorkspaceRepository _repository = WorkspaceRepository(
    widget.workspace,
  );
  late Future<List<Object>> _initial;
  final _sequence = TextEditingController(text: '1');
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _gloss = TextEditingController();
  final _translation = TextEditingController();
  final _language = TextEditingController(text: 'en');
  final _annotator = TextEditingController();
  final _notes = TextEditingController();
  String? _speakerId;
  String _boundary = 'pending';
  String _annotationStatus = 'draft';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initial = Future.wait<Object>([
      _repository.listAnnotations(widget.recordingId),
      _repository.listParticipants(limit: 1000),
    ]);
  }

  @override
  void dispose() {
    for (final controller in [
      _sequence,
      _start,
      _end,
      _gloss,
      _translation,
      _language,
      _annotator,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.saveAnnotation(
        recordingId: widget.recordingId,
        sequenceNo: int.parse(_sequence.text),
        startMs: int.tryParse(_start.text),
        endMs: int.tryParse(_end.text),
        boundaryStatus: _boundary,
        annotationStatus: _annotationStatus,
        participantId: _speakerId,
        gloss: _gloss.text,
        translation: _translation.text,
        languageTag: _language.text,
        annotatorLabel: _annotator.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      setState(() {
        _initial = Future.wait<Object>([
          _repository.listAnnotations(widget.recordingId),
          _repository.listParticipants(limit: 1000),
        ]);
        _sequence.text = '${(int.tryParse(_sequence.text) ?? 0) + 1}';
        _start.clear();
        _end.clear();
        _gloss.clear();
        _translation.clear();
        _notes.clear();
        _boundary = 'pending';
        _annotationStatus = 'draft';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotation saved in this workspace.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save annotation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
    future: _initial,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(
          'Annotations unavailable: ${snapshot.error}',
          style: const TextStyle(color: AppTheme.gold),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final segments = snapshot.data![0] as List<Map<String, dynamic>>;
      final participants = snapshot.data![1] as List<Map<String, dynamic>>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Utterance annotations',
            style: TextStyle(
              color: AppTheme.ivory,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add natural utterance boundaries and revise glosses or translations as needed. Times are milliseconds from the start of the video.',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 12),
          for (final segment in segments)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Utterance ${segment['sequence_no']} · ${segment['start_ms'] ?? '?'}–${segment['end_ms'] ?? '?'} ms · ${segment['boundary_status']}',
                    style: const TextStyle(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final speaker in segment['speakers'] as List)
                    Text(
                      'Speaker: ${speaker['display_label'] ?? 'Unknown'}',
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                  for (final entry in segment['annotations'] as List)
                    Text(
                      '${entry['annotation_kind']}: ${entry['text']} (${entry['status']})',
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                  if ((segment['notes'] as String?)?.isNotEmpty == true)
                    Text(
                      'Note: ${segment['notes']}',
                      style: const TextStyle(color: AppTheme.mutedText),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _sequence,
                        'Utterance number',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        _start,
                        'Start ms (optional)',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_end, 'End ms (optional)', numeric: true),
                    ),
                  ],
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _speakerId,
                  decoration: const InputDecoration(
                    labelText: 'Speaker (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unknown / not assigned'),
                    ),
                    ...participants.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p['id'] as String,
                        child: Text('${p['signer_id']} · ${p['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _speakerId = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _boundary,
                  decoration: const InputDecoration(
                    labelText: 'Boundary confidence',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'uncertain',
                      child: Text('Uncertain'),
                    ),
                    DropdownMenuItem(
                      value: 'validated',
                      child: Text('Validated'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _boundary = value ?? 'pending'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _annotationStatus,
                  decoration: const InputDecoration(
                    labelText: 'Annotation status',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'uncertain',
                      child: Text('Uncertain'),
                    ),
                    DropdownMenuItem(
                      value: 'validated',
                      child: Text('Validated'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _annotationStatus = value ?? 'draft'),
                ),
                _field(_gloss, 'Gloss (optional)'),
                _field(_translation, 'Translation (optional)'),
                _field(_language, 'Translation language tag'),
                _field(_annotator, 'Annotator label (optional)'),
                _field(
                  _notes,
                  'Uncertainty or annotation note (optional)',
                  lines: 2,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Saving…' : 'Save annotation'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      maxLines: lines,
      style: const TextStyle(color: AppTheme.ivory),
      decoration: InputDecoration(labelText: label),
    ),
  );
}
