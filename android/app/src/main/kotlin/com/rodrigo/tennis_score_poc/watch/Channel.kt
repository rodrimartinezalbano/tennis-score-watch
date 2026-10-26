package com.rodrigo.tennis_score_poc.watch

enum class Channel {
    Unknown,
    Version,
    ProtobufCommand,
    Activity,
    Data,
    Authentication,
}

fun interface ChannelHandler {
    fun handle(payload: ByteArray)
}
