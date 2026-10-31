import 'package:blocodenotasturmab/servicos/servico_autenticacao.dart';
import 'package:blocodenotasturmab/telas/pagina_cadastro.dart';
import 'package:blocodenotasturmab/telas/pagina_notas.dart';
import 'package:flutter/material.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final controladorEmail = TextEditingController();
  final controladorSenha = TextEditingController();

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

  Future<void> entrar() async {
    if (controladorEmail.text.isEmpty || controladorSenha.text.isEmpty) {
      mostrarMensagem("Preencha todos os campos");
      return;
    }
    setState(() => carregando = true);

    try {
      final usuario = await autenticacao.entrar(
        controladorEmail.text.trim(),
        controladorSenha.text.trim(),
      );

      if (usuario != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PaginaNotas()),
        );
      }
    } catch (erro) {
      mostrarMensagem(ServicoAutenticacao.mensagemDeErro(erro));
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    controladorEmail.dispose();
    controladorSenha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Color(0xffe8ddf8),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xff6c4ab6),
                      size: 45,
                    ),
                  ),
                ),
                SizedBox(height: 35),
                Text(
                  "Seja Bem-vindo",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff292333),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Entre para acessar suas notas",
                  style: TextStyle(fontSize: 16, color: Color(0xff77717f)),
                ),
                SizedBox(height: 35),
                Text(
                  "E-mail",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff40394a),
                  ),
                ),
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
                Text(
                  "Senha",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff40394a),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: controladorSenha,
                  obscureText: ocultarSenha,
                  decoration: InputDecoration(
                    hintText: "Digite sua senha",
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
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: carregando ? null : entrar,
                  child: carregando
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Entrar",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaginaCadastro(),
                        ),
                      );
                    },
                    child: Text("Ainda não possui uma conta? Cadastre-se"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
