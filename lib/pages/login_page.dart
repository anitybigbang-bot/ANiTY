// =====================================
// lib/pages/login_page.dart
// =====================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_request_page.dart'; // ← 追加（画面遷移先）

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  Future<void> _withBusy(Future<void> Function() run) async {
    setState(() => _busy = true);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 既存ユーザーの通常ログイン
  Future<void> _signIn() async => _withBusy(() async {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          // 成功したら AuthGate が自動で切り替わる
        } on AuthException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      });

  void _goToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignUpRequestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ログイン / 新規登録")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ログインフォーム
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "メールアドレス"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "パスワード"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _signIn,
                    child: const Text("ログイン"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 32),

            // 新規登録導線（別画面へ）
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _goToSignUp,
                    child: const Text("新規登録へ進む（メール入力）"),
                  ),
                ),
              ],
            ),

            const Spacer(),
            if (_busy) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}