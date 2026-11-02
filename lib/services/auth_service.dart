import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static String errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Informe um e-mail válido.',
        'email-already-in-use' => 'Este e-mail já está cadastrado.',
        'weak-password' => 'Escolha uma senha com pelo menos 6 caracteres.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'E-mail ou senha incorretos.',
        'network-request-failed' =>
          'Sem conexão. Conecte-se para entrar ou criar uma conta.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde um pouco e tente novamente.',
        'operation-not-allowed' =>
          'Ative o acesso por e-mail e senha no Firebase.',
        _ => 'Não foi possível acessar sua conta. Tente novamente.',
      };
    }
    return 'Não foi possível acessar sua conta. Tente novamente.';
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
