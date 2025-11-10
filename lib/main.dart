import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/input_kinerja_page.dart';
import 'package:e_kinerja_web_mobile/pages/lihat_kinerja_page.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uerbnsdoxgypdygoxhvd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVlcmJuc2RveGd5cGR5Z294aHZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzNDQ3OTUsImV4cCI6MjA3NzkyMDc5NX0.d-Z2-GVXqZzTZXmcVkeVGwOkL-o9j04j3y-wyG1okEQ',
  );

  runApp(const EKinerjaApp());
}

class EKinerjaApp extends StatelessWidget {
  const EKinerjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final _router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/input-kinerja',
          builder: (context, state) => const InputKinerjaPage(),
        ),
        GoRoute(
          path: '/lihat-kinerja',
          builder: (context, state) => const LihatKinerjaPage(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'E-Kinerja Web Mobile',
      theme: ThemeData(useMaterial3: true),
      routerConfig: _router,
    );
  }
}
