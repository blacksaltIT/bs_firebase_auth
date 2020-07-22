import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'models.g.dart';

enum Provider { facebook, google, email, anonymous, phone }

abstract class UserProfileManagerModel<TUserProfile> {
  Future<TUserProfile> create(String authToken, User<TUserProfile> user);
  TUserProfile fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(TUserProfile userP);
  Future<TUserProfile> merge(TUserProfile partial, TUserProfile full, User<TUserProfile> user);
}

typedef ToJsonCallback<T> = Map<String, dynamic> Function(T);
typedef FromJsonCallback<T> = T Function(Map<String, dynamic>);
typedef CreateCallback<T> = T Function();

Function toJsonProfile;
Function fromJsonProfile;

Map<String, dynamic> toJsonUser<T>(dynamic u) => _$UserToJson<T>(u as User<T>);
dynamic _toJsonProfile(dynamic u) => toJsonProfile?.call(u);
dynamic _fromJsonProfile(dynamic u) => fromJsonProfile?.call(u);

@JsonSerializable()
class BlocData<TUserProfile> with EquatableMixin {
  static Logger _logger = Logger("salty_auth.blocs.UserBloc.BlocData");

  @JsonKey(toJson: toJsonUser)
  User<TUserProfile> user;
  bool tryLoginAtLoad = false;
  Provider provider;
  String facebookAccessToken;
  String googleIdToken;
  String googleAccessToken;
  String password;

  BlocData() {
    user = User();
  }

  @override
  List get props {
    return <dynamic>[
      user,
      tryLoginAtLoad,
      provider,
      facebookAccessToken,
      googleIdToken,
      googleAccessToken,
      password,
    ];
  }

  BlocData<TUserProfile> clone() => BlocData.fromJson(toJson());
  factory BlocData.fromJson(Map<String, dynamic> json) =>
      _$BlocDataFromJson(json);
  Map<String, dynamic> toJson() => _$BlocDataToJson(this);

  static Future<BlocData<TUserProfile>> getOrCreate<TUserProfile>(
      String sharedPreferencesKey) async {
    return loadFromSharedPreferences<TUserProfile>(
      sharedPreferencesKey,
    );
  }

  int _lastSaveHashCode;

  static Future<BlocData<TUserProfile>> loadFromSharedPreferences<TUserProfile>(
      String sharedPreferencesKey) async {
    return Future.sync(() async {
      BlocData<TUserProfile> persistentData;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String jsonEncodedData = prefs.getString(sharedPreferencesKey);

      if (jsonEncodedData == null) {
        persistentData = BlocData<TUserProfile>();
        _logger.finest(() =>
            "getOrCreate: Stored data not found, create new PersistentData");
        await prefs.setString(sharedPreferencesKey, jsonEncode(persistentData));
      } else
        persistentData = BlocData.fromJson(
            jsonDecode(jsonEncodedData) as Map<String, dynamic>);

      persistentData._lastSaveHashCode = persistentData.hashCode;
      _logger.finest(() => "getOrCreate: returning $persistentData");
      return persistentData;
    });
  }

  Future<void> persist(String sharedPreferencesKey) async {
    return Future.sync(() async {
      int currentHashCode = hashCode;

      if (_lastSaveHashCode != currentHashCode) {
        _logger.finest(() =>
            "persist: Hash code mismatch (last: $_lastSaveHashCode, current: $currentHashCode). Data: $this");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(sharedPreferencesKey, jsonEncode(this));
        _lastSaveHashCode = currentHashCode;
      }
    });
  }

  @override
  String toString() =>
      "BlocData { user: $user, tryLoginAtLoad: $tryLoginAtLoad, provider: $provider }";
}

@JsonSerializable()
class User<TUserProfile> with EquatableMixin {
  String email;
  String uid;
  String userName;
  String displayName;
  String profilePictureUrl;
  String currency;
  String phoneNumber;
  List<String> providers;

  @JsonKey(toJson: _toJsonProfile, fromJson: _fromJsonProfile)
  TUserProfile userProfile;

  User();

  @override
  List get props {
    return <dynamic>[
      userName,
      uid,
      email,
      displayName,
      profilePictureUrl,
      currency,
      userProfile,
      providers,
      phoneNumber
    ];
  }

  factory User.clone(User<TUserProfile> other) => User.fromJson(other.toJson());
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  String toString() => "User { userName: $userName, email: $email, phoneNumber: $phoneNumber }";
}
