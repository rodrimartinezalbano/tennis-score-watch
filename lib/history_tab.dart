import 'package:flutter/material.dart';

import 'match_log.dart';
import 'match_progress.dart';
import 'score_audio_handler.dart';

/// Partidos guardados. Tocar uno abre su detalle; deslizarlo lo borra.
class HistoryTab extends StatelessWidget {
  const HistoryTab({required this.handler, super.key});

  final ScoreAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    // También escucha el partido actual para saber cuál está "En juego".
    return ListenableBuilder(
      listenable: Listenable.merge([handler.log.records, handler.match]),
      builder: (context, _) {
        final records = handler.log.records.value;
        final currentId = handler.startedAt.millisecondsSinceEpoch;
        if (records.isEmpty) {
          return const Center(child: Text('Todavía no hay partidos.'));
        }
        return ListView.separated(
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final record = records[i];
            final status = _status(record, isCurrent: record.id == currentId);
            return Dismissible(
              key: ValueKey(record.id),
              direction: DismissDirection.endToStart,
              background: ColoredBox(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: 24),
                    child: Icon(Icons.delete),
                  ),
                ),
              ),
              onDismissed: (_) => handler.log.delete(record),
              child: ListTile(
                title: Text(record.match.resultLabel),
                subtitle: Text('${formatDate(record.startedAt)} · $status'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MatchDetailPage(record: record, status: status),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _status(MatchRecord record, {required bool isCurrent}) {
    final match = record.match;
    if (match.isOver) {
      return match.mySets > match.rivalSets ? 'Ganaste' : 'Perdiste';
    }
    return isCurrent ? 'En juego' : 'Sin terminar';
  }
}

class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({
    required this.record,
    required this.status,
    super.key,
  });

  final MatchRecord record;
  final String status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final match = record.match;
    return Scaffold(
      appBar: AppBar(title: Text(formatDate(record.startedAt))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(match.resultLabel, style: text.headlineMedium),
            const SizedBox(height: 4),
            Text('$status · ${rulesLabel(match)}', style: text.labelLarge),
            if (outcomeLabel(match).isNotEmpty)
              Text(outcomeLabel(match), style: text.labelLarge),
            const SizedBox(height: 16),
            Expanded(child: MatchProgress(match: match)),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)} '
      '${two(date.hour)}:${two(date.minute)}';
}
