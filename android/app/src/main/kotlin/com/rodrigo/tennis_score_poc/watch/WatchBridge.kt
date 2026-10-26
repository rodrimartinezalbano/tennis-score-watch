package com.rodrigo.tennis_score_poc.watch

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.Calendar
import java.util.GregorianCalendar

/**
 * Conexión directa con el Redmi Watch 5 Lite, sin Mi Fitness.
 *
 * Autentica con la clave del reloj, le manda la hora y el marcador como "canción" de la
 * pantalla de música, y avisa cada botón que se toca en esa pantalla. Si se corta, reintenta
 * solo mientras haya una conexión pedida.
 */
@SuppressLint("StaticFieldLeak") // Guarda el applicationContext, que vive lo mismo que el proceso.
object WatchBridge {
    private const val TAG = "WatchBridge"
    private const val PREFS = "watch"
    private const val KEY_MAC = "mac"
    private const val KEY_AUTH = "auth_key"

    private const val TYPE_MUSIC = 18
    private const val MUSIC_REQUEST_INFO = 0
    private const val MUSIC_INFO = 1
    private const val MUSIC_MEDIA_KEY = 2
    private const val HEALTH_REALTIME_EVENT = 47

    /** Botones de la pantalla de música del reloj. */
    enum class Button { PLAY, PAUSE, PREVIOUS, NEXT, VOLUME_UP, VOLUME_DOWN }

    enum class Status { DISCONNECTED, CONNECTING, AUTHENTICATING, CONNECTED }

    interface Listener {
        fun onStatus(status: Status, detail: String?)
        fun onButton(button: Button)
        fun onHeartRate(bpm: Int)
    }

    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())
    var listener: Listener? = null

    @Volatile var status = Status.DISCONNECTED
        private set

    /** true mientras el usuario quiere estar conectado: habilita los reintentos. */
    @Volatile private var wanted = false
    @Volatile private var attempt = 0
    private var retryDelayMs = 3_000L
    private var connection: SppConnection? = null
    private var protocol: ProtocolHandler? = null

    private var title = ""
    private var artist = ""

    fun init(context: Context) {
        this.context = context.applicationContext
    }

    private val prefs get() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    val savedMac: String get() = prefs.getString(KEY_MAC, "") ?: ""
    val hasSavedKey: Boolean get() = !prefs.getString(KEY_AUTH, "").isNullOrBlank()

    /** Guarda la MAC y, si no está vacía, la clave. La clave nunca vuelve a Dart. */
    fun saveCredentials(mac: String, authKey: String?) {
        prefs.edit().apply {
            putString(KEY_MAC, mac.trim().uppercase())
            if (!authKey.isNullOrBlank()) putString(KEY_AUTH, authKey.trim())
        }.apply()
    }

    fun connect() {
        val mac = savedMac
        val key = prefs.getString(KEY_AUTH, "") ?: ""
        if (mac.isBlank() || key.isBlank()) {
            setStatus(Status.DISCONNECTED, "Faltan la MAC o la clave")
            return
        }
        wanted = true
        retryDelayMs = 3_000L
        startAttempt(mac, key)
    }

    fun disconnect() {
        wanted = false
        attempt++
        teardown()
        setStatus(Status.DISCONNECTED, null)
    }

    /** Lo que muestra el reloj en la pantalla de música. */
    fun setScore(title: String, artist: String) {
        this.title = title
        this.artist = artist
        if (status == Status.CONNECTED) sendMusicInfo()
    }

    private fun startAttempt(mac: String, key: String) {
        if (status != Status.DISCONNECTED) return
        val myAttempt = ++attempt
        setStatus(Status.CONNECTING, null)
        Thread({
            var handler: ProtocolHandler? = null
            val spp = SppConnection(
                onData = { data -> handler?.onDataReceived(data) },
                onDisconnected = { onDrop(myAttempt) },
            )
            try {
                val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
                val ok = adapter != null && spp.connect(adapter.getRemoteDevice(mac))
                if (myAttempt != attempt) {
                    spp.disconnect()
                    return@Thread
                }
                if (!ok) {
                    spp.disconnect()
                    failAndRetry(myAttempt, "No se pudo conectar (¿Mi Fitness está abierta o el Bluetooth apagado?)")
                    return@Thread
                }
                val built = ProtocolHandler(
                    authService = AuthService(key),
                    connection = { bytes -> spp.write(bytes) },
                    onAuthenticated = { if (myAttempt == attempt) onAuthenticated() },
                    onCommand = { cmd -> if (myAttempt == attempt) onCommand(cmd) },
                )
                handler = built
                connection = spp
                protocol = built
                setStatus(Status.AUTHENTICATING, null)
                built.start()
                // Si la clave es incorrecta el reloj no responde: no esperamos para siempre.
                main.postDelayed({
                    if (myAttempt == attempt && status == Status.AUTHENTICATING) {
                        teardown()
                        failAndRetry(myAttempt, "El reloj no aceptó la clave")
                    }
                }, 15_000)
            } catch (e: SecurityException) {
                Log.w(TAG, "Sin permiso de Bluetooth", e)
                wanted = false
                setStatus(Status.DISCONNECTED, "Falta el permiso de Bluetooth")
            } catch (e: IllegalArgumentException) {
                wanted = false
                setStatus(Status.DISCONNECTED, "La MAC no es válida")
            }
        }, "watch-connect").start()
    }

    private fun onAuthenticated() {
        Log.i(TAG, "Autenticado")
        retryDelayMs = 3_000L
        setStatus(Status.CONNECTED, null)
        sendCurrentTime()
        protocol?.sendCommand(CommandHelper.buildRealtimeStatsStart())
        sendMusicInfo()
    }

    private fun onCommand(cmd: XiaomiProto.Command) {
        when {
            cmd.type == TYPE_MUSIC && cmd.subtype == MUSIC_REQUEST_INFO -> sendMusicInfo()
            cmd.type == TYPE_MUSIC && cmd.subtype == MUSIC_MEDIA_KEY && cmd.music.hasMediaKey() -> {
                val key = cmd.music.mediaKey
                val button = when (key.key) {
                    0 -> Button.PLAY
                    1 -> Button.PAUSE
                    3 -> Button.PREVIOUS
                    4 -> Button.NEXT
                    // El reloj manda volumen 100 para subir y 0 para bajar, sin importar el
                    // volumen real: por eso funciona aunque el celular esté al mínimo o al máximo.
                    5 -> if (key.volume >= 50) Button.VOLUME_UP else Button.VOLUME_DOWN
                    else -> null
                }
                Log.i(TAG, "Botón del reloj: key=${key.key} volume=${key.volume} -> $button")
                if (button != null) main.post { listener?.onButton(button) }
            }
            cmd.type == CommandHelper.TYPE_HEALTH && cmd.subtype == HEALTH_REALTIME_EVENT &&
                cmd.health.hasRealTimeStats() -> {
                val bpm = cmd.health.realTimeStats.heartRate
                if (bpm > 0) main.post { listener?.onHeartRate(bpm) }
            }
        }
    }

    private fun sendMusicInfo() {
        val info = XiaomiProto.MusicInfo.newBuilder()
            .setState(1) // reproduciendo: el reloj muestra los controles de pausa
            .setTrack(title)
            .setArtist(artist)
            // Siempre a la mitad: hay lugar para subir y bajar.
            .setVolume(50)
        protocol?.sendCommand(
            XiaomiProto.Command.newBuilder()
                .setType(TYPE_MUSIC)
                .setSubtype(MUSIC_INFO)
                .setMusic(XiaomiProto.Music.newBuilder().setMusicInfo(info))
                .build(),
        )
    }

    private fun sendCurrentTime() {
        val cal = GregorianCalendar.getInstance()
        val tz = cal.timeZone
        val quarterHours = tz.getOffset(cal.timeInMillis) / 1000 / 60 / 15
        val dst = if (tz.inDaylightTime(cal.time)) tz.dstSavings / 1000 / 60 / 15 else 0
        protocol?.sendCommand(
            XiaomiProto.Command.newBuilder()
                .setType(CommandHelper.TYPE_SYSTEM)
                .setSubtype(CommandHelper.SYS_CLOCK)
                .setSystem(XiaomiProto.System.newBuilder().setClock(XiaomiProto.Clock.newBuilder()
                    .setTime(XiaomiProto.Time.newBuilder()
                        .setHour(cal.get(Calendar.HOUR_OF_DAY))
                        .setMinute(cal.get(Calendar.MINUTE))
                        .setSecond(cal.get(Calendar.SECOND))
                        .setMillisecond(cal.get(Calendar.MILLISECOND)))
                    .setDate(XiaomiProto.Date.newBuilder()
                        .setYear(cal.get(Calendar.YEAR))
                        .setMonth(cal.get(Calendar.MONTH) + 1)
                        .setDay(cal.get(Calendar.DAY_OF_MONTH)))
                    .setTimezone(XiaomiProto.TimeZone.newBuilder()
                        .setZoneOffset(quarterHours)
                        .setDstOffset(dst)
                        .setName(tz.id))))
                .build(),
        )
    }

    private fun onDrop(myAttempt: Int) {
        if (myAttempt != attempt) return
        Log.i(TAG, "Conexión cortada")
        teardown()
        failAndRetry(myAttempt, "Se cortó la conexión")
    }

    private fun failAndRetry(myAttempt: Int, detail: String) {
        if (myAttempt != attempt) return
        setStatus(Status.DISCONNECTED, detail)
        if (!wanted) return
        val delay = retryDelayMs
        retryDelayMs = (retryDelayMs * 2).coerceAtMost(30_000L)
        main.postDelayed({
            if (wanted && myAttempt == attempt) connect()
        }, delay)
    }

    private fun teardown() {
        try { connection?.disconnect() } catch (_: Exception) {}
        connection = null
        protocol = null
    }

    private fun setStatus(newStatus: Status, detail: String?) {
        status = newStatus
        main.post { listener?.onStatus(newStatus, detail) }
    }
}
