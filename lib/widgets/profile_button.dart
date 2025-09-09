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
          Navigator.of(context).pop();
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
          vertical: defaultPadding / 2,
        ),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Image.asset('assets/images/profile_pic.png', height: 38),
            if (!Responsive.isMobile(context))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding / 2,
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
