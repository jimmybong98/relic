import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin/constants.dart';
import 'package:admin/responsive.dart';
import 'package:admin/services/auth_service.dart';
import 'package:admin/features/users/users_page.dart';

class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    if (auth == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authServiceProvider.notifier).logout();
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
        } else if (value == 'manage') {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const UsersPage()));
        }
      },
      itemBuilder: (context) => [
        if (auth.isAdmin)
          const PopupMenuItem(
            value: 'manage',
            child: Text('Gerenciar Acessos'),
          ),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: Container(
        margin: const EdgeInsets.only(left: defaultPadding),
        padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding,
          vertical: defaultPadding / 1,
        ),
        child: Row(
          children: [
            Image.asset('assets/images/profile_picazul.png', height: 24),
            if (!Responsive.isMobile(context))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding / 1,
                ),
                child: Text(auth.username),
              ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}
