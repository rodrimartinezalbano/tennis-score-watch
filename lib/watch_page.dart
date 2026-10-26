import 'package:flutter/material.dart';

import 'watch_link.dart';

/// Datos para conectar con el reloj, estado de la conexión y lo último que
/// llegó del reloj (botón y pulso).
class WatchPage extends StatefulWidget {
  const WatchPage({required this.watch, super.key});

  final WatchLink watch;

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  final _mac = TextEditingController();
  final _key = TextEditingController();
  var _hasKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.watch.savedCredentials();
    if (!mounted) return;
    setState(() {
      _mac.text = saved.mac;
      _hasKey = saved.hasKey;
    });
  }

  @override
  void dispose() {
    _mac.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    await widget.watch.saveCredentials(mac: _mac.text, key: _key.text);
    _key.clear();
    await widget.watch.disconnect();
    await widget.watch.connect();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final watch = widget.watch;
    return Scaffold(
      appBar: AppBar(title: const Text('Reloj')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([watch.status, watch.statusDetail]),
            builder: (context, _) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.watch,
                  color: watch.status.value == WatchStatus.connected
                      ? Colors.green
                      : null,
                ),
                title: Text(_statusLabel(watch.status.value)),
                subtitle: watch.statusDetail.value == null
                    ? null
                    : Text(watch.statusDetail.value!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La app se conecta directo con el reloj, sin Mi Fitness. '
            'Mi Fitness tiene que estar desactivada o cerrada: el reloj atiende '
            'una sola app a la vez.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mac,
            decoration: const InputDecoration(
              labelText: 'Dirección MAC',
              hintText: 'XX:XX:XX:XX:XX:XX',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Clave de autorización',
              hintText: _hasKey
                  ? 'Guardada (dejala vacía para no cambiarla)'
                  : '32 caracteres (encryptKey de Mi Fitness)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveAndConnect,
            child: const Text('Guardar y conectar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: watch.disconnect,
            child: const Text('Desconectar'),
          ),
          const SizedBox(height: 24),
          Text('Desde el reloj', style: text.titleSmall),
          ValueListenableBuilder<WatchButton?>(
            valueListenable: watch.lastButton,
            builder: (context, button, _) => Text(
              'Último botón: ${button == null ? '—' : _buttonLabel(button)}',
            ),
          ),
          ValueListenableBuilder<int?>(
            valueListenable: watch.heartRate,
            builder: (context, bpm, _) =>
                Text('Pulso: ${bpm == null ? '—' : '$bpm lpm'}'),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(WatchStatus status) => switch (status) {
    WatchStatus.disconnected => 'Desconectado',
    WatchStatus.connecting => 'Conectando…',
    WatchStatus.authenticating => 'Autorizando…',
    WatchStatus.connected => 'Conectado',
  };

  static String _buttonLabel(WatchButton button) => switch (button) {
    WatchButton.play => '▶ Play',
    WatchButton.pause => '⏸ Pausa',
    WatchButton.previous => '⏮ Anterior',
    WatchButton.next => '⏭ Siguiente',
    WatchButton.volumeUp => 'Vol +',
    WatchButton.volumeDown => 'Vol −',
  };
}
