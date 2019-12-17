import 'dart:convert';
import 'package:bs_firebase_auth/blocs/UserBloc/events.dart';
import 'package:bs_firebase_auth/blocs/UserBloc/states.dart';
import 'package:bs_firebase_auth/blocs/UserBloc/models.dart';
import 'package:bloc/bloc.dart';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

class _OnFirebaseAuthChangedEvent extends UserBlocEvent {
  final FirebaseUser firebaseUser;

  _OnFirebaseAuthChangedEvent({this.firebaseUser});
}

class UserBloc<TUserProfile> extends Bloc<UserBlocEvent, UserBlocState> {
  ///////// Construct, singleton, initialize /////////
  bool _initializing = false;
  UserBlocEvent get initializeEvent => InitializeEvent();
  bool get isInitialized => currentState is! UninitializedState;

  Future<void> initialize() async {
    if (isInitialized) return Future.value();

    if (!_initializing) {
      _initializing = true;
      dispatch(initializeEvent);
    }
    return waitForInitialize();
  }

  Future<void> waitForInitialize() async {
    await for (UserBlocState _ in state) {
      if (isInitialized) return;
    }
  }

  factory UserBloc(UserProfileManagerModel<TUserProfile> manager) {
    return _instance[_typeOf<TUserProfile>()] as UserBloc<TUserProfile> ??
        (_instance[_typeOf<TUserProfile>()] =
            UserBloc<TUserProfile>._(manager: manager));
  }

  static Type _typeOf<T>() => T;

  static Map<Type, Bloc<UserBlocEvent, UserBlocState>> _instance = {};

  UserBloc._({@required this.manager}) {
    toJsonProfile = manager?.toJson;
    fromJsonProfile = manager?.fromJson;

    initialize();
  }

  CreateCallback<TUserProfile> createCallback;
  UserProfileManagerModel<TUserProfile> manager;

  ///////// Logging /////////
  Logger logger = Logger(
      "bs_firebase_auth.blocs.UserBloc.UserBloc.${_typeOf<TUserProfile>()}");

  ///////// Data & persistence /////////
  String _blocDataSharedPreferencesKey =
      "_UserBlocData<${_typeOf<TUserProfile>()}>";
  BlocData<TUserProfile> _blocData; // Peristed
  FirebaseUser _firebaseUser;

  void _copyFirebaseUserProperties(FirebaseUser firebaseUser) {
    _blocData.user.uid = firebaseUser.uid;
    _blocData.user.email = firebaseUser.email;
    _blocData.user.displayName = firebaseUser.displayName;
    _blocData.user.profilePictureUrl = firebaseUser.photoUrl;
  }

  Future<void> _saveBlocData() =>
      _blocData?.persist(_blocDataSharedPreferencesKey);

  ///////// Firebase token /////////
  static const String authorizationHeader = 'Authorization';
  Future<String> get authToken async => isLoggedIn ? _authToken : null;
  Future<String> get _authToken async {
    if (_firebaseUser != null) {
      String token = (await _firebaseUser.getIdToken())?.token;
      if (token != null)
        return token;
      else {
        logger.finest("_authToken: FirebaseUser token is null");
        dispatch(FirebaseDisconnectedLogoutEvent());
        return null;
      }
    } else {
      logger.finest("_authToken: missing _firebaseUser");
      return null;
    }
  }

  Future<Map<String, String>> get authHeader async =>
      isLoggedIn ? _authHeader : null;
  Future<Map<String, String>> get _authHeader async {
    String token = await authToken;
    return token == null ? null : {authorizationHeader: "Bearer $token"};
  }

  ///////// Convenient shortcuts /////////
  bool get isLoggedIn => currentState is LoggedInUserState<TUserProfile>;
  LoggedInUserState<TUserProfile> get loggedInUserState =>
      currentState is LoggedInUserState<TUserProfile>
          ? currentState as LoggedInUserState<TUserProfile>
          : null;

  void logout() => dispatch(LogoutEvent());
  void deleteUser() => dispatch(DeleteUserEvent());

  ///////// BLoC /////////
  @override
  UserBlocState get initialState => UninitializedState();

  @override
  Stream<UserBlocState> mapEventToState(UserBlocEvent event) async* {
    // Split again after https://github.com/dart-lang/language/issues/121

    try {
      if (event is InitializeEvent) {
        //////////////////////////////////////////  InitializeEvent //////////////////////////////////////////

        /*Stream<State> _mapInitializeToState(InitializeEvent event) async* */ {
          if (currentState is UninitializedState) {
            _blocData =
                await BlocData.getOrCreate(_blocDataSharedPreferencesKey);

            _firebaseUser = await FirebaseAuth.instance.currentUser();
            FirebaseAuth.instance.onAuthStateChanged.listen((fbUser) =>
                dispatch(_OnFirebaseAuthChangedEvent(
                    firebaseUser:
                        fbUser?.isAnonymous == false ? fbUser : null)));

            if (_firebaseUser != null && _blocData.tryLoginAtLoad) {
              String token = (await _firebaseUser.getIdToken())?.token;

              if (token != null)
                _blocData.user.userProfile =
                    await manager?.create(token, _blocData.user.userProfile);
              yield _recreateLoggedInState(justLoggedIn: true);
            }

            if (currentState is UninitializedState) yield GuestUserState();
          }
        }
      }

      if (isInitialized) {
        if (event is LoginWithFacebookEvent) {
          //////////////////////////////////////////  LoginWithFacebookEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithFacebookToState(LoginWithFacebookEvent event) async* */
          {
            if (currentState is GuestUserState || event is LinkFacebookEvent) {
              try {
                String currentEmail = loggedInUserState?.user?.email;
                UserBlocState previousState = currentState;

                yield UserLoggingInState(loginEvent: event);

                FacebookLogin facebookLogin = FacebookLogin()
                  ..loginBehavior = FacebookLoginBehavior.webViewOnly;

                FacebookLoginResult loginResult =
                    await facebookLogin.logIn(event.readOnlyScopes);

                switch (loginResult.status) {
                  case FacebookLoginStatus.loggedIn:
                    AuthCredential credential =
                        FacebookAuthProvider.getCredential(
                            accessToken: loginResult.accessToken.token);

                    FirebaseAuth firebaseAuth = FirebaseAuth.instance;
                    FirebaseUser firebaseUser;
                    try {
                      if (event is LinkFacebookEvent) {
                        List<String> platforms = await firebaseAuth
                            .fetchSignInMethodsForEmail(email: currentEmail);

                        if (platforms != null &&
                            !platforms.contains("facebook.com")) {
                          firebaseUser = await firebaseAuth.currentUser();
                          firebaseUser = (await firebaseUser
                                  .linkWithCredential(credential))
                              ?.user;
                        }
                      }

                      firebaseUser =
                          (await firebaseAuth.signInWithCredential(credential))
                              ?.user;

                      if (event is LoginWithFacebookAndLinkAccountEvent) {
                        firebaseUser = await firebaseAuth.currentUser();
                        firebaseUser = (await firebaseUser.linkWithCredential(
                                event.accountLinkingData.credential))
                            ?.user;
                      }
                    } on PlatformException catch (e) {
                      if (e.code ==
                          'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL') {
                        http.Response result = await http.get(
                            'https://graph.facebook.com/v2.12/me?fields=email&access_token=${loginResult.accessToken.token}');

                        Map<String, dynamic> resultJson =
                            json.decode(result.body) as Map<String, dynamic>;

                        List<String> platforms =
                            await firebaseAuth.fetchSignInMethodsForEmail(
                                email: resultJson["email"] as String);

                        if (platforms.contains("google.com"))
                          yield LinkingNecessaryState(
                              accountLinkingData: AccountLinkingData(
                                  credential: credential,
                                  email: resultJson["email"] as String,
                                  provider: Provider.google));
                        else
                          yield LinkingNecessaryState(
                              accountLinkingData: AccountLinkingData(
                                  credential: credential,
                                  email: resultJson["email"] as String,
                                  provider: Provider.email));
                        return;
                      } else
                        rethrow;
                    }

                    if (!firebaseUser.isEmailVerified)
                      await firebaseUser.sendEmailVerification();

                    logger.finer("FirebaseUser: { $firebaseUser }");
                    _firebaseUser = firebaseUser;
                    _blocData.user ??= User<TUserProfile>();
                    _blocData.user.userProfile = await manager?.create(
                        await _authToken, _blocData.user.userProfile);
                    _blocData.provider = Provider.facebook;
                    _blocData.facebookAccessToken =
                        loginResult.accessToken.token;
                    _copyFirebaseUserProperties(firebaseUser);

                    yield LoggedInWithFacebookUserState<TUserProfile>(
                        user: _blocData.user,
                        accessToken: _blocData.facebookAccessToken,
                        justLoggedIn: true);
                    break;
                  case FacebookLoginStatus.cancelledByUser:
                    yield LoginCanceledState(loginEvent: event);
                    yield previousState;
                    break;
                  case FacebookLoginStatus.error:
                    yield LoginErrorState(
                        error: loginResult.errorMessage, loginEvent: event);
                    yield GuestUserState();
                    break;
                }
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield GuestUserState();
              }
            }
          }
        } else if (event is LoginWithEmailEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (currentState is GuestUserState) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                AuthCredential credential = EmailAuthProvider.getCredential(
                    email: event.email, password: event.password);

                FirebaseUser firebaseUser =
                    (await firebaseAuth.signInWithCredential(credential))?.user;

                if (event is LoginWithEmailAndLinkAccountEvent) {
                  firebaseUser = await firebaseAuth.currentUser();
                  firebaseUser =
                      (await firebaseUser.linkWithCredential(credential))?.user;
                }
                if (!firebaseUser.isEmailVerified) {
                  await firebaseAuth.signOut();
                  throw PlatformException(code: 'EMAIL_IS_NOT_VERIFIED');
                }

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _blocData.user.userProfile = await manager?.create(
                    await _authToken, _blocData.user.userProfile);
                _blocData
                  ..password = event.password
                  ..provider = Provider.email;
                _copyFirebaseUserProperties(firebaseUser);

                yield LoggedInWithEmailUserState<TUserProfile>(
                    user: _blocData.user,
                    password: event.password,
                    justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield GuestUserState();
              }
            }
          }
        } else if (event is LoginWithAnonymousEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (currentState is GuestUserState) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                FirebaseUser firebaseUser =
                    (await firebaseAuth.signInAnonymously())?.user;

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _blocData.user.userProfile = await manager?.create(
                    await _authToken, _blocData.user.userProfile);
                _blocData.provider = Provider.anonymous;
                _copyFirebaseUserProperties(firebaseUser);

                yield LoggedInWithAnonymousUserState<TUserProfile>(
                    user: _blocData.user, justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield GuestUserState();
              }
            }
          }
        } else if (event is LoginWithGoogleEvent) {
          //////////////////////////////////////////  LoginWithGoogleEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithGoogleToState(LoginWithGoogleEvent event) async* */
          {
            if (currentState is GuestUserState) {
              yield UserLoggingInState(loginEvent: event);

              try {
                bool canceled = false;
                GoogleSignIn googleSignIn = GoogleSignIn(scopes: event.scopes);
                GoogleSignInAccount googleAccount =
                    googleSignIn.currentUser != null
                        ? await googleSignIn.signInSilently()
                        : null;

                if (googleAccount == null) {
                  googleAccount = await googleSignIn.signIn();
                  if (googleAccount == null) {
                    yield LoginCanceledState(loginEvent: event);
                    canceled = true; //return;
                  }
                }

                if (!canceled) {
                  GoogleSignInAuthentication googleAuth =
                      await googleSignIn.currentUser.authentication;
                  AuthCredential credential = GoogleAuthProvider.getCredential(
                    idToken: googleAuth.idToken,
                    accessToken: googleAuth.accessToken,
                  );

                  FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                  FirebaseUser firebaseUser =
                      (await firebaseAuth.signInWithCredential(credential))
                          ?.user;

                  if (event is LoginWithGoogleAndLinkAccountEvent) {
                    firebaseUser = await firebaseAuth.currentUser();
                    firebaseUser = (await firebaseUser.linkWithCredential(
                            event.accountLinkingData.credential))
                        ?.user;
                  }

                  logger.finer("FirebaseUser: { $firebaseUser }");
                  _firebaseUser = firebaseUser;
                  _blocData.user ??= User<TUserProfile>();
                  _blocData.user.userProfile = await manager?.create(
                      await _authToken, _blocData.user.userProfile);
                  _blocData
                    ..provider = Provider.google
                    ..googleIdToken = googleAuth.idToken
                    ..googleAccessToken = googleAuth.accessToken;
                  _copyFirebaseUserProperties(firebaseUser);

                  yield LoggedInWithGoogleUserState<TUserProfile>(
                      user: _blocData.user,
                      idToken: _blocData.googleIdToken,
                      accessToken: _blocData.googleAccessToken,
                      justLoggedIn: true);
                }
              } on PlatformException catch (e) {
                switch (e.code) {
                  case GoogleSignIn.kSignInCanceledError:
                    yield LoginCanceledState(loginEvent: event);
                    break;
                  default:
                    yield LoginErrorState(error: e, loginEvent: event);
                    yield GuestUserState();
                }
              }
            }
          }
        } else if (event is _OnFirebaseAuthChangedEvent) {
          //////////////////////////////////////////  _OnFirebaseAuthChangedEvent //////////////////////////////////////////

          /* Stream<State> _mapOnFirebaseAuthChangedToState(_OnFirebaseAuthChangedEvent event) async* */
          {
            if (isLoggedIn) {
              _firebaseUser = event.firebaseUser;
              logger.info("OnFirebaseAuthChanged: ${event.firebaseUser}");
            }
          }
        } else if (event is LogoutEvent) {
          //////////////////////////////////////////  LogoutEvent //////////////////////////////////////////
          ///
          /* Stream<State> _mapLogoutEventToState(LogoutEvent event) async* */ {
            if (currentState is LoggedInUserState<TUserProfile>) {
              await _logoutUser();
              yield JustLoggedOutGuestUserState(
                  loggedInState:
                      currentState as LoggedInUserState<TUserProfile>);
            } else
              yield GuestUserState();
          }
        } else if (event is UpdateUserProfileEvent<TUserProfile>) {
          //////////////////////////////////////////  UpdateUserProfileEvent //////////////////////////////////////////

          /* Stream<State> _mapUpdateUserProfileEventToState(UpdateUserProfileEvent event) async* */
          {
            if (currentState is LoggedInUserState<TUserProfile>) {
              _blocData = _blocData.clone();

              UserUpdateInfo fbUpdate = UserUpdateInfo();

              if (event.profilePicture != null) {
                fbUpdate.photoUrl = _blocData.user.profilePictureUrl;
              }

              fbUpdate.displayName = _blocData.user.displayName;
              await _firebaseUser.updateProfile(fbUpdate);

              _blocData.user.userProfile =
                  await manager?.merge(event.input, _blocData.user.userProfile);
              yield _recreateLoggedInState(justLoggedIn: false, event: event);
            }
          }
        } else if (event is DeleteUserEvent) {
          //////////////////////////////////////////  DeleteUserEvent //////////////////////////////////////////

          /* Stream<State> _mapDeleteUserEventToState(DeleteUserEvent event) async* */
          {
            UserBlocState state = currentState;
            if (state is LoggedInUserState<TUserProfile>) {
              yield InProgressState();

              await _logoutUser(delete: true);

              yield JustLoggedOutGuestUserState(loggedInState: state);
            }
          }
        } else if (event is CreateUserEvent) {
          try {
            yield InProgressState();
            FirebaseUser user;
            FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

            List<String> platforms = await _firebaseAuth
                .fetchSignInMethodsForEmail(email: event.email);

            if (platforms != null && platforms.contains("password")) {
              throw PlatformException(code: "ERROR_EMAIL_ALREADY_IN_USE");
            } else if (platforms != null && platforms.contains("google.com")) {
              yield LinkingNecessaryState(
                  accountLinkingData: AccountLinkingData(
                      email: event.email,
                      credential: EmailAuthProvider.getCredential(
                          email: event.email, password: event.password),
                      provider: Provider.google));
              return;
            } else if (platforms != null &&
                platforms.contains("facebook.com")) {
              yield LinkingNecessaryState(
                  accountLinkingData: AccountLinkingData(
                      email: event.email,
                      credential: EmailAuthProvider.getCredential(
                          email: event.email, password: event.password),
                      provider: Provider.facebook));
              return;
            } else
              user = (await _firebaseAuth.createUserWithEmailAndPassword(
                      email: event.email, password: event.password))
                  ?.user;

            if (!user.isEmailVerified) await user.sendEmailVerification();

            yield JustRegisteredGuestUserState();
          } on PlatformException catch (exception) {
            yield CreateErrorState(error: exception, createEvent: event);
            yield GuestUserState();
          }
        } else if (event is PasswordResetEvent) {
          try {
            FirebaseAuth firebaseAuth = FirebaseAuth.instance;
            await firebaseAuth.sendPasswordResetEmail(email: event.email);

            yield JustResetEmailSentGuestUserState();
          } on PlatformException catch (exception) {
            yield ErrorState(error: exception);
            yield GuestUserState();
          }
        }
      }

      _blocData?.tryLoginAtLoad = isLoggedIn;
      await _saveBlocData();
    } on Exception catch (err) {
      yield ErrorState(error: err);
      yield GuestUserState();
      rethrow;
    }
  }

  LoggedInUserState<TUserProfile> _recreateLoggedInState(
      {@required bool justLoggedIn,
      UpdateUserProfileEvent<TUserProfile> event}) {
    switch (_blocData.provider) {
      case Provider.facebook:
        return LoggedInWithFacebookUserState<TUserProfile>(
            user: _blocData.user,
            accessToken: _blocData.facebookAccessToken,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);
      case Provider.google:
        return LoggedInWithGoogleUserState(
            user: _blocData.user,
            idToken: _blocData.googleIdToken,
            accessToken: _blocData.googleAccessToken,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);
      case Provider.email:
        return LoggedInWithEmailUserState(
            user: _blocData.user,
            password: _blocData.password,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);
      case Provider.anonymous:
        return LoggedInWithAnonymousUserState(
            user: _blocData.user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);

      // Don't write default, let analyzer warn about unhandled values
    }

    throw RangeError(
        "Not all provider handled in _recreateLoggedInState"); // never hits if all switch cases are handled
  }

  Future<void> _logoutUser({bool delete = false}) async {
    switch (_blocData.provider) {
      // use switch to ensure all providers are handled
      case Provider.facebook:
        await FacebookLogin().logOut();
        break;
      case Provider.google:
        await GoogleSignIn().signOut();
        break;
      case Provider.email:
      case Provider.anonymous:
        break;
    }

    if (delete)
      await _firebaseUser.delete();
    else
      await FirebaseAuth.instance.signOut();

    _firebaseUser = null;
    _blocData = BlocData();
  }
}
