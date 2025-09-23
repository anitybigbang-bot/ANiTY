// =====================================
// lib/pages/set_password_page.dart
// （メールのMagic Linkから遷移 → パスワードを設定）
// =====================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _busy = false;

  Future<void> _updatePassword() async {
    final p1 = _pass1.text;
    final p2 = _pass2.text;

    if (p1.isEmpty || p2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを入力してください')),
      );
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードが一致しません')),
      );
      return;
    }
    if (p1.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードは8文字以上にしてください')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      // ここに到達した時点でメールリンクによりすでに「ログイン済み」になっている想定
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクからアクセスしてください（未ログインです）')),
        );
        return;
      }

      await auth.updateUser(UserAttributes(password: p1));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを設定しました')),
      );

      // 好きなホームへ遷移（例：/ ＝ AuthGate配下のホーム）
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return Scaffold(
      appBar: AppBar(title: const Text('パスワード設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (session == null)
              const Text('メールのリンクからアクセスしてください（セッション未検出）'),
            if (session != null) ...[
              Text('メール認証済み: ${session.user.email ?? ""}'),
              const SizedBox(height: 16),
              TextField(
                controller: _pass1,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新しいパスワード'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pass2,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新しいパスワード（確認）'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _updatePassword,
                child: const Text('パスワードを設定して完了'),
              ),
            ],
            const Spacer(),
            if (_busy) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}