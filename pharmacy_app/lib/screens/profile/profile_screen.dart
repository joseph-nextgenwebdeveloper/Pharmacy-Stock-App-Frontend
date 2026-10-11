import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/session_helper.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/route_names.dart';
import '../../services/stock_alert_service.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/user_avatar.dart';

/// The signed-in person: photo, today's numbers, recent activity, settings
/// (dark mode, stock-alert notifications) and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _alertsOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadMine();
      context.read<AuthProvider>().refreshProfile();
    });
    StockAlertService.isEnabled().then((v) {
      if (mounted) setState(() => _alertsOn = v);
    });
  }

  // ---------------------------------------------------------------- photo

  Future<void> _changePhoto() async {
    final user = context.read<AuthProvider>().user;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (user?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    bool ok;

    if (choice == 'remove') {
      ok = await auth.updateProfile(removeAvatar: true);
    } else {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      ok = await auth.updateProfile(avatarPath: picked.path);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile photo updated.' : (auth.error ?? 'Could not update the photo.')),
      ),
    );
  }

  Future<void> _editDetails() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final phone = TextEditingController(text: user.phoneNumber);

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit profile', style: AppTextStyles.headingSmall),
            const SizedBox(height: 14),
            TextField(
              controller: first,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: last,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      firstName: first.text.trim(),
      lastName: last.text.trim(),
      phoneNumber: phone.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile saved.' : (auth.error ?? 'Could not save your profile.')),
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final activity = context.watch<ActivityProvider>();
    final theme = context.watch<ThemeProvider>();
    final summary = activity.summary;

    final recent = activity.mine.where((a) => !a.isSession).take(6).toList();

    String signed(int n) => '${n >= 0 ? '+' : ''}$n';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await activity.loadMine();
          await auth.refreshProfile();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text('My activity', style: AppTextStyles.headingLarge),
            const SizedBox(height: 18),
            Row(
              children: [
                GestureDetector(
                  onTap: auth.isSavingProfile ? null : _changePhoto,
                  child: Stack(
                    children: [
                      UserAvatar(
                        url: user?.avatarUrl,
                        initials: user?.initials ?? '?',
                        radius: 33,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: auth.isSavingProfile
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_camera_rounded,
                                  size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'Staff', style: AppTextStyles.headingSmall),
                      Text(user?.prettyRole ?? '', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: _editDetails,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _StatBox(value: '${summary.updatesToday}', label: 'Updates today')),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    value: signed(summary.netUnitsToday),
                    label: 'Net units today',
                    color: summary.netUnitsToday >= 0 ? AppColors.primaryDeep : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    value: '+${summary.unitsIn7d}',
                    label: 'Received · 7 days',
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    value: '-${summary.unitsOut7d}',
                    label: 'Removed · 7 days',
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent activity', style: AppTextStyles.headingSmall),
                TextButton(
                  onPressed: () => context.push(RouteNames.activity),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  activity.isLoading ? 'Loading…' : 'Nothing recorded yet.',
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else
              ...recent.map((a) => ActivityTile(log: a)),
            if (user?.canViewTeamActivity ?? false) ...[
              const SizedBox(height: 6),
              _NavTile(
                icon: Icons.groups_rounded,
                title: 'Team activity',
                subtitle: 'See who did what, across all staff',
                onTap: () => context.push('${RouteNames.activity}?team=1'),
              ),
            ],
            _NavTile(
              icon: Icons.swap_vert_rounded,
              title: 'Movement history',
              subtitle: 'Every stock in and out, with who did it',
              onTap: () => context.push(RouteNames.movementHistory),
            ),
            const SizedBox(height: 22),
            Text('Settings', style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_rounded),
                    title: const Text('Dark mode'),
                    value: theme.isDark,
                    activeColor: AppColors.primary,
                    onChanged: theme.setDark,
                  ),
                  Divider(height: 1, color: AppColors.border),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Out-of-stock notifications'),
                    subtitle: const Text('Repeats every 2 hours until restocked'),
                    value: _alertsOn,
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      setState(() => _alertsOn = v);
                      await StockAlertService.setEnabled(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Account', style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Username',
                    value: user?.username.isNotEmpty == true ? user!.username : '—',
                  ),
                  _InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user?.email.isNotEmpty == true ? user!.email : '—',
                  ),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user?.phoneNumber.isNotEmpty == true ? user!.phoneNumber : '—',
                  ),
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Role',
                    value: user?.prettyRole ?? '—',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => SessionHelper.signOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDeep),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatBox({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
