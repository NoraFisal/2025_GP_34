// lib/ui/create_team_page.dart
import 'dart:typed_data';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '../../services/player/model_service.dart';
import 'player_search_page.dart';
import 'results_page.dart';

class CreateTeamPage extends StatefulWidget {
  const CreateTeamPage({super.key});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  /// First slot is always the current user; then you can add up to 4 more.
  final _picked = <PickedPlayer>[];
  Uint8List? _logoBytes;

  String? _error;
  bool _loading = false;
  bool _loadedSelf = false;

  @override
  void initState() {
    super.initState();
    _loadSelf();
  }

  Future<void> _loadSelf() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final d =
          await FirebaseFirestore.instance.collection('Player').doc(uid).get();
      final data = d.data() ?? {};

      final me = PickedPlayer(
        uid: uid,
        name: (data['Name'] ?? '').toString(),
        photoUrl: (data['ProfilePhoto'] ?? '').toString(),
      );

      setState(() {
        _picked
          ..clear()
          ..add(me);
        _loadedSelf = true;
      });
    } catch (_) {
      setState(() => _loadedSelf = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ===== Exit confirmation dialog =====
  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.05),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB6382B).withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Color(0xFFB6382B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Leave Create Team?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your progress will not be saved.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(.2),
                            width: 1,
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB6382B).withOpacity(.3),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB6382B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Leave',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return shouldPop ?? false;
  }

  // ===== Image picker (web & mobile) =====
  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? xf = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (xf == null) return;
      final bytes = await xf.readAsBytes();
      setState(() => _logoBytes = bytes);
    } catch (e) {
      _showPopup(title: 'Image Error', message: e.toString());
    }
  }

  // ===== Search players (keep previous selections, avoid loop) =====
  Future<void> _openSearch() async {
    final res = await Navigator.push<List<PickedPlayer>>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerSearchPage(
          already: _picked.map((e) => e.uid).toSet(),
          limit: 4,
        ),
      ),
    );

    // user pressed back or nothing selected
    if (!mounted || res == null || res.isEmpty) return;

    setState(() {
      // always keep current user as first slot
      final selfUid = FirebaseAuth.instance.currentUser?.uid;
      if (selfUid != null) {
        final idx = _picked.indexWhere((p) => p.uid == selfUid);
        if (idx != -1 && idx != 0) {
          final self = _picked.removeAt(idx);
          _picked.insert(0, self);
        }
      }

      // add new players, but don't remove existing ones, max 5 total
      for (final p in res) {
        final already = _picked.any((x) => x.uid == p.uid);
        if (!already && _picked.length < 5) {
          _picked.add(p);
        }
      }
    });
  }

  Future<void> _runModel() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      // team name required before winrate
      if (_nameCtrl.text.trim().isEmpty) {
        _showPopup(
          title: 'Add Team Name',
          message:
              'Please enter a name for your team before viewing the winrate.',
        );
        return;
      }

      if (_picked.length < 5) {
        _showPopup(
          title: 'Add More Players',
          message: 'You need exactly 5 players to compute team winrate.',
        );
        return;
      }

      // 🔹 ما نستخدم assignments أبدًا هنا
      // ModelService موجود لو احتجتوه لاحقاً، لكن ResultsPage تحسب كل شيء بنفسها الآن

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsPage(
            roster: _picked,
            teamName: _nameCtrl.text,
            description: _descCtrl.text,
            logoBytes: _logoBytes,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPopup({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(.15), width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.05),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB6382B).withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFB6382B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB6382B).withOpacity(.3),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB6382B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: BgScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Create Team'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: !_loadedSelf
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: _pickLogo,
                              child: Container(
                                width: 140,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white24),
                                  image: _logoBytes == null
                                      ? null
                                      : DecorationImage(
                                          image: MemoryImage(_logoBytes!),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                child: _logoBytes == null
                                    ? const Center(
                                        child: Icon(
                                          Icons.photo_camera_outlined,
                                          color: Colors.white70,
                                          size: 32,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _pillField(
                            controller: _nameCtrl,
                            hint: 'Team name',
                            theme: t,
                          ),
                          const SizedBox(height: 14),
                          _multilineField(
                            controller: _descCtrl,
                            hint: 'Describe your team',
                            theme: t,
                          ),
                          const SizedBox(height: 14),
                          _searchBar(t, onTap: _openSearch),
                          const SizedBox(height: 16),
                          Text(
                            'Your Team',
                            style: t.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _teamStrip(t),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: t.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _glowButton(
                            text: 'show winrate',
                            onPressed: _loading ? null : _runModel,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: kToolbarHeight + 20,
                    child: MiniSideNav(top: kToolbarHeight + 20, left: 0),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------- Search bar (block when 5 players) ----------
  Widget _searchBar(ThemeData t, {required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        if (_picked.length >= 5) {
          _showPopup(
            title: 'Team is full',
            message:
                'You already have 5 players.\nRemove a player first if you want to change the lineup.',
          );
          return;
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search players',
                style: t.textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
            ),
            const Icon(Icons.tune, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // ---------- Avatar helper (URL or base64) ----------
  ImageProvider<Object>? _avatarProvider(String raw) {
    if (raw.isEmpty) return null;

    if (raw.startsWith('http')) {
      return NetworkImage(raw);
    }
    try {
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  // ---------- Team strip with red X ----------
  Widget _teamStrip(ThemeData t) {
    final selfUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < 5; i++)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (_) {
                        final photo =
                            (i < _picked.length) ? _picked[i].photoUrl : '';
                        final avatarProvider = _avatarProvider(photo);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white12,
                              backgroundImage: avatarProvider,
                              child: avatarProvider == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            if (i < _picked.length &&
                                _picked[i].uid != selfUid)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _picked.removeAt(i);
                                    });
                                  },
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB6382B),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFB6382B)
                                              .withOpacity(.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i < _picked.length ? _picked[i].name : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _multilineField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _glowButton({
    required String text,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x33B6382B),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB6382B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          disabledBackgroundColor: const Color(0xFFB6382B).withOpacity(.4),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text.toLowerCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
      ),
    );
  }
}
