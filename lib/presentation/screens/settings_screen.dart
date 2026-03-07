import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_preferences.dart';
import '../../data/repositories/user_settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = UserSettingsRepository();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  String _themeMode = 'system';
  String _languageCode = 'vi';

  String? _userId;
  String? _avatarUrl;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExtension;

  bool _isMissingColumnError(Object error) {
    return error is PostgrestException && error.code == '42703';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _userId = user.id;
    try {
      Map<String, dynamic>? profile;
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url,bio')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      }

      final settings = await _repo.getSettings(user.id);
      if (!mounted) return;

      setState(() {
        _displayNameController.text =
            (profile?['display_name'] as String?) ??
            user.email?.split('@').first ??
            '';
        _bioController.text = (profile?['bio'] as String?) ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        _inAppNotifications = settings.inAppNotifications;
        _emailNotifications = settings.emailNotifications;
        _themeMode = settings.themeMode;
        _languageCode = settings.languageCode;
      });
    } catch (_) {
      // Ignore load errors.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack('Không đọc được dữ liệu ảnh');
        return;
      }

      final fileName = file.name.toLowerCase();
      String extension = 'jpg';
      if (fileName.endsWith('.png')) {
        extension = 'png';
      } else if (fileName.endsWith('.webp')) {
        extension = 'webp';
      } else if (fileName.endsWith('.gif')) {
        extension = 'gif';
      } else if (fileName.endsWith('.jpeg') || fileName.endsWith('.jpg')) {
        extension = 'jpg';
      }

      setState(() {
        _pendingAvatarBytes = file.bytes;
        _pendingAvatarExtension = extension;
      });
    } catch (e) {
      _showSnack('Chọn ảnh thất bại: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    if (displayName.isEmpty) {
      _showSnack('Tên hiển thị không được để trống');
      return;
    }

    setState(() => _saving = true);
    try {
      String? displayNameError;
      try {
        await _repo.updateDisplayName(
          userId: _userId!,
          displayName: displayName,
        );
        await _repo.updateBio(
          userId: _userId!,
          bio: bio,
        );
      } catch (e) {
        displayNameError = e.toString();
      }

      if (_pendingAvatarBytes != null && _pendingAvatarExtension != null) {
        final avatarUrl = await _repo.uploadAvatar(
          userId: _userId!,
          bytes: _pendingAvatarBytes!,
          fileExtension: _pendingAvatarExtension!,
        );
        await _repo.updateAvatarUrl(userId: _userId!, avatarUrl: avatarUrl);
        _avatarUrl = avatarUrl;
        _pendingAvatarBytes = null;
        _pendingAvatarExtension = null;
      }

      await _repo.updateSettings(
        userId: _userId!,
        inAppNotifications: _inAppNotifications,
        emailNotifications: _emailNotifications,
        themeMode: _themeMode,
        languageCode: _languageCode,
      );
      AppPreferences.apply(
        themeMode: _themeMode,
        languageCode: _languageCode,
      );

      if (displayNameError == null) {
        _showSnack('Đã lưu cài đặt');
      } else {
        _showSnack('Đã lưu cài đặt, nhưng chưa cập nhật được tên hiển thị');
      }
    } catch (e) {
      final message = e is PostgrestException
          ? (e.message.isNotEmpty ? e.message : e.toString())
          : e.toString();
      _showSnack('Lưu cài đặt thất bại: $message');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _t(String vi, String en) => _languageCode == 'en' ? en : vi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F9FF), Color(0xFFEFF4FF), Color(0xFFF8FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Row(
                          children: [
                            _iconShell(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Cài đặt',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF12263F),
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            _saveButton(),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _sectionCard(
                            title: 'Tài khoản',
                            icon: Icons.person_outline_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: const Color(0xFFDFE9FF),
                                      backgroundImage: _pendingAvatarBytes != null
                                          ? MemoryImage(_pendingAvatarBytes!)
                                          : (_avatarUrl != null
                                                    ? NetworkImage(_avatarUrl!)
                                                    : null),
                                      child: (_pendingAvatarBytes == null &&
                                              _avatarUrl == null)
                                          ? const Icon(
                                              Icons.person_outline_rounded,
                                              color: Color(0xFF2E66FF),
                                              size: 30,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _saving ? null : _pickAvatar,
                                        icon: const Icon(Icons.photo_camera_outlined),
                                        label: const Text('Đổi ảnh đại diện'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _displayNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Tên hiển thị',
                                    hintText: 'Nhập tên của bạn',
                                    prefixIcon: const Icon(Icons.badge_outlined),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _bioController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: 'Mô tả bản thân',
                                    hintText: 'Viết vài dòng giới thiệu về bạn',
                                    prefixIcon: const Icon(Icons.edit_note_rounded),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Thông báo',
                            icon: Icons.notifications_active_outlined,
                            child: Column(
                              children: [
                                _switchTile(
                                  title: 'Thông báo trong app',
                                  subtitle: 'Hiển thị chuông, badge và thông báo nội bộ',
                                  value: _inAppNotifications,
                                  onChanged: (value) =>
                                      setState(() => _inAppNotifications = value),
                                ),
                                const SizedBox(height: 10),
                                _switchTile(
                                  title: 'Thông báo qua email',
                                  subtitle: 'Nhận email khi có bình luận mới',
                                  value: _emailNotifications,
                                  onChanged: (value) =>
                                      setState(() => _emailNotifications = value),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Giao diện', 'Appearance'),
                            icon: Icons.palette_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('Chế độ hiển thị', 'Theme mode'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF344560),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _choiceChip('system', _t('Theo hệ thống', 'System')),
                                    _choiceChip('light', _t('Sáng', 'Light')),
                                    _choiceChip('dark', _t('Tối', 'Dark')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Ngôn ngữ', 'Language'),
                            icon: Icons.language_rounded,
                            child: DropdownButtonFormField<String>(
                              value: _languageCode,
                              items: [
                                DropdownMenuItem(
                                  value: 'vi',
                                  child: Text(_t('Tiếng Việt', 'Vietnamese')),
                                ),
                                const DropdownMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                              ],
                              onChanged: (value) {
                                final next = value ?? 'vi';
                                setState(() => _languageCode = next);
                                AppPreferences.apply(
                                  themeMode: _themeMode,
                                  languageCode: next,
                                );
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Về ứng dụng',
                            icon: Icons.info_outline_rounded,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FAFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFCFDBF3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.apps_rounded, color: Color(0xFF2859D6)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'KanbanFlow\nPhiên bản 1.0.0',
                                      style: TextStyle(
                                        height: 1.4,
                                        color: Color(0xFF1D2E45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : _saveSettings,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _saving
                  ? [Colors.grey.shade400, Colors.grey.shade400]
                  : [const Color(0xFF2F6BFF), const Color(0xFF00A3FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6BFF).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Lưu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _iconShell({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD7E2F3)),
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF233A59)),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF284B8D).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E66FF), Color(0xFF56A9FF)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF142C4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E4FA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F334F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.8,
                    color: Color(0xFF5A6E8D),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF2E66FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String value, String label) {
    final selected = _themeMode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _themeMode = value);
        AppPreferences.apply(
          themeMode: value,
          languageCode: _languageCode,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: selected ? const Color(0xFF2E66FF) : const Color(0xFFF4F7FC),
          border: Border.all(
            color: selected ? const Color(0xFF2E66FF) : const Color(0xFFD2DCEC),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E66FF).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF344560),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
