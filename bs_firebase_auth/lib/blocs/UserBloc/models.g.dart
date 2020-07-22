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
      'user': toJsonUser(instance.user),
      'tryLoginAtLoad': instance.tryLoginAtLoad,
      'provider': _$ProviderEnumMap[instance.provider],
      'facebookAccessToken': instance.facebookAccessToken,
      'googleIdToken': instance.googleIdToken,
      'googleAccessToken': instance.googleAccessToken,
      'password': instance.password,
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$ProviderEnumMap = {
  Provider.facebook: 'facebook',
  Provider.google: 'google',
  Provider.email: 'email',
  Provider.anonymous: 'anonymous',
  Provider.phone: 'phone',
};

User<TUserProfile> _$UserFromJson<TUserProfile>(Map<String, dynamic> json) {
  return User<TUserProfile>()
    ..email = json['email'] as String
    ..uid = json['uid'] as String
    ..userName = json['userName'] as String
    ..displayName = json['displayName'] as String
    ..profilePictureUrl = json['profilePictureUrl'] as String
    ..currency = json['currency'] as String
    ..phoneNumber = json['phoneNumber'] as String
    ..userProfile = _fromJsonProfile(json['userProfile']);
}

Map<String, dynamic> _$UserToJson<TUserProfile>(User<TUserProfile> instance) =>
    <String, dynamic>{
      'email': instance.email,
      'uid': instance.uid,
      'userName': instance.userName,
      'displayName': instance.displayName,
      'profilePictureUrl': instance.profilePictureUrl,
      'currency': instance.currency,
      'phoneNumber': instance.phoneNumber,
      'userProfile': _toJsonProfile(instance.userProfile),
    };
