import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bootstrap_supabase.dart';
import '../pages/anime_list_page.dart';
import '../pages/login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = supabase.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session != null) {
      return const AnimeListPage();
    }
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final s = supabase.auth.currentSession;
        if (s != null) return const AnimeListPage();
        return const LoginPage();
      },
    );
  }
}