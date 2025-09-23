// =====================================
// lib/pages/signup_request_page.dart
// （メール入力→Magic Link送信。リンク先でパスワード設定）
// =====================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpRequestPage extends StatefulWidget {
  const SignUpRequestPage({super.key});

  @override
  State<SignUpRequestPage> createState() => _SignUpRequestPageState();
}

class _SignUpRequestPageState extends State<SignUpRequestPage> {
  final _emailController = TextEditingController();
  bool _sending = false;

  Future<void> _sendInviteLink() async {
  final email = _emailController.text.trim();
  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('メールアドレスを入力してください')),
    );
    return;
  }

  setState(() => _sending = true);
  try {
    // 本番用の set-password ページにリダイレクトするよう設定
    await Supabase.instance.client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'https://anitybigbang-bot.github.io/ANiTY/app/#/set-password',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('確認メールを送信しました。メール内のリンクから続行してください'),
      ),
    );

    Navigator.of(context).pop();
  } on AuthException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } finally {
    if (mounted) setState(() => _sending = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("新規登録")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('メールアドレスを入力すると、登録用のリンクを送ります。'),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "メールアドレス"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendInviteLink,
                    child: const Text('登録用リンクをメールで送る'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_sending) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}