// lib/ui/player_search_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // 👈 add this
import 'package:flutter/material.dart';

import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';
import '../../services/player/model_service.dart';
import '../player/player_profile_view_page.dart';

class PlayerSearchPage extends StatefulWidget {
  /// IDs that must not be offered (e.g., already selected + self).
  final Set<String> already;

  /// How many players you can still add (usually 4 because self is prefilled).
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

  ImageProvider<Object>? _avatarProvider(String raw) {
    if (raw.isEmpty) return null;

    // URL
    if (raw.startsWith('http')) {
      return NetworkImage(raw);
    }

    // Base64 (like your profile page)
    try {
      return MemoryImage(base64Decode(raw.split(',').last));
    } catch (_) {
      return null;
    }
  }
  
  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<List<PickedPlayer>> _runQuery(String q) async {
    final col = FirebaseFirestore.instance.collection('Player');
    Query<Map<String, dynamic>> qy = col.orderBy('Name');

    if (q.trim().isNotEmpty) {
      final s = q.trim();
      qy = col
          .orderBy('Name')
          .startAt([s])
          .endAt(['$s\uf8ff']);
    }

    final snap = await qy.limit(40).get();
    final out = <PickedPlayer>[];
    for (final d in snap.docs) {
      if (widget.already.contains(d.id)) continue; // exclude self + already picked
      out.add(PickedPlayer(
        uid: d.id,
        name: (d.data()['Name'] ?? '').toString(),
        photoUrl: (d.data()['ProfilePhoto'] ?? '').toString(),
      ));
    }
    return out;
  }

  void _toggle(PickedPlayer p) {
    setState(() {
      final i = _picked.indexWhere((x) => x.uid == p.uid);
      if (i >= 0) {
        _picked.removeAt(i);
      } else {
        if (_picked.length >= widget.limit) {
          _showPopup(
            title: 'Limit reached',
            message: 'You can only add ${widget.limit} players.\n'
                'Remove someone or press Done.',
          );
          return;
        }
        _picked.add(p);
      }
    });
  }

  void _navigateToProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewPlayerProfilePage(userId: uid),
      ),
    );
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
    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, _picked),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  _searchBar(t),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<PickedPlayer>>(
                      future: _runQuery(_queryCtrl.text),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        final items = snap.data!;
                        if (items.isEmpty) {
                          return Center(
                            child: Text('No players found',
                              style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = items[i];
                            final selected = _picked.any((x) => x.uid == p.uid);
                            return InkWell(
                              onTap: () => _navigateToProfile(p.uid),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    Builder(
  builder: (_) {
    final avatar = _avatarProvider(p.photoUrl);
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white12,
      backgroundImage: avatar,
      child: avatar == null
          ? const Icon(Icons.person, color: Colors.white54)
          : null,
    );
  },
),

                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(p.name,
                                          style: t.textTheme.titleMedium?.copyWith(
                                              color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                    InkWell(
                                      onTap: () => _toggle(p),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.white24
                                              : const Color(0xFFB6382B),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          selected ? 'remove' : 'add',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
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
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _confirmButton(),
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
    );
  }

  Widget _searchBar(ThemeData t) {
    return TextField(
      controller: _queryCtrl,
      onChanged: (_) => setState(() {}), // live refresh
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        hintText: 'Search players',
        hintStyle: t.textTheme.bodyLarge?.copyWith(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
      style: t.textTheme.bodyLarge?.copyWith(color: Colors.white),
    );
  }

  Widget _confirmButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
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
          onPressed: () => Navigator.pop(context, _picked),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB6382B),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: const Text(
            'Done',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: .5,
            ),
          ),
        ),
      ),
    );
  }
}