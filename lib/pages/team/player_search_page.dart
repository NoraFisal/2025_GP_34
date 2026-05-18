// lib/ui/player_search_page.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/player/model_service.dart';
import '../player/player_profile_view_page.dart';

class PlayerSearchPage extends StatefulWidget {
  final Set<String> already;
  final int limit;

  const PlayerSearchPage({
    super.key,
    required this.already,
    this.limit = 4,
  });

  @override
  State<PlayerSearchPage> createState() => _PlayerSearchPageState();
}

class _PlayerSearchPageState extends State<PlayerSearchPage> {
  final _queryCtrl = TextEditingController();
  final _picked = <PickedPlayer>[];

  static const Color _accent = Color.fromRGBO(235, 61, 36, 1);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _text = Color(0xFF0F1419);
  static const Color _muted = Color(0xFF536471);
  static const Color _line = Color(0xFFCFD9DE);
  static const Color _chip = Color(0xFFF0F3F4);
  static const Color _dark = Color.fromRGBO(54, 52, 53, 1);

  static const double _maxContentWidth = 360;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
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

  Future<List<PickedPlayer>> _runQuery(String q) async {
    final col = FirebaseFirestore.instance.collection('Player');
    Query<Map<String, dynamic>> qy = col.orderBy('Name');

    if (q.trim().isNotEmpty) {
      final s = q.trim();
      qy = col.orderBy('Name').startAt([s]).endAt(['$s\uf8ff']);
    }

    final snap = await qy.limit(40).get();

    final out = <PickedPlayer>[];
    for (final d in snap.docs) {
      if (widget.already.contains(d.id)) continue;
      
      out.add(
        PickedPlayer(
          uid: d.id,
          name: (d.data()['Name'] ?? '').toString(),
          photoUrl: (d.data()['ProfilePhoto'] ?? '').toString(),
        ),
      );
    }
    return out;
  }

  void _toggle(PickedPlayer p) {
    setState(() {
      final i = _picked.indexWhere((x) => x.uid == p.uid);

      if (i >= 0) {
        _picked.removeAt(i);
        return;
      }

      if (_picked.length >= widget.limit) {
        _showLimitDialog();
        return;
      }

      _picked.add(p);
    });
  }

  void _navigateToProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewPlayerProfilePage(userId: uid)),
    );
  }

  Future<void> _showLimitDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: _accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Limit reached',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You can add ${widget.limit} players.\nRemove someone or press Done',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          onPressed: () => Navigator.pop(context, _picked),
        ),
        title: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 36,
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    onChanged: (_) => setState(() {}),
                    cursorColor: _accent,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _text,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Search',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: FutureBuilder<List<PickedPlayer>>(
                    future: _runQuery(_queryCtrl.text),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: _accent),
                        );
                      }

                      final items = snap.data!;
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            'No players found',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: _muted,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final p = items[i];
                          final selected = _picked.any((x) => x.uid == p.uid);
                          return _playerCard(p: p, selected: selected);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: SizedBox(
                width: 210,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCard({required PickedPlayer p, required bool selected}) {
    final avatar = _avatarProvider(p.photoUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigateToProfile(p.uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 2.4),
              ),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFFEFEFEF),
                  child: avatar == null
                      ? const Icon(Icons.person, color: Colors.black38, size: 24)
                      : Image(image: avatar, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.name.isEmpty ? 'Player Name' : p.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _text,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            _CircleToggleButton(
              selected: selected,
              accent: _accent,
              dark: _dark,
              onTap: () => _toggle(p),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleToggleButton extends StatefulWidget {
  final bool selected;
  final Color accent;
  final Color dark;
  final VoidCallback onTap;

  const _CircleToggleButton({
    required this.selected,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  @override
  State<_CircleToggleButton> createState() => _CircleToggleButtonState();
}

class _CircleToggleButtonState extends State<_CircleToggleButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.selected ? widget.accent : widget.dark;
    final bg = _hover ? Colors.white : baseColor;
    final fg = _hover ? widget.accent : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _pressed ? 0.94 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? 0.16 : 0.10),
                  blurRadius: _hover ? 10 : 8,
                ),
              ],
            ),
            child: Icon(
              widget.selected ? Icons.remove : Icons.add,
              color: fg,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}