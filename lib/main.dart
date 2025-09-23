// =====================================
// lib/main.dart （Anity / ログイン必須）
// =====================================
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 既存ページ
import 'pages/anime_list_page.dart';
import 'pages/admin_page.dart';

// 追加ページ（ログイン/サインアップUI・ログイン後ホーム）
import 'pages/login_page.dart';
import 'pages/set_password_page.dart';     // もし未使用なら消してOK
import 'pages/signup_request_page.dart';   // もし未使用なら消してOK

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 初期化（あなたのプロジェクトのURL/anonKeyに置き換え済み）
  await Supabase.initialize(
    url: 'https://eqorqjocaasikmwphegi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxb3Jxam9jYWFzaWttd3BoZWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcxNjgxNjMsImV4cCI6MjA3Mjc0NDE2M30.aGg5GnSW3mcrSMxcPwGkOmOPfcWQgtq3QVYfOa8bY3c',
  );

  // GitHub Pages 等で # 付きルーティング
  setUrlStrategy(const HashUrlStrategy());

  runApp(const AnityApp());
}

class AnityApp extends StatelessWidget {
  const AnityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anity',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 192, 169, 231),
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // ← ログイン状態で振り分け
      routes: {
        '/admin': (_) => const AdminPage(),
        '/set-password': (_) => const SetPasswordPage(),       // 使わないなら削除OK
        '/signup-request': (_) => const SignUpRequestPage(),   // 使わないなら削除OK
      },
    );
  }
}

/// ログイン必須ゲート
/// - サインイン済みなら HomePage（＝内部で AnimeListPage を表示でもOK）
/// - 未ログインなら LoginPage
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    // セッションの変化を購読して画面を即時更新
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          // ログイン後のホーム（必要なら AnimeListPage に差し替えてOK）
          return const AnimeListPage();
          // 例: return const AnimeListPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}