import 'package:firebase_auth/firebase_auth.dart';

/// Autenticação com e-mail e senha pelo Firebase Authentication.
///
/// O Firebase mantém a sessão salva no aparelho, então o usuário continua
/// logado ao reabrir o app (ver `AuthGate` em `main.dart`).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<void> logout() => _auth.signOut();

  /// Converte os códigos de erro do Firebase em mensagens em português.
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Já existe uma conta com este e-mail.';
        case 'weak-password':
          return 'A senha precisa ter pelo menos 6 caracteres.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
        case 'network-request-failed':
          return 'Sem conexão com a internet. Verifique sua rede.';
      }
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }
}
