import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../cloud/cloud_session.dart';
import '../design_system/app_design_system.dart';
import '../widgets/initial_avatar.dart';

/// Manager account settings deliberately exclude trainer and physical data.
class ManagerProfileScreen extends ConsumerStatefulWidget {
  const ManagerProfileScreen({super.key});

  @override
  ConsumerState<ManagerProfileScreen> createState() =>
      _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends ConsumerState<ManagerProfileScreen> {
  Future<void> _showEditNameDialog(
    BuildContext context,
    CloudProfile profile,
  ) async {
    final controller = TextEditingController(text: profile.name);
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Nama Manager'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: localError,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSaving = true;
                            localError = null;
                          });
                          try {
                            final err = await ref
                                .read(cloudAuthProvider.notifier)
                                .updateProfile(
                                  displayName: controller.text.trim(),
                                  phone: profile.phone,
                                );
                            if (!dialogCtx.mounted) return;
                            if (err != null) {
                              setDialogState(() {
                                isSaving = false;
                                localError = 'Gagal memperbarui nama. Silakan periksa koneksi Anda.';
                              });
                            } else {
                              Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nama profil berhasil diperbarui.',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              localError = 'Terjadi kesalahan saat menyimpan. Silakan coba lagi.';
                            });
                          }
                        },
                  child: isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmResetPassword(BuildContext context, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Reset Password'),
        content: Text('Kirim tautan pemulihan kata sandi ke $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim Tautan'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final msg = await ref
            .read(cloudAuthProvider.notifier)
            .resetPassword(email);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal mengirim tautan reset password. Silakan coba lagi.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Manager?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(cloudAuthProvider.notifier).logout();
        if (context.mounted) {
          context.go('/login');
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal melakukan logout. Silakan coba lagi.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(cloudAuthProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Profil Manager')),
        body: account.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal memuat profil manager. Silakan periksa koneksi Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(cloudAuthProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) {
            if (profile == null || !profile.isManager) {
              return const Center(child: Text('Sesi manager tidak tersedia.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InitialAvatar(
                      name: profile.name,
                      email: profile.email,
                      radius: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      profile.name,
                      style: AppTypography.screenHeader.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        'Manager',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Nama Lengkap',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          subtitle: Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit Nama'),
                            onPressed: () =>
                                _showEditNameDialog(context, profile),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          subtitle: Text(
                            profile.email,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.badge_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Peran Akun',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          subtitle: Text(
                            'Manager',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.dark_mode_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Pengaturan Tema Aplikasi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final currentTheme =
                                  ref.watch(themeProvider).value ??
                                  ThemeMode.system;
                              return Column(
                                children: [
                                  RadioListTile<ThemeMode>(
                                    title: const Text('Ikuti Sistem (Default)'),
                                    value: ThemeMode.system,
                                    groupValue: currentTheme,
                                    onChanged: (v) {
                                      if (v != null) {
                                        ref
                                            .read(themeProvider.notifier)
                                            .setMode(v);
                                      }
                                    },
                                  ),
                                  RadioListTile<ThemeMode>(
                                    title: const Text('Mode Terang (Light)'),
                                    value: ThemeMode.light,
                                    groupValue: currentTheme,
                                    onChanged: (v) {
                                      if (v != null) {
                                        ref
                                            .read(themeProvider.notifier)
                                            .setMode(v);
                                      }
                                    },
                                  ),
                                  RadioListTile<ThemeMode>(
                                    title: const Text('Mode Gelap (Dark)'),
                                    value: ThemeMode.dark,
                                    groupValue: currentTheme,
                                    onChanged: (v) {
                                      if (v != null) {
                                        ref
                                            .read(themeProvider.notifier)
                                            .setMode(v);
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_reset,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kata Sandi',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Kirim tautan reset kata sandi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () =>
                                _confirmResetPassword(context, profile.email),
                            child: const Text('Reset Password'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar dari Akun'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    onPressed: () => _confirmLogout(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
