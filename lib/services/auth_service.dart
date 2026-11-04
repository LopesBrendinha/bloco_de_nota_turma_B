import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Avisa quando o usuário entra ou sai. O Firebase guarda a sessão no
  /// aparelho, então ela também funciona ao abrir o aplicativo sem internet.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Traduz um erro de autenticação para uma mensagem ao usuário.
  static String errorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Não foi possível concluir a operação. Tente novamente.';
    }

    switch (error.code) {
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
      case 'invalid-email':
        return 'Digite um e-mail válido.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com este e-mail.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'operation-not-allowed':
        return 'Login por e-mail e senha desativado no Firebase.';
      default:
        return 'Não foi possível concluir a operação. Tente novamente.';
    }
  }
}
