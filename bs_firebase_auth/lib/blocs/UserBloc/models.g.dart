// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlocData<TUserProfile> _$BlocDataFromJson<TUserProfile>(
    Map<String, dynamic> json) {
  return BlocData<TUserProfile>()
    ..user = json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>)
    ..tryLoginAtLoad = json['tryLoginAtLoad'] as bool
    ..provider = _$enumDecodeNullable(_$ProviderEnumMap, json['provider'])
    ..facebookAccessToken = json['facebookAccessToken'] as String
    ..googleIdToken = json['googleIdToken'] as String
    ..googleAccessToken = json['googleAccessToken'] as String
    ..password = json['password'] as String;
}

Map<String, dynamic> _$BlocDataToJson<TUserProfile>(
        BlocData<TUserProfile> instance) =>
    <String, dynamic>{
      'user': instance.user == null ? null : toJsonUser(instance.user),
      'tryLoginAtLoad': instance.tryLoginAtLoad,
      'provider': _$ProviderEnumMap[instance.provider],
      'facebookAccessToken': instance.facebookAccessToken,
      'googleIdToken': instance.googleIdToken,
      'googleAccessToken': instance.googleAccessToken,
      'password': instance.password
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$ProviderEnumMap = <Provider, dynamic>{
  Provider.facebook: 'facebook',
  Provider.google: 'google',
  Provider.email: 'email'
};

User<TUserProfile> _$UserFromJson<TUserProfile>(Map<String, dynamic> json) {
  return User<TUserProfile>()
    ..email = json['email'] as String
    ..userName = json['userName'] as String
    ..displayName = json['displayName'] as String
    ..profilePictureUrl = json['profilePictureUrl'] as String
    ..currency = json['currency'] as String
    ..userProfile = json['userProfile'] == null
        ? null
        : _fromJsonProfile(json['userProfile']);
}

Map<String, dynamic> _$UserToJson<TUserProfile>(User<TUserProfile> instance) =>
    <String, dynamic>{
      'email': instance.email,
      'userName': instance.userName,
      'displayName': instance.displayName,
      'profilePictureUrl': instance.profilePictureUrl,
      'currency': instance.currency,
      'userProfile': instance.userProfile == null
          ? null
          : _toJsonProfile(instance.userProfile)
    };
