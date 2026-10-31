import 'package:firebase_auth/firebase_auth.dart';

/// Erro de autenticação já traduzido para uma mensagem exibível.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Autenticação por e-mail e senha no Firebase Authentication.
///
/// O `uid` devolvido aqui é a chave que liga cada nota ao seu dono: ele vai
/// para a coluna `uid` do SQLite e para o caminho `users/{uid}` do Firestore.
/// Nenhuma senha é guardada pelo aplicativo — o SDK do Firebase cuida das
/// credenciais e do token de sessão.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Emite o usuário atual a cada login/logout. Usado pelo `AuthGate`.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_loginMessage(error.code));
    } catch (_) {
      throw AuthException('Não foi possível entrar. Tente novamente.');
    }
  }

  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_registerMessage(error.code));
    } catch (_) {
      throw AuthException('Não foi possível criar a conta. Tente novamente.');
    }
  }

  Future<void> logout() => _auth.signOut();

  String _loginMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      default:
        return 'Não foi possível entrar ($code).';
    }
  }

  String _registerMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'A senha deve ter no mínimo 6 caracteres.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail está desativado no projeto Firebase.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      default:
        return 'Não foi possível criar a conta ($code).';
    }
  }
}
