import 'package:firebase_auth/firebase_auth.dart';

class ServicoAutenticacao {
  final FirebaseAuth _autenticacao = FirebaseAuth.instance;

  User? get usuarioAtual => _autenticacao.currentUser;

  Future<User?> entrar(String email, String senha) async {
    final resultado = await _autenticacao.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return resultado.user;
  }

  Future<User?> cadastrar(String email, String senha) async {
    final resultado = await _autenticacao.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return resultado.user;
  }

  Future<void> sair() async {
    await _autenticacao.signOut();
  }

  static String mensagemDeErro(Object erro) {
    if (erro is! FirebaseAuthException) {
      return 'Algo deu errado. Tente novamente.';
    }
    return switch (erro.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'E-mail ou senha incorretos.',
      'invalid-email' => 'Digite um e-mail válido.',
      'email-already-in-use' => 'Já existe uma conta com esse e-mail.',
      'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
      'user-disabled' => 'Essa conta foi desativada.',
      'too-many-requests' => 'Muitas tentativas. Aguarde um pouco.',
      'network-request-failed' => 'Sem conexão com a internet.',
      'operation-not-allowed' =>
        'Login por e-mail e senha não está ativo no Firebase.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }
}
