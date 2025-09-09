import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'package:admin/widgets/window_bar.dart';
import 'package:admin/screens/main/components/side_menu.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  late Future<List<AppUser>> _future;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppUser>> _load() {
    final auth = ref.read(authServiceProvider)!;
    return UserService().fetchUsers(auth.username, auth.password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    if (auth == null || !auth.isAdmin) {
      return Scaffold(
        drawer: const SideMenu(current: SideMenuSection.dashboard),
        body: const Center(child: Text('Acesso negado')),
      );
    }
    return Scaffold(
      appBar: const WindowBar(title: 'Gerenciar Acessos'),
      drawer: const SideMenu(current: SideMenuSection.dashboard),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: users
                      .map(
                        (u) => ListTile(
                          title: Text(u.username),
                          subtitle: Text(
                            u.isAdmin ? 'Administrador' : 'Usuário',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Novo usuário',
                      ),
                    ),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                    ),
                    SwitchListTile(
                      title: const Text('Administrador'),
                      value: _isAdmin,
                      onChanged: (v) => setState(() => _isAdmin = v),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final ok = await UserService().createUser(
                          _userCtrl.text,
                          _passCtrl.text,
                          _isAdmin,
                          auth.username,
                          auth.password,
                        );
                        if (ok) {
                          setState(() {
                            _future = _load();
                            _userCtrl.clear();
                            _passCtrl.clear();
                            _isAdmin = false;
                          });
                        }
                      },
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
