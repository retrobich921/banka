import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/group.dart';
import '../bloc/groups_list_bloc.dart';
import '../widgets/group_card.dart';

/// Экран списка групп с двумя вкладками — «Мои» и «Открытые». Создание
/// группы — через FAB. После успешного создания автоматически
/// перекидываем на экран новой группы.
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      context.read<GroupsListBloc>().add(GroupsListSubscribeRequested(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Группы'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Мои'),
              Tab(text: 'Открытые'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.pushNamed(AppRoutes.groupCreateName),
          icon: const Icon(Icons.add),
          label: const Text('Создать'),
        ),
        body: BlocListener<GroupsListBloc, GroupsListState>(
          listenWhen: (prev, curr) =>
              prev.createdGroupId != curr.createdGroupId &&
              curr.createdGroupId != null,
          listener: (context, state) {
            // Создание подтверждено — открываем экран группы и сбрасываем
            // флаг, чтобы при следующем создании listener снова сработал.
            final id = state.createdGroupId!;
            context.read<GroupsListBloc>().add(
              const GroupsListCreationAcknowledged(),
            );
            context.pushNamed(
              AppRoutes.groupDetailName,
              pathParameters: {'id': id},
            );
          },
          child: BlocBuilder<GroupsListBloc, GroupsListState>(
            builder: (context, state) {
              if (state.status == GroupsListStatus.initial ||
                  (state.status == GroupsListStatus.loading &&
                      state.myGroups.isEmpty &&
                      state.publicGroups.isEmpty)) {
                return const Center(child: CircularProgressIndicator());
              }
              return TabBarView(
                children: [
                  _GroupsTab(
                    groups: state.myGroups,
                    emptyHint: 'Ты пока ни в одной группе.\nСоздай свою.',
                  ),
                  _GroupsTab(
                    groups: state.publicGroups,
                    emptyHint: 'Открытых групп пока нет.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.groups, required this.emptyHint});

  final List<Group> groups;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            emptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final group = groups[i];
        return GroupCard(
          group: group,
          onTap: () => context.pushNamed(
            AppRoutes.groupDetailName,
            pathParameters: {'id': group.id},
          ),
        );
      },
    );
  }
}
