// lib/pages/team/create_team_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/player/model_service.dart';
import 'player_search_page.dart';
import 'results_page.dart';

class CreateTeamPage extends StatefulWidget {
  const CreateTeamPage({super.key});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _picked = <PickedPlayer>[];
  Uint8List? _logoBytes;

  String? _error;
  bool _loading = false;
  bool _loadedSelf = false;

  Timer? _nameDebounce;
  bool _checkingName = false;
  bool _nameTaken = false;
  String? _nameErrorText;

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFF7F7F7);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  @override
  void initState() {
    super.initState();
    _loadSelf();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSelf() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final d = await FirebaseFirestore.instance.collection('Player').doc(uid).get();
      final data = d.data() ?? {};

      final me = PickedPlayer(
        uid: uid,
        name: (data['Name'] ?? '').toString(),
        photoUrl: (data['ProfilePhoto'] ?? '').toString(),
      );

      if (!mounted) return;
      setState(() {
        _picked
          ..clear()
          ..add(me);
        _loadedSelf = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadedSelf = true);
    }
  }

  ButtonStyle _primaryPill() {
    return ElevatedButton.styleFrom(
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ).copyWith(
      splashFactory: NoSplash.splashFactory,
      overlayColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
    );
  }

  ButtonStyle _secondaryPill() {
    return OutlinedButton.styleFrom(
      foregroundColor: _accent,
      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ).copyWith(
      splashFactory: NoSplash.splashFactory,
      overlayColor: MaterialStateProperty.all(Colors.transparent),
    );
  }

  ButtonStyle _darkPill() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF363435),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ).copyWith(
      splashFactory: NoSplash.splashFactory,
      overlayColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
    );
  }

  Future<bool> _showLeaveCreateTeamDialog() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCFD9DE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2),
                  ),
                  child: const Icon(Icons.logout_rounded, color: _accent, size: 32),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your progress will not be saved. Are you sure you want to leave?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF0F1419),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF536471),
                          side: const BorderSide(color: Color(0xFFCFD9DE)),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Leave',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldLeave ?? false;
  }

  Future<void> _showLimitReachedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCFD9DE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 2),
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: _accent, size: 32),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You can add up to 4 players. Remove someone or press Done.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF0F1419),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCFD9DE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2),
                ),
                child: const Icon(Icons.info_outline_rounded, color: _accent, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF0F1419),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
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
    );
  }

  void _onNameChanged() {
    _nameDebounce?.cancel();

    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      setState(() {
        _checkingName = false;
        _nameTaken = false;
        _nameErrorText = null;
      });
      return;
    }

    _nameDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _checkTeamNameTaken(name);
    });
  }

  Future<void> _checkTeamNameTaken(String name) async {
    try {
      if (!mounted) return;
      setState(() {
        _checkingName = true;
      });

      final snap = await FirebaseFirestore.instance
          .collection('Team')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (!mounted) return;

      final taken = snap.docs.isNotEmpty;

      setState(() {
        _checkingName = false;
        _nameTaken = taken;
        _nameErrorText = taken ? 'This team name is already taken' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingName = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final xf = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (xf == null) return;
      final bytes = await xf.readAsBytes();
      if (!mounted) return;
      setState(() => _logoBytes = bytes);
    } catch (e) {
      _showInfoDialog(title: 'Image Error', message: e.toString());
    }
  }

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

    if (!mounted || res == null || res.isEmpty) return;

    setState(() {
      final selfUid = FirebaseAuth.instance.currentUser?.uid;
      if (selfUid != null) {
        final idx = _picked.indexWhere((p) => p.uid == selfUid);
        if (idx != -1 && idx != 0) {
          final self = _picked.removeAt(idx);
          _picked.insert(0, self);
        }
      }

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
      final name = _nameCtrl.text.trim();

      if (name.isEmpty) {
        _showInfoDialog(
          title: 'Add Team Name',
          message: 'Please enter a name for your team before viewing the winrate.',
        );
        return;
      }

      if (_nameTaken) {
        if (!mounted) return;
        setState(() {
          _nameErrorText = 'This team name is already taken';
        });
        return;
      }

      if (_picked.length < 5) {
        _showInfoDialog(
          title: 'Add More Players',
          message: 'You need exactly 5 players to compute team winrate.',
        );
        return;
      }

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
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ImageProvider<Object>? _avatarProvider(String raw) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return NetworkImage(raw);

    try {
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return null;
    }
  }

  Widget _fieldBlock({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? errorText,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: const Color(0xFF363435),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _text,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: _accent,
              fontWeight: FontWeight.w700,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1,
              color: Color(0xFFB3261E),
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _accent, width: 2.0),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB3261E), width: 1.6),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFB3261E), width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _showLeaveCreateTeamDialog();
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF363435),
            ),
            onPressed: () async {
              final leave = await _showLeaveCreateTeamDialog();
              if (leave && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Create Team',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _accent,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
        ),
        body: !_loadedSelf
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _teamLogo(),
                    const SizedBox(height: 26),

                    _fieldBlock(
                      label: 'Name',
                      controller: _nameCtrl,
                      maxLines: 1,
                      errorText: _nameTaken ? _nameErrorText : null,
                      suffix: _checkingName
                          ? const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFEB3D24),
                                ),
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 18),

                    _fieldBlock(
                      label: 'Describe your team',
                      controller: _descCtrl,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 22),

                    _searchPlayerBarSmall(),
                    const SizedBox(height: 22),

                    const Text(
                      'Your Team',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _yourTeamContainer(),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFB3261E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),

                    Center(
                      child: SizedBox(
                        width: 210,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_loading || _nameTaken || _checkingName) ? null : _runModel,
                          style: _darkPill(),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _teamLogo() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2.2),
            ),
            child: ClipOval(
              child: _logoBytes == null
                  ? const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 54,
                        color: Color(0xFF1F1F1F),
                      ),
                    )
                  : Image.memory(_logoBytes!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: -2,
            bottom: 8,
            child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchPlayerBarSmall() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: GestureDetector(
          onTap: () {
            if (_picked.length >= 5) {
              _showLimitReachedDialog();
              return;
            }
            _openSearch();
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Search Player',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _yourTeamContainer() {
    final selfUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.15), width: 1.5),
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 30,
          runSpacing: 12,
          children: List.generate(5, (i) {
            final hasPlayer = i < _picked.length;
            final photo = hasPlayer ? _picked[i].photoUrl : '';
            final provider = hasPlayer ? _avatarProvider(photo) : null;
            final name = hasPlayer ? _picked[i].name : '';

            return SizedBox(
              width: 54,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _accent, width: 2.2),
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: provider == null
                              ? const Icon(Icons.person, color: Colors.black38, size: 24)
                              : Image(image: provider, fit: BoxFit.cover),
                        ),
                      ),
                      if (hasPlayer && _picked[i].uid != selfUid)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _picked.removeAt(i)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D2D2D),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.isEmpty ? '-' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _text,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}