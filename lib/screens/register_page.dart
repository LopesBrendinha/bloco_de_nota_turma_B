import 'package:blocodenotasturmab/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'notes_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool obscurePassword = true;

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      showMessage("Preencha todos os campos");
      return;
    }
    if (password.length < 6) {
      showMessage('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (password != confirm) {
      showMessage("As senhas não são iguais");
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final user = await authService.register(email, password);
      if (user == null) throw StateError('O cadastro não retornou um usuário.');

      if (mounted) {
        showMessage("Conta criada com sucesso!");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => NotesPage(uid: user.uid, email: user.email),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      showMessage("Não foi possível criar a conta.");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              "E-mail",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xff40394a),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: emailController,
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
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: "Digite sua senha",
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              "Confirmar senha",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xff40394a),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: confirmPasswordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: "Digite novamente",
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
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
