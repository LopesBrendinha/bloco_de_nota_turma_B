import 'dart:math';

final Random _random = Random.secure();

/// Gera um identificador UUID versão 4.
///
/// O banco antigo usava AUTOINCREMENT, mas dois aparelhos gerariam o mesmo
/// número para notas diferentes. Com um UUID criado no próprio aparelho,
/// a nota já tem o mesmo ID no SQLite e no Firestore, mesmo sem internet.
String generateId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
