// lib/data/user_repo.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class UserProfileModel {
  String username;
  int age; // stored int age (what your UI/repo already uses)
  String city;
  List<String> games;
  String? photoLocal;        // local asset/path for avatar
  DateTime? dob;             // optional, for future Firebase use

  UserProfileModel({
    required this.username,
    required this.age,
    required this.city,
    required this.games,
    this.photoLocal,
    this.dob,
  });

  /// If DOB is set, compute age on the fly; otherwise fall back to stored age.
  int get ageEffective => dob != null ? _calcAge(dob!) : age;

  // Private helper that fixes the “_calcAge isn’t defined” error.
  int _calcAge(DateTime d) {
    final now = DateTime.now();
    int years = now.year - d.year;
    final hadBirthday =
        (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hadBirthday) years--;
    return years.clamp(0, 200);
  }

  UserProfileModel copyWith({
    String? username,
    int? age,
    String? city,
    List<String>? games,
    String? photoLocal,
    DateTime? dob,
  }) {
    return UserProfileModel(
      username: username ?? this.username,
      age: age ?? this.age,
      city: city ?? this.city,
      games: games ?? this.games,
      photoLocal: photoLocal ?? this.photoLocal,
      dob: dob ?? this.dob,
    );
  }
}

class UserRepo extends ChangeNotifier {
  // Demo user
  UserProfileModel _me = UserProfileModel(
    username: 'Username',
    age: 21,
    city: 'Riyadh',
    games: const ['League of Legends', 'VALORANT'],
    photoLocal: null,
    dob: null, // you can set a real DateTime later
  );

  UserProfileModel get me => _me;

  // If other pages call getById, just return _me for now.
  UserProfileModel? getById(String id) => _me;

  /// Unified update with named params.
  void updateMe({
    String? username,
    int? age,
    String? city,
    List<String>? games,
    String? photoLocal,
    DateTime? dob,
  }) {
    _me = _me.copyWith(
      username: username,
      age: age,
      city: city,
      games: games,
      photoLocal: photoLocal,
      dob: dob,
    );
    notifyListeners();
  }

  // helper for main.dart demos, optional
  static UserRepo sample() => UserRepo();
}

/// Simple inherited provider for the repo.
class UserRepoProvider extends InheritedNotifier<UserRepo> {
  const UserRepoProvider({
    super.key,
    required UserRepo repo,
    required Widget child,
  }) : super(notifier: repo, child: child);

  static UserRepo of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<UserRepoProvider>();
    assert(p != null, 'UserRepoProvider not found in widget tree');
    return p!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant InheritedNotifier<UserRepo> oldWidget) => true;
}
