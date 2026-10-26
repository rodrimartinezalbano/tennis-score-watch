# Origen

`SppConnection`, `ProtocolHandler`, `PacketV1`, `PacketV2`, `Channel`, `AuthService`,
`CommandHelper` y `proto/xiaomi.proto` vienen de
[judas-priest/pedometer](https://github.com/judas-priest/pedometer) (licencia MIT según su
README), que a su vez se basa en el protocolo de Gadgetbridge. Solo se cambió el paquete.

`java/.../XiaomiProto.java` es código generado: se regenera con
`protoc --java_out=lite:app/src/main/java -I app/src/main/proto app/src/main/proto/xiaomi.proto`.
