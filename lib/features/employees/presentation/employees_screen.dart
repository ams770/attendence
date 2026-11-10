import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';

/// Screen displaying all registered employees with management actions (edit, toggle active, delete, re-enroll).
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _activeOnly = false;
  String _searchQuery = '';
  bool _isLoading = false;
  List<Employee> _employees = <Employee>[];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final EmployeeRepository repo = ref.read(employeeRepositoryProvider);
      final List<Employee> list = await repo.getAllEmployees(
        activeOnly: _activeOnly ? true : null,
      );
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Employee> get _filteredEmployees {
    if (_searchQuery.trim().isEmpty) return _employees;
    final String q = _searchQuery.toLowerCase();
    return _employees.where((Employee e) {
      return e.name.toLowerCase().contains(q) ||
          e.code.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleActive(Employee employee) async {
    final EmployeeRepository repo = ref.read(employeeRepositoryProvider);
    await repo.setEmployeeActive(employee.id, !employee.isActive);
    ref.read(faceMatcherProvider).clearCache();
    await _loadEmployees();
  }

  Future<void> _showEditDialog(Employee employee) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController(
      text: employee.name,
    );
    final TextEditingController codeController = TextEditingController(
      text: employee.code,
    );
    String? errorMessage;

    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder:
                (
                  BuildContext ctx,
                  void Function(void Function()) setDialogState,
                ) {
                  return AlertDialog(
                    title: Text(l10n.editEmployee),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: l10n.employeeName,
                            hintText: l10n.employeeNameHint,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        TextField(
                          controller: codeController,
                          decoration: InputDecoration(
                            labelText: l10n.employeeCode,
                            hintText: l10n.employeeCodeHint,
                          ),
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.cancelAction),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final String newName = nameController.text.trim();
                          final String newCode = codeController.text.trim();

                          if (newName.isEmpty) {
                            setDialogState(
                              () => errorMessage = l10n.employeeNameRequired,
                            );
                            return;
                          }
                          if (newCode.isEmpty) {
                            setDialogState(
                              () => errorMessage = l10n.employeeCodeRequired,
                            );
                            return;
                          }

                          final EmployeeRepository repo = ref.read(
                            employeeRepositoryProvider,
                          );
                          final bool isTaken = await repo.isCodeTaken(
                            newCode,
                            excludeId: employee.id,
                          );
                          if (isTaken) {
                            setDialogState(
                              () => errorMessage = l10n.employeeCodeExists,
                            );
                            return;
                          }

                          final Employee updated = employee.copyWith(
                            name: newName,
                            code: newCode,
                          );
                          await repo.updateEmployee(updated);
                          ref.read(faceMatcherProvider).clearCache();
                          if (ctx.mounted) Navigator.of(dialogContext).pop();
                          await _loadEmployees();
                        },
                        child: Text(l10n.saveAction),
                      ),
                    ],
                  );
                },
          );
        },
      );
    } finally {
      nameController.dispose();
      codeController.dispose();
    }
  }

  Future<void> _confirmDelete(Employee employee) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.deleteEmployeeTitle),
          content: Text(l10n.deleteEmployeeConfirm(employee.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancelAction),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.deleteAction),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final EmployeeRepository repo = ref.read(employeeRepositoryProvider);
      await repo.deleteEmployee(employee.id);
      ref.read(faceMatcherProvider).clearCache();
      await _loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<Employee> items = _filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeesTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/enrollment');
          if (mounted) _loadEmployees();
        },
        icon: const Icon(Icons.person_add),
        label: Text(l10n.enrollEmployee),
      ),
      body: Column(
        children: <Widget>[
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: l10n.searchEmployees,
                    leading: const Icon(Icons.search),
                    trailing: _searchQuery.isNotEmpty
                        ? <Widget>[
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                          ]
                        : null,
                    onChanged: (String val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                FilterChip(
                  label: Text(l10n.statusActive),
                  selected: _activeOnly,
                  onSelected: (bool selected) {
                    setState(() => _activeOnly = selected);
                    _loadEmployees();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1.0),

          // Employee List or empty view
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          l10n.noEmployeesFound,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1.0),
                    itemBuilder: (BuildContext ctx, int index) {
                      final Employee emp = items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.isActive
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: emp.isActive
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.outline,
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                emp.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: emp.isActive
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (emp.needsReEnrollment) ...<Widget>[
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  l10n.needsReEnrollmentBadge,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${emp.code} • ${emp.embeddingCount} samples • ${emp.isActive ? l10n.statusActive : l10n.statusInactive}',
                          style: TextStyle(
                            color: emp.isActive
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.outline,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String action) async {
                            switch (action) {
                              case 'edit':
                                await _showEditDialog(emp);
                                break;
                              case 'toggle_active':
                                await _toggleActive(emp);
                                break;
                              case 're_enroll':
                                await context.push(
                                  '/enrollment',
                                  extra: <String, dynamic>{
                                    'employeeId': emp.id,
                                    'name': emp.name,
                                    'code': emp.code,
                                  },
                                );
                                if (mounted) _loadEmployees();
                                break;
                              case 'delete':
                                await _confirmDelete(emp);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext menuCtx) =>
                              <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(Icons.edit_outlined, size: 20),
                                      const SizedBox(width: 8.0),
                                      Text(l10n.editEmployee),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'toggle_active',
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        emp.isActive
                                            ? Icons.block_outlined
                                            : Icons.check_circle_outline,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        emp.isActive
                                            ? l10n.statusInactive
                                            : l10n.statusActive,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 're_enroll',
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.face_retouching_natural,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(l10n.reEnrollEmployee),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        l10n.deleteAction,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
