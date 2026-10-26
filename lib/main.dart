import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_tab.dart';
import 'match_log.dart';
import 'match_progress.dart';
import 'score_audio_handler.dart';
import 'tennis_match.dart';
import 'watch_link.dart';
import 'watch_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = MatchLog(await SharedPreferences.getInstance());
  final watch = WatchLink();
  final handler = await AudioService.init(
    builder: () => ScoreAudioHandler(log, watch),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.rodrigo.tennis_score_poc.score',
      androidNotificationChannelName: 'Marcador de tenis',
      androidNotificationOngoing: true,
    ),
  );
  await handler.start();
  // Si ya hay MAC y clave guardadas, se conecta solo al abrir la app.
  final saved = await watch.savedCredentials();
  if (saved.mac.isNotEmpty && saved.hasKey) await watch.connect();
  runApp(App(handler: handler));
}

class App extends StatelessWidget {
  const App({required this.handler, super.key});

  final ScoreAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tenis Score',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: HomePage(handler: handler),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({required this.handler, super.key});

  final ScoreAudioHandler handler;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _tab = 0;

  Future<void> _startNewMatch() async {
    final fresh = await showDialog<TennisMatch>(
      context: context,
      builder: (_) => NewMatchDialog(current: widget.handler.match.value),
    );
    if (fresh == null) return;
    await widget.handler.newMatch(fresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenis Score'),
        actions: [
          // Verde cuando el reloj está conectado.
          ValueListenableBuilder<WatchStatus>(
            valueListenable: widget.handler.watch.status,
            builder: (context, status, _) => IconButton(
              tooltip: 'Reloj',
              icon: Icon(
                Icons.watch,
                color: status == WatchStatus.connected ? Colors.green : null,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WatchPage(watch: widget.handler.watch),
                ),
              ),
            ),
          ),
          if (_tab == 0)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo partido'),
              onPressed: _startNewMatch,
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          LiveMatchTab(handler: widget.handler),
          HistoryTab(handler: widget.handler),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_tennis),
            label: 'Partido',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

/// Marcador, botones de prueba y el desarrollo del partido actual.
class LiveMatchTab extends StatelessWidget {
  const LiveMatchTab({required this.handler, super.key});

  final ScoreAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<TennisMatch>(
      valueListenable: handler.match,
      builder: (context, m, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(m.watchTitle, style: text.headlineMedium),
                    const SizedBox(height: 8),
                    Text(m.watchSubtitle, style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      [
                        rulesLabel(m),
                        if (m.servingMine case final mine?)
                          mine ? 'Saco yo' : 'Saca el rival',
                      ].join(' · '),
                      style: text.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (outcomeLabel(m).isNotEmpty)
                      Text(outcomeLabel(m), style: text.labelLarge),
                    ValueListenableBuilder<int?>(
                      valueListenable: handler.watch.heartRate,
                      builder: (context, bpm, _) => bpm == null
                          ? const SizedBox.shrink()
                          : Text('❤ $bpm lpm', style: text.labelLarge),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              m.needsServer
                  ? '¿Quién saca? En el reloj: ⏭ yo · ⏮ el rival'
                  : 'En el reloj: ⏭ punto mío · ⏮ punto rival\n'
                        '⏯ 2do saque · ⏯⏯ (doble toque) deshacer\n'
                        'Vol + ganador · Vol − error no forzado (del último punto)',
              textAlign: TextAlign.center,
              style: m.needsServer ? text.titleMedium : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: handler.skipToPrevious,
                    child: Text(
                      m.needsServer ? 'Saca el rival' : 'Punto rival',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Deshacer',
                  onPressed: m.canUndo ? handler.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                const SizedBox(width: 8),
                // Se ve "apretado" mientras el próximo punto va con 2do saque.
                IconButton(
                  tooltip: '2do saque',
                  isSelected: m.secondServe,
                  style: IconButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  onPressed: m.isOver || m.needsServer
                      ? null
                      : handler.toggleSecondServe,
                  icon: const Text('2S'),
                  selectedIcon: const Text(
                    '2S',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: handler.skipToNext,
                    child: Text(m.needsServer ? 'Saco yo' : 'Punto mío'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Desarrollo del partido', style: text.titleSmall),
            const SizedBox(height: 8),
            Expanded(child: MatchProgress(match: m)),
          ],
        ),
      ),
    );
  }
}

/// Configura el partido nuevo, arrancando con las opciones del actual.
/// Devuelve el partido a empezar, o `null` si se cancela.
class NewMatchDialog extends StatefulWidget {
  const NewMatchDialog({required this.current, super.key});

  final TennisMatch current;

  @override
  State<NewMatchDialog> createState() => _NewMatchDialogState();
}

class _NewMatchDialogState extends State<NewMatchDialog> {
  late bool _goldenPoint = widget.current.goldenPoint;
  late bool _superTieBreak = widget.current.superTieBreak;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo partido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Punto de oro'),
            subtitle: const Text('A 40-40, el que gana el punto gana el game.'),
            value: _goldenPoint,
            onChanged: (value) => setState(() => _goldenPoint = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Super tie-break en el 3er set'),
            subtitle: const Text(
              'A 10 puntos. A 9-9, el que gana el punto gana el partido.',
            ),
            value: _superTieBreak,
            onChanged: (value) => setState(() => _superTieBreak = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            TennisMatch(
              goldenPoint: _goldenPoint,
              superTieBreak: _superTieBreak,
            ),
          ),
          child: const Text('Empezar'),
        ),
      ],
    );
  }
}
