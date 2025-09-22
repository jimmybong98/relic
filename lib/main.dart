import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pv;
import 'package:window_manager/window_manager.dart';
import 'package:admin/utils/platform_utils.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:admin/constants.dart';
import 'package:admin/controllers/menu_app_controller.dart';
import 'package:admin/features/main_menu/main_menu_page.dart';
import 'package:admin/features/shared/providers/search_flow_form_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  if (isDesktop) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden, // oculta a barra do sistema
        size: Size(1000, 700),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  // Carrega .env de forma segura (não quebra se não existir)
  try {
    await dotenv.load(fileName: ".env");
    // print("[dotenv] carregado com ${dotenv.env.length} variáveis");
  } catch (e) {
    // print("[dotenv] falhou ao carregar .env: $e");
  }

  await Hive.initFlutter();
  await Hive.openBox<Map>(sharedSearchFlowBoxName);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return pv.MultiProvider(
      providers: [
        pv.ChangeNotifierProvider(create: (_) => MenuAppController()),
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
