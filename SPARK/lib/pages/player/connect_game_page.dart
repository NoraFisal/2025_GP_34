import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/data/riot_link_service.dart';
import '/ui/components/bg_scaffold.dart';
import '/ui/components/mini_side_nav.dart';

enum GamePick { lol, valorant }

class ConnectGamePage extends StatefulWidget {
  const ConnectGamePage({super.key});
  @override
  State<ConnectGamePage> createState() => _ConnectGamePageState();
}

class _ConnectGamePageState extends State<ConnectGamePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _tagCtrl  = TextEditingController();

  bool _loading = false;
  String? _error;
  GamePick? _pick;

  @override
  void dispose() { _nameCtrl.dispose(); _tagCtrl.dispose(); super.dispose(); }

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter Riot username';
    if (!RegExp(r'^[A-Za-z0-9 _.\-]{3,16}$').hasMatch(s)) return '3–16 characters';
    return null;
  }
  String? _vTag(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter tag (e.g., NA1 / EUW / Z10)';
    if (!RegExp(r'^[A-Za-z0-9]{2,5}$').hasMatch(s)) return '2–5 letters/numbers';
    return null;
  }

  Future<void> _onConnect() async {
    if (_pick == null || _pick != GamePick.lol) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick LoL first')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _loading = true; _error = null; });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('You must be signed in.');

      final svc = RiotLinkService(FirebaseFirestore.instance);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Step 1/3: linking…')));
      await svc.connectLoL(playerId: uid, gameName: _nameCtrl.text, tagLine: _tagCtrl.text);

      // remove any manual roleStats you previously added so results are accurate
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Step 2/3: clearing old role stats…')));
      await svc.clearRoleStats(uid);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Step 3/3: pulling 50 matches…')));
      await svc.buildSeedsForLinkedLol(
        playerId: uid,
        maxMatches: 50,          // ← 50 like Colab
        forceRefresh: true,      // ensure we rebuild
        allowNonRankedIfEmpty: true, // helpful for NA1 testing
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done: roleStats saved ✅')));
      Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BgScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Connect Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text('Games', textAlign: TextAlign.center,
                    style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gameCard(label: 'LoL', asset: 'assets/images/lol.png',
                        selected: _pick == GamePick.lol, onTap: () => setState(()=>_pick = GamePick.lol)),
                      const SizedBox(width: 18),
                      _gameCard(label: 'Valorant', asset: 'assets/images/valorant.png',
                        selected: _pick == GamePick.valorant, onTap: () => setState(()=>_pick = GamePick.valorant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_pick != null)
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Username', style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _pillField(controller: _nameCtrl, hint: 'Riot Username', validator: _vName, theme: t),
                          const SizedBox(height: 14),
                          Text('Tag', style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _pillField(controller: _tagCtrl, hint: 'e.g., NA1 / EUW / Z10', validator: _vTag,
                            theme: t, textCapitalization: TextCapitalization.characters),
                          const SizedBox(height: 18),
                          if (_error != null) Text(_error!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.error)),
                          const SizedBox(height: 6),
                          _glowButton(text: 'connect', onPressed: _loading ? null : _onConnect, loading: _loading),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(left: 0, top: kToolbarHeight + 20, child: MiniSideNav(top: kToolbarHeight + 20, left: 0)),
        ],
      ),
    );
  }

  // helpers
  Widget _gameCard({required String label, required String asset, required bool selected, VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1),
          ),
          width: 98, height: 78,
          child: ClipRRect(borderRadius: BorderRadius.circular(14),
            child: Image.asset(asset, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(child: Text(label, style: const TextStyle(color: Colors.white70))),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 12, height: 12,
          decoration: BoxDecoration(color: selected ? Colors.white : Colors.white24, shape: BoxShape.circle)),
      ]),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller, validator: validator, textCapitalization: textCapitalization,
      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint, hintStyle: theme.textTheme.bodyLarge?.copyWith(color: Colors.black45),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _glowButton({required String text, VoidCallback? onPressed, bool loading = false}) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x33B6382B), blurRadius: 16, spreadRadius: 2)],
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB6382B), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          disabledBackgroundColor: const Color(0xFFB6382B).withOpacity(.4),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text.toLowerCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .5)),
      ),
    );
  }
}
