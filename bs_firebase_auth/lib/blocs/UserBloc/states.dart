import 'package:bs_firebase_auth/blocs/UserBloc/events.dart';
import 'package:bs_firebase_auth/blocs/UserBloc/models.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';

@immutable
abstract class UserBlocState extends Equatable {
  final List<Object> _props;
  UserBlocState([this._props = const <dynamic>[]]) : super();

  @override
  List<Object> get props => _props;

  @override
  String toString() => runtimeType.toString();
}

class UninitializedState extends UserBlocState {}

// error states

class ErrorState extends UserBlocState {
  final dynamic error;

  ErrorState({this.error}) : super(<dynamic>[error]);

  @override
  String toString() => "${super.toString()} { error: $error }";
}

class LoginErrorState extends ErrorState {
  final UserBlocEvent loginEvent;

  LoginErrorState({@required dynamic error, @required this.loginEvent})
      : super(error: error);
}

class UpdateErrorState extends ErrorState {
  final UserBlocEvent updateEvent;

  UpdateErrorState({@required dynamic error, @required this.updateEvent})
      : super(error: error);
}

class DeleteErrorState extends ErrorState {
  final UserBlocEvent deleteEvent;

  DeleteErrorState({@required dynamic error, @required this.deleteEvent})
      : super(error: error);
}

class CreateErrorState extends ErrorState {
  final UserBlocEvent createEvent;

  CreateErrorState({@required dynamic error, @required this.createEvent})
      : super(error: error);
}

// not logged in states
class AccountLinkingData {
  final String email;
  final AuthCredential credential;
  final Provider provider;

  AccountLinkingData(
      {@required this.email,
      @required this.credential,
      @required this.provider});

  @override
  String toString() =>
      "${super.toString()} { email: $email, credential: $credential, provider: $provider }";
}

class GuestUserState extends UserBlocState {
  GuestUserState({List props = const <dynamic>[]}) : super(props);
}

class JustLoggedOutGuestUserState<TUserProfile> extends GuestUserState {
  final LoggedInUserState<TUserProfile> loggedInState;

  JustLoggedOutGuestUserState({@required this.loggedInState})
      : super(props: <dynamic>[loggedInState]);
}

class JustRegisteredGuestUserState extends GuestUserState {}

class JustResetEmailSentGuestUserState extends GuestUserState {}

class JustResentVerificationEmailGuestUserState extends GuestUserState {}

class LinkingNecessaryState extends GuestUserState {
  final AccountLinkingData accountLinkingData;

  LinkingNecessaryState({this.accountLinkingData})
      : super(props: <dynamic>[accountLinkingData]);

  @override
  String toString() =>
      "${super.toString()} { accountLinkingData: $accountLinkingData }";
}

class LoginCanceledState extends GuestUserState {
  final UserBlocEvent loginEvent;

  LoginCanceledState({@required this.loginEvent})
      : super(props: <dynamic>[loginEvent]);

  @override
  String toString() => "${super.toString()} { event: $loginEvent }";
}

// logged in states

class LoggedInUserState<TUserProfile> extends UserBlocState {
  final User<TUserProfile> user;
  final bool justLoggedIn;
  final UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent;

  LoggedInUserState(List props,
      {this.user, this.justLoggedIn = false, this.updateUserProfileEvent})
      : super(<dynamic>[user, justLoggedIn] + props);

  @override
  String toString() =>
      "${super.toString()} { user: $user, justLoggedIn: $justLoggedIn }";
}

class LoggedInWithAnonymousUserState<TUserProfile>
    extends LoggedInUserState<TUserProfile> {
  final bool justLinked;
  LoggedInWithAnonymousUserState(
      {this.justLinked,
      User<TUserProfile> user,
      bool justLoggedIn = false,
      UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent})
      : super(<dynamic>[],
            user: user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: updateUserProfileEvent);
}

class LoggedInWithPhoneNumberUserState<TUserProfile>
    extends LoggedInUserState<TUserProfile> {
  final bool justLinked;
  LoggedInWithPhoneNumberUserState(
      {this.justLinked,
      User<TUserProfile> user,
      bool justLoggedIn = false,
      UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent})
      : super(<dynamic>[],
            user: user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: updateUserProfileEvent);
}

class VaitingForVerificationState extends GuestUserState {
  final UserBlocState previousState;
  final String verificationId;
  VaitingForVerificationState({this.verificationId, this.previousState});
}

class LoginConflictState extends LoginErrorState { 
  LoginConflictState({this.conflicts});
  final List<String> conflicts;
}

class VerificationCompletedState extends GuestUserState {
  final AuthCredential auth;
  VerificationCompletedState({this.auth});
}

class PhoneNumberManualVerificationNecessaryState extends GuestUserState {
  final String verificationId;
  PhoneNumberManualVerificationNecessaryState({this.verificationId});
}


class LoginWithCredentialState extends GuestUserState {
  final AuthCredential credential;
  LoginWithCredentialState({this.credential});
}

class LoggedInWithFacebookUserState<TUserProfile>
    extends LoggedInUserState<TUserProfile> {
  final String accessToken;

  LoggedInWithFacebookUserState(
      {this.accessToken,
      User<TUserProfile> user,
      bool justLoggedIn = false,
      UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent})
      : super(<dynamic>[accessToken],
            user: user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: updateUserProfileEvent);

  @override
  String toString() =>
      "${super.toString()} { accessToken: ${accessToken == null ? "<null>" : "<not null>"} }";
}

class LoggedInWithGoogleUserState<TUserProfile>
    extends LoggedInUserState<TUserProfile> {
  final String idToken;
  final String accessToken;

  LoggedInWithGoogleUserState(
      {this.idToken,
      this.accessToken,
      User<TUserProfile> user,
      bool justLoggedIn = false,
      UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent})
      : super(<dynamic>[idToken, accessToken],
            user: user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: updateUserProfileEvent);

  @override
  String toString() =>
      "${super.toString()} { idToken: <${idToken == null ? "" : "not "}null>, accessToken: <${accessToken == null ? "" : "not "}null> }";
}

class LoggedInWithEmailUserState<TUserProfile>
    extends LoggedInUserState<TUserProfile> {
  final String password;

  LoggedInWithEmailUserState(
      {User<TUserProfile> user,
      this.password,
      bool justLoggedIn = false,
      UpdateUserProfileEvent<TUserProfile> updateUserProfileEvent})
      : super(<dynamic>[password],
            user: user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: updateUserProfileEvent);
}

// in progress states

class InProgressState extends UserBlocState {
  InProgressState([List props = const <dynamic>[]]) : super(props);
}

class UserLoggingInState extends InProgressState {
  final LoginEvent loginEvent;

  UserLoggingInState({this.loginEvent}) : super(<dynamic>[loginEvent]);

  @override
  String toString() => "${super.toString()} { loginEvent: $loginEvent }";
}
