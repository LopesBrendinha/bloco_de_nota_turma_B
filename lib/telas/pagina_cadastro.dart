import 'package:blocodenotasturmab/servicos/servico_autenticacao.dart';
import 'package:blocodenotasturmab/telas/pagina_notas.dart';
import 'package:flutter/material.dart';

class PaginaCadastro extends StatefulWidget {
  const PaginaCadastro({super.key});

  @override
  State<PaginaCadastro> createState() => _PaginaCadastroState();
}

class _PaginaCadastroState extends State<PaginaCadastro> {
  final controladorEmail = TextEditingController();
  final controladorSenha = TextEditingController();
  final controladorConfirmacao = TextEditingController();

  final ServicoAutenticacao autenticacao = ServicoAutenticacao();

  bool carregando = false;
  bool ocultarSenha = true;

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    controladorEmail.dispose();
    controladorSenha.dispose();
    controladorConfirmacao.dispose();
    super.dispose();
  }

  Future<void> cadastrar() async {
    final email = controladorEmail.text.trim();
    final senha = controladorSenha.text.trim();
    final confirmacao = controladorConfirmacao.text.trim();

    if (email.isEmpty || senha.isEmpty || confirmacao.isEmpty) {
      mostrarMensagem("Preencha todos os campos");
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      mostrarMensagem("Digite um e-mail válido");
      return;
    }
    if (senha.length < 6) {
      mostrarMensagem("A senha precisa ter pelo menos 6 caracteres");
      return;
    }
    if (senha != confirmacao) {
      mostrarMensagem("As senhas não são iguais");
      return;
    }

    setState(() => carregando = true);

    try {
      await autenticacao.cadastrar(email, senha);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PaginaNotas()),
          (rota) => false,
        );
      }
    } catch (erro) {
      mostrarMensagem(ServicoAutenticacao.mensagemDeErro(erro));
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  Widget campoSenha(TextEditingController controlador, String dica) {
    return TextField(
      controller: controlador,
      obscureText: ocultarSenha,
      decoration: InputDecoration(
        hintText: dica,
        prefixIcon: Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => ocultarSenha = !ocultarSenha);
          },
          icon: Icon(
            ocultarSenha
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estiloRotulo = TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xff40394a),
    );

    return Scaffold(
      appBar: AppBar(title: Text("Criar conta")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 15),
            Text(
              "Comece suas anotações",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff292333),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Crie sua conta para começar",
              style: TextStyle(color: Color(0xff77717f)),
            ),
            SizedBox(height: 35),
            Text("E-mail", style: estiloRotulo),
            SizedBox(height: 8),
            TextField(
              controller: controladorEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "seu@email.com",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            SizedBox(height: 20),
            Text("Senha", style: estiloRotulo),
            SizedBox(height: 8),
            campoSenha(controladorSenha, "Digite sua senha"),
            SizedBox(height: 20),
            Text("Confirmar senha", style: estiloRotulo),
            SizedBox(height: 8),
            campoSenha(controladorConfirmacao, "Digite novamente"),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: carregando ? null : cadastrar,
              child: carregando
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Criar minha conta",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
