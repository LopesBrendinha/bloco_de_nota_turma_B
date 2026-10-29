import 'dart:math';

const _chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random.secure();

/// Gera um identificador aleatório de 20 caracteres, no mesmo formato dos IDs
/// automáticos do Firestore. Funciona sem internet, o que permite criar a nota
/// offline já com o ID que ela terá na nuvem.
String generateId() =>
    List.generate(20, (_) => _chars[_random.nextInt(_chars.length)]).join();
