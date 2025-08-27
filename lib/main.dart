import 'package:admin/constants.dart';
import 'package:admin/controllers/menu_app_controller.dart';
import 'package:admin/features/main_menu/main_menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pv;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega .env de forma segura (não quebra se não existir)
  try {
    await dotenv.load(fileName: ".env");
    // print("[dotenv] carregado com ${dotenv.env.length} variáveis");
  } catch (e) {
    // print("[dotenv] falhou ao carregar .env: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return pv.MultiProvider(
      providers: [
        pv.ChangeNotifierProvider(
          create: (_) => MenuAppController(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Admin Panel',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: bgColor,
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme,
          ).apply(bodyColor: Colors.white),
          canvasColor: secondaryColor,
        ),
        home: const MainMenuPage(),
      ),
    );
  }
}
