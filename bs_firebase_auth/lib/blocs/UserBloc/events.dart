import 'dart:io';

import 'package:bs_firebase_auth/blocs/UserBloc/states.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

//
// Events
//

@immutable
abstract class UserBlocEvent {
  @override
  String toString() => runtimeType.toString();
}

class InitializeEvent extends UserBlocEvent {}

class UpdateUserProfileEvent<TUserProfile> extends UserBlocEvent {
  final TUserProfile input;
  final String displayName;
  final File profilePicture;

  UpdateUserProfileEvent({this.input, this.profilePicture, this.displayName});
}

class LogoutEvent extends UserBlocEvent {}

class CreateUserEvent extends UserBlocEvent {
  final String email;
  final String password;

  CreateUserEvent({this.email, this.password});
}

class LinkWithEmailCredentialEvent extends UserBlocEvent {
  final String email;
  final String password;

  LinkWithEmailCredentialEvent({this.email, this.password});
}

class DeleteUserEvent extends UserBlocEvent {}

class FirebaseDisconnectedLogoutEvent extends LogoutEvent {}

// Login events

abstract class LoginEvent extends UserBlocEvent {}

class LoginWithAnonymousEvent extends LoginEvent {}

class LoginWithFacebookEvent extends LoginEvent {
  final List<String> readOnlyScopes;

  LoginWithFacebookEvent({this.readOnlyScopes = const ["email"]});

  @override
  String toString() =>
      "${super.toString()} { readOnlyScopes: $readOnlyScopes }";
}

class LinkFacebookEvent extends LoginWithFacebookEvent {
  LinkFacebookEvent({List<String> readOnlyScopes})
      : super(readOnlyScopes: readOnlyScopes);
}

class LoginWithFacebookAndLinkAccountEvent extends LoginWithFacebookEvent {
  final AccountLinkingData accountLinkingData;

  LoginWithFacebookAndLinkAccountEvent(
      {List<String> readOnlyScopes, this.accountLinkingData})
      : super(readOnlyScopes: readOnlyScopes);

  @override
  String toString() =>
      "${super.toString()} { accountLinkingData: $accountLinkingData}";
}

class LoginWithEmailEvent extends LoginEvent {
  final String email;
  final String password;

  LoginWithEmailEvent({this.email, this.password});

  @override
  String toString() =>
      "${super.toString()} { email: $email, password: $password }";
}

class LoginWithEmailAndLinkAccountEvent extends LoginWithEmailEvent {
  final AccountLinkingData accountLinkingData;

  LoginWithEmailAndLinkAccountEvent(
      {String email, String password, this.accountLinkingData})
      : super(email: email, password: password);

  @override
  String toString() =>
      "${super.toString()} { accountLinkingData: $accountLinkingData}";
}

class LoginWithGoogleEvent extends LoginEvent {
  final List<String> scopes;

  LoginWithGoogleEvent({this.scopes = const ["email"]});

  @override
  String toString() => "${super.toString()} { scopes: $scopes }";
}

class LoginWithGoogleAndLinkAccountEvent extends LoginWithGoogleEvent {
  final AccountLinkingData accountLinkingData;

  LoginWithGoogleAndLinkAccountEvent(
      {List<String> scopes, this.accountLinkingData})
      : super(scopes: scopes);

  @override
  String toString() =>
      "${super.toString()} { accountLinkingData: $accountLinkingData}";
}

class PasswordResetEvent extends UserBlocEvent {
  final String email;
  PasswordResetEvent({this.email});
}
