import 'dart:io';

import 'package:bs_firebase_auth/blocs/UserBloc/states.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final List<String> checkConflictFor;

  CreateUserEvent({this.email, this.password, this.checkConflictFor});
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
  final bool forceCreate;

  LoginWithEmailEvent({this.email, this.password, this.forceCreate = false});

  @override
  String toString() =>
      "${super.toString()} { email: $email, password: $password, forceCreate: $forceCreate}";
}

class LoginWithEmailLinkEvent extends LoginEvent {
  final String email;
  final String link;

  LoginWithEmailLinkEvent({this.link, this.email});

  @override
  String toString() =>
      "${super.toString()} { link: $link , email: $email }";
}

class LoginWithPhoneNumberEvent extends LoginEvent {
  final AuthCredential credential;
  final String verificationId;
  final String smsCode;
  final bool alreadyRegistered;

  LoginWithPhoneNumberEvent({this.credential, this.verificationId, this.smsCode, this.alreadyRegistered = false});

  @override
  String toString() =>
      "${super.toString()} { credential: $credential }";
}

class LinkWithPhoneNumberEvent extends LoginWithPhoneNumberEvent {
  LinkWithPhoneNumberEvent({AuthCredential credential, String verificationId, String smsCode, bool alreadyRegistered})
  :super(credential:credential, verificationId:verificationId, smsCode:smsCode, alreadyRegistered:alreadyRegistered);

  @override
  String toString() =>
      "${super.toString()}";
}

class DelegateStateEvent extends UserBlocEvent {
  final UserBlocState state;
  
  DelegateStateEvent({this.state});

  @override
  String toString() =>
      "${super.toString()} { state: $state }";
}

class VerifyPhoneNumberEvent extends LoginEvent {
  final String phoneNumber;
  final bool alreadyRegistered;

  VerifyPhoneNumberEvent({this.phoneNumber, this.alreadyRegistered = false});

  @override
  String toString() =>
      "${super.toString()} { phoneNumber: $phoneNumber }";
}

class LoginWithEmailAndLinkAccountEvent extends LoginWithEmailEvent {
  final AccountLinkingData accountLinkingData;

  LoginWithEmailAndLinkAccountEvent(
      {String email, String password, bool forceCreate, this.accountLinkingData})
      : super(email: email, password: password, forceCreate:forceCreate);

  @override
  String toString() =>
      "${super.toString()} { accountLinkingData: $accountLinkingData}";
}

class LoginWithEmailLinkAndLinkAccountEvent extends LoginWithEmailLinkEvent {
  final AccountLinkingData accountLinkingData;

  LoginWithEmailLinkAndLinkAccountEvent(
      {String link, this.accountLinkingData})
      : super(link: link);

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

class ResendVerificationEmailEvent extends UserBlocEvent {
  final String email;
  final String password;
  ResendVerificationEmailEvent({this.email, this.password});
}