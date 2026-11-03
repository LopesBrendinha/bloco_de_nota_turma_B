import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Painel inferior para escolher a ordenação por data.
Future<NoteSort?> showSortSheet(BuildContext context, NoteSort current) {
  return showModalBottomSheet<NoteSort>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SortSheet(current: current),
  );
}

class _SortSheet extends StatefulWidget {
  const _SortSheet({required this.current});

  final NoteSort current;

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late SortField field = widget.current.field;
  late bool newestFirst = widget.current.newestFirst;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ordenar notas', style: AppTheme.display(context, size: 24)),
            const SizedBox(height: 4),
            Text(
              'a lista é agrupada pela data escolhida',
              style: AppTheme.handwritten(context, size: 19),
            ),
            const SizedBox(height: 18),
            _Label('Por data de'),
            RadioGroup<SortField>(
              groupValue: field,
              onChanged: (value) => setState(() => field = value!),
              child: Column(
                children: [
                  for (final option in SortField.values)
                    RadioListTile<SortField>(
                      contentPadding: EdgeInsets.zero,
                      value: option,
                      activeColor: Theme.of(context).colorScheme.onSurface,
                      title: Text(option.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Label('Ordem'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: GrafiteColors.highlighter,
                selectedForegroundColor: GrafiteColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.south_rounded),
                  label: Text('Recentes primeiro'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.north_rounded),
                  label: Text('Antigas primeiro'),
                ),
              ],
              selected: {newestFirst},
              onSelectionChanged: (value) =>
                  setState(() => newestFirst = value.first),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                NoteSort(field: field, newestFirst: newestFirst),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
