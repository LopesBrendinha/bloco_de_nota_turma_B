import 'package:blocodenotasturmab/services/auth_service.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:flutter/material.dart';

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

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      showMessage('Preencha todos os campos.');
      return;
    }
    if (password != confirm) {
      showMessage('As senhas não são iguais.');
      return;
    }

    setState(() => loading = true);
    try {
      // O Firebase já autentica a conta criada; ao fechar esta tela o
      // AuthGate mostra as notas.
      await authService.register(email, password);
      if (mounted) Navigator.pop(context);
      return;
    } catch (e) {
      showMessage(AuthService.messageFor(e));
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget passwordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Abra um caderno novo',
              style: AppTheme.display(context, size: 30),
            ),
            const SizedBox(height: 6),
            Text(
              'suas notas ficam no aparelho e na sua conta',
              style: AppTheme.handwritten(context, size: 21),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                hintText: 'seu@email.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 14),
            passwordField(passwordController, 'Senha (mín. 6 caracteres)'),
            const SizedBox(height: 14),
            passwordField(confirmPasswordController, 'Confirmar senha'),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    )
                  : const Text('Criar minha conta'),
            ),
          ],
        ),
      ),
    );
  }
}
