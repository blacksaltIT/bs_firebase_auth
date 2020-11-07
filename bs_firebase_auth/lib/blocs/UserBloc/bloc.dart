import 'dart:async';
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
import 'package:flutter/foundation.dart';

class _OnFirebaseAuthChangedEvent extends UserBlocEvent {
  final FirebaseUser firebaseUser;

  _OnFirebaseAuthChangedEvent({this.firebaseUser});
}

class UserBloc<TUserProfile> extends Bloc<UserBlocEvent, UserBlocState> {
  ///////// Construct, singleton, initialize /////////
  bool _initializing = false;
  UserBlocEvent get initializeEvent => InitializeEvent();
  bool get isInitialized => state is! UninitializedState;
  final Completer<void> initCompleter = Completer<void>();

  Future<void> initialize() async {
    if (isInitialized) return Future.value();

    if (!_initializing) {
      _initializing = true;
      add(initializeEvent);
    }
    return waitForInitialize();
  }

  StreamSubscription _sub;
  Future<void> waitForInitialize() async {
    if (isInitialized || initCompleter.isCompleted) return Future.value();

    _sub = listen((state) {
      if (isInitialized) {
        if (!initCompleter.isCompleted) {
          initCompleter.complete();
        }
        _sub.cancel();
      }
    });
    return initCompleter.future;
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
    _blocData.user.email = firebaseUser.email ??
        firebaseUser.providerData
            .firstWhere(
                (pd) =>
                    pd.providerId == "facebook.com" ||
                    pd.providerId == "google.com",
                orElse: () => null)
            ?.email;
    _blocData.user.displayName = firebaseUser.displayName ??
        firebaseUser.providerData
            .firstWhere(
                (pd) =>
                    pd.providerId == "facebook.com" ||
                    pd.providerId == "google.com",
                orElse: () => null)
            ?.displayName;
    _blocData.user.profilePictureUrl = firebaseUser.photoUrl ??
        firebaseUser.providerData
            .firstWhere(
                (pd) =>
                    pd.providerId == "facebook.com" ||
                    pd.providerId == "google.com",
                orElse: () => null)
            ?.photoUrl;
    _blocData.user.phoneNumber = firebaseUser.phoneNumber;
    _blocData.user.providers =
        firebaseUser.providerData.map((pd) => pd.providerId).toList();
  }

  Future<void> _saveBlocData() =>
      _blocData?.persist(_blocDataSharedPreferencesKey);

  ///////// Firebase token /////////
  static const String authorizationHeader = 'Authorization';
  Future<String> get authToken async => isLoggedIn ? _authToken : null;
  Future<String> get _authToken async {
    if (_firebaseUser != null) {
      IdTokenResult idToken = await _firebaseUser.getIdToken();
      String token = idToken?.token;
      if (token != null)
        return token;
      else {
        logger.finest("_authToken: FirebaseUser token is null");
        add(FirebaseDisconnectedLogoutEvent());
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
  bool get isLoggedIn => state is LoggedInUserState<TUserProfile>;
  LoggedInUserState<TUserProfile> get loggedInUserState =>
      state is LoggedInUserState<TUserProfile>
          ? state as LoggedInUserState<TUserProfile>
          : null;

  void logout() => add(LogoutEvent());
  void deleteUser() => add(DeleteUserEvent());

  ///////// BLoC /////////
  @override
  UserBlocState get initialState => UninitializedState();

  @override
  Stream<UserBlocState> mapEventToState(UserBlocEvent event) async* {
    // Split again after https://github.com/dart-lang/language/issues/121
    UserBlocState previousState = state;
    previousState.recreated = true;
    try {
      if (event is InitializeEvent) {
        //////////////////////////////////////////  InitializeEvent //////////////////////////////////////////

        /*Stream<State> _mapInitializeToState(InitializeEvent event) async* */
        {
          if (state is UninitializedState) {
            try {
              _blocData =
                  await BlocData.getOrCreate(_blocDataSharedPreferencesKey);
            } catch (e) {
              print(e);
            }
            _firebaseUser = await FirebaseAuth.instance.currentUser();
            FirebaseAuth.instance.onAuthStateChanged.listen((fbUser) =>
                add(_OnFirebaseAuthChangedEvent(firebaseUser: fbUser)));

            if (_firebaseUser != null && _blocData.tryLoginAtLoad) {
              String token = (await _firebaseUser.getIdToken())?.token;

              if (token != null)
                _blocData.user.userProfile =
                    await manager?.create(token, _blocData.user);
              yield _recreateLoggedInState(justLoggedIn: true);
            }

            if (state is UninitializedState) yield GuestUserState();
          }
        }
      }

      if (isInitialized) {
        if (event is LoginWithFacebookEvent) {
          //////////////////////////////////////////  LoginWithFacebookEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithFacebookToState(LoginWithFacebookEvent event) async* */
          {
            if (state is GuestUserState ||
                event is LinkFacebookEvent ||
                event is LoginWithFacebookAndLinkAccountEvent) {
              try {
                String currentEmail = loggedInUserState?.user?.email;

                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;
                FacebookLogin facebookLogin = FacebookLogin()
                  ..loginBehavior = FacebookLoginBehavior.webViewOnly;

                FacebookLoginResult loginResult =
                    await facebookLogin.logIn(event.readOnlyScopes);

                switch (loginResult.status) {
                  case FacebookLoginStatus.loggedIn:
                    AuthCredential credential =
                        FacebookAuthProvider.getCredential(
                            accessToken: loginResult.accessToken.token);

                    FirebaseUser firebaseUser;
                    try {
                      if (event is LinkFacebookEvent ||
                          event is LoginWithFacebookAndLinkAccountEvent) {
                        firebaseUser = await firebaseAuth.currentUser();

                        if (firebaseUser != null &&
                            firebaseUser.providerData.firstWhere(
                                    (pd) => pd.providerId == "facebook.com",
                                    orElse: () => null) ==
                                null) {
                          firebaseUser = (await firebaseUser
                                  .linkWithCredential(credential))
                              ?.user;
                        }
                      } else {
                        firebaseUser = (await firebaseAuth
                                .signInWithCredential(credential))
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

                    logger.finer("FirebaseUser: { $firebaseUser }");
                    _firebaseUser = firebaseUser;
                    _blocData.user ??= User<TUserProfile>();
                    _copyFirebaseUserProperties(firebaseUser);
                    _blocData.user.userProfile =
                        await manager?.create(await _authToken, _blocData.user);
                    _blocData.provider = Provider.facebook;
                    _blocData.facebookAccessToken =
                        loginResult.accessToken.token;

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
                    yield previousState;
                    break;
                }
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield previousState;
              }
            }
          }
        } else if (event is LoginWithEmailEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (state is GuestUserState ||
                state is LoggedInWithAnonymousUserState ||
                state is LoggedInWithPhoneNumberUserState) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                AuthCredential credential = EmailAuthProvider.getCredential(
                    email: event.email, password: event.password);

                FirebaseUser firebaseUser;
                if (event is LoginWithEmailAndLinkAccountEvent) {
                  firebaseUser = await firebaseAuth.currentUser();

                  if (firebaseUser != null &&
                      firebaseUser.providerData.firstWhere(
                              (pd) => pd.providerId == "password",
                              orElse: () => null) ==
                          null) {
                    firebaseUser =
                        (await firebaseUser.linkWithCredential(credential))
                            ?.user;
                  }
                } else {
                  try {
                    firebaseUser =
                        (await firebaseAuth.signInWithCredential(credential))
                            ?.user;
                  } catch (e) {
                    // if user doesn't exist create it

                    if (event.forceCreate && e.code == "ERROR_USER_NOT_FOUND") {
                      firebaseUser =
                          (await firebaseAuth.createUserWithEmailAndPassword(
                                  email: event.email, password: event.password))
                              ?.user;
                    } else
                      throw e;
                  }
                }

                // if state was anonymous let's delete previous user as it would be lost
                /*if (previousState is LoggedInWithAnonymousUserState) {
                  await _firebaseUser.delete();
                }*/

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _copyFirebaseUserProperties(firebaseUser);
                _blocData.user.userProfile =
                    await manager?.create(await _authToken, _blocData.user);
                _blocData
                  ..password = event.password
                  ..link = null
                  ..provider = Provider.email;

                yield LoggedInWithEmailUserState<TUserProfile>(
                    user: _blocData.user,
                    password: event.password,
                    justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield previousState;
              }
            }
          }
        } else if (event is LoginWithEmailLinkEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (state is GuestUserState ||
                state is LoggedInWithAnonymousUserState ||
                state is LoggedInWithPhoneNumberUserState) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                AuthCredential credential =
                    EmailAuthProvider.getCredentialWithLink(
                        email: event.email, link: event.link);

                FirebaseUser firebaseUser;
                if (event is LoginWithEmailLinkAndLinkAccountEvent) {
                  firebaseUser = await firebaseAuth.currentUser();

                  if (firebaseUser != null &&
                      firebaseUser.providerData.firstWhere(
                              (pd) => pd.providerId == "password",
                              orElse: () => null) ==
                          null) {
                    firebaseUser =
                        (await firebaseUser.linkWithCredential(credential))
                            ?.user;
                  }
                } else {
                  firebaseUser =
                      (await firebaseAuth.signInWithCredential(credential))
                          ?.user;

                  if (!firebaseUser.isEmailVerified) {
                    await firebaseAuth.signOut();
                    throw PlatformException(code: 'EMAIL_IS_NOT_VERIFIED');
                  }
                }

                // if state was anonymous let's delete previous user as it would be lost
                if (state is LoggedInWithAnonymousUserState) {
                  await _firebaseUser.delete();
                }

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _copyFirebaseUserProperties(firebaseUser);
                _blocData.user.userProfile =
                    await manager?.create(await _authToken, _blocData.user);
                _blocData
                  ..link = event.link
                  ..password = null
                  ..provider = Provider.email;

                yield LoggedInWithEmailUserState<TUserProfile>(
                    user: _blocData.user, link: event.link, justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield previousState;
              }
            }
          }
        } else if (event is LoginWithAnonymousEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (state is GuestUserState) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                FirebaseUser firebaseUser =
                    (await firebaseAuth.signInAnonymously())?.user;

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _copyFirebaseUserProperties(firebaseUser);
                _blocData.user.userProfile =
                    await manager?.create(await _authToken, _blocData.user);
                _blocData.provider = Provider.anonymous;

                yield LoggedInWithAnonymousUserState<TUserProfile>(
                    user: _blocData.user, justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield GuestUserState();
              }
            }
          }
        } else if (event is DelegateStateEvent) {
          yield event.state;
        } else if (event is VerifyPhoneNumberEvent) {
          FirebaseAuth firebaseAuth = FirebaseAuth.instance;
          try {
            await firebaseAuth.verifyPhoneNumber(
                phoneNumber: event.phoneNumber,
                timeout: Duration(seconds: 60),
                verificationFailed: (e) {
                  add(DelegateStateEvent(
                      state: LoginErrorState(error: e, loginEvent: event)));
                  add(DelegateStateEvent(state: previousState));
                },
                codeSent: (verificationId, [forceResendingToken]) async {
                  add(DelegateStateEvent(
                      state: VaitingForVerificationState(
                          previousState: previousState,
                          verificationId: verificationId)));
                },
                codeAutoRetrievalTimeout: (verificationId) {
                  Map error = {"code": "ERROR_PHONE_VERIFICATION_TIMEOUT"};
                  add(DelegateStateEvent(
                      state: LoginErrorState(error: error, loginEvent: event)));
                  //previousState.recreated = false;
                  add(DelegateStateEvent(state: previousState));
                },
                verificationCompleted: (auth) {
                  add(previousState is LoggedInUserState
                      ? LinkWithPhoneNumberEvent(
                          credential: auth,
                          alreadyRegistered: event.alreadyRegistered)
                      : LoginWithPhoneNumberEvent(credential: auth));
                });
          } on Exception catch (e) {
            yield LoginErrorState(error: e, loginEvent: event);
            yield previousState;
          }
        } else if (event is LoginWithPhoneNumberEvent) {
          //////////////////////////////////////////  LoginWithEmailEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithEmailToState(LoginWithEmailEvent event) async* */
          {
            if (state is GuestUserState || event is LinkWithPhoneNumberEvent) {
              try {
                yield UserLoggingInState(loginEvent: event);

                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                AuthCredential credential = event.credential ??
                    PhoneAuthProvider.getCredential(
                        verificationId: event.verificationId,
                        smsCode: event.smsCode);

                FirebaseUser currentUser = await firebaseAuth.currentUser();
                FirebaseUser firebaseUser;

                Provider savedProvider = _blocData.provider;
                Provider rewriteProvider;

                if (event is LinkWithPhoneNumberEvent) {
                  try {
                    // first login with phone number
                    if (event.alreadyRegistered) {
                      firebaseUser =
                          (await firebaseAuth.signInWithCredential(credential))
                              ?.user;
                      yield LoginErrorState(error: {
                        "code": "ERROR_CREDENTIAL_ALREADY_IN_USE",
                      }, loginEvent: event, obj: "${firebaseUser.email ?? firebaseUser.providerData.firstWhere((pd) =>pd.providerId != 'firebase' || pd.providerId != 'phone', orElse: () => null)?.email} (${firebaseUser.providerData.map((pd) => pd.providerId).toList().firstWhere((pd) => pd != "firebase" && pd != "phone")})");
                    } else {
                      firebaseUser =
                          (await currentUser.linkWithCredential(credential))
                              ?.user;
                    }

                    rewriteProvider = savedProvider;
                  } catch (e) {
                    if (e.code == "ERROR_INVALID_VERIFICATION_CODE") {
                      // TODO: handle invalid verification codeú
                      firebaseUser = (await firebaseUser.linkWithCredential(
                              EmailAuthProvider.getCredential(
                                  email: _blocData.user.email,
                                  password: _blocData.password)))
                          ?.user;

                      yield LoginErrorState(error: {
                        "code": "ERROR_INVALID_VERIFICATION_CODE",
                        "providerData": firebaseUser.providerData
                      }, loginEvent: event);
                      return;
                    }
                  }
                } else
                  firebaseUser =
                      (await firebaseAuth.signInWithCredential(credential))
                          ?.user;

                logger.finer("FirebaseUser: { $firebaseUser }");
                _firebaseUser = firebaseUser;
                _blocData.user ??= User<TUserProfile>();
                _copyFirebaseUserProperties(firebaseUser);
                _blocData.user.userProfile =
                    await manager?.create(await _authToken, _blocData.user);

                _blocData.provider = rewriteProvider ?? Provider.phone;

                yield LoggedInWithPhoneNumberUserState<TUserProfile>(
                    user: _blocData.user, justLoggedIn: true);
              } on PlatformException catch (e) {
                yield LoginErrorState(error: e, loginEvent: event);
                yield previousState;
              }
            }
          }
        } else if (event is LoginWithGoogleEvent) {
          //////////////////////////////////////////  LoginWithGoogleEvent //////////////////////////////////////////

          /* Stream<State> _mapLoginWithGoogleToState(LoginWithGoogleEvent event) async* */
          {
            if (state is GuestUserState ||
                event is LoginWithGoogleAndLinkAccountEvent) {
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
                FirebaseAuth firebaseAuth = FirebaseAuth.instance;

                if (!canceled) {
                  GoogleSignInAuthentication googleAuth =
                      await googleSignIn.currentUser.authentication;
                  AuthCredential credential = GoogleAuthProvider.getCredential(
                    idToken: googleAuth.idToken,
                    accessToken: googleAuth.accessToken,
                  );

                  FirebaseUser firebaseUser;
                  if (event is LoginWithGoogleAndLinkAccountEvent) {
                    firebaseUser = await firebaseAuth.currentUser();

                    if (firebaseUser != null &&
                        firebaseUser.providerData.firstWhere(
                                (pd) => pd.providerId == "google.com",
                                orElse: () => null) ==
                            null) {
                      firebaseUser =
                          (await firebaseUser.linkWithCredential(credential))
                              ?.user;
                    }
                  } else {
                    firebaseUser =
                        (await firebaseAuth.signInWithCredential(credential))
                            ?.user;
                  }

                  logger.finer("FirebaseUser: { $firebaseUser }");
                  _firebaseUser = firebaseUser;
                  _blocData.user ??= User<TUserProfile>();
                  _copyFirebaseUserProperties(firebaseUser);
                  _blocData.user.userProfile =
                      await manager?.create(await _authToken, _blocData.user);
                  _blocData
                    ..provider = Provider.google
                    ..googleIdToken = googleAuth.idToken
                    ..googleAccessToken = googleAuth.accessToken;

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
                    yield previousState;
                    break;
                  default:
                    yield LoginErrorState(error: e, loginEvent: event);
                    yield previousState;
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
            } else if (event.firebaseUser != null) {
              _firebaseUser = event.firebaseUser;
              String token = (await _firebaseUser.getIdToken())?.token;

              if (token != null) {
                _copyFirebaseUserProperties(_firebaseUser);
                _blocData.user.userProfile =
                    await manager?.create(token, _blocData.user);
              }
              yield _recreateLoggedInState(justLoggedIn: true);
            }
          }
        } else if (event is LogoutEvent) {
          //////////////////////////////////////////  LogoutEvent //////////////////////////////////////////
          ///
          /* Stream<State> _mapLogoutEventToState(LogoutEvent event) async* */ {
            if (state is LoggedInUserState<TUserProfile>) {
              await _logoutUser();
              yield JustLoggedOutGuestUserState(
                  loggedInState: state as LoggedInUserState<TUserProfile>);
            } else
              yield GuestUserState();
          }
        } else if (event is UpdateUserProfileEvent<TUserProfile>) {
          //////////////////////////////////////////  UpdateUserProfileEvent //////////////////////////////////////////

          /* Stream<State> _mapUpdateUserProfileEventToState(UpdateUserProfileEvent event) async* */
          {
            if (state is LoggedInUserState<TUserProfile>) {
              _blocData = _blocData.clone();

              UserUpdateInfo fbUpdate = UserUpdateInfo();

              if (event.profilePicture != null) {
                // TODO upload profile picture
                /*fbUpdate.photoUrl = event.profilePicture;
                _blocData.user.profilePictureUrl = event.profilePicture;*/
              }

              if (event.displayName != null) {
                fbUpdate.displayName = event.displayName;
              }

              await _firebaseUser.updateProfile(fbUpdate);
              _firebaseUser = await FirebaseAuth.instance.currentUser();
              _copyFirebaseUserProperties(_firebaseUser);

              _blocData.user.userProfile = await manager?.merge(
                  event.input, _blocData.user.userProfile, _blocData.user);
              yield _recreateLoggedInState(justLoggedIn: false, event: event);
            }
          }
        } else if (event is DeleteUserEvent) {
          //////////////////////////////////////////  DeleteUserEvent //////////////////////////////////////////

          /* Stream<State> _mapDeleteUserEventToState(DeleteUserEvent event) async* */
          {
            UserBlocState bstate = state;
            if (bstate is LoggedInUserState<TUserProfile>) {
              yield InProgressState();

              await _logoutUser(delete: true);

              yield JustLoggedOutGuestUserState(loggedInState: bstate);
            }
          }
        } else if (event is CreateUserEvent) {
          try {
            yield InProgressState();
            FirebaseUser user;
            FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

            // TODO: this feature is not implemented in web yet
            List<String> platforms = await _firebaseAuth
                .fetchSignInMethodsForEmail(email: event.email);

            if (platforms != null && platforms.contains("password")) {
              throw PlatformException(code: "ERROR_EMAIL_ALREADY_IN_USE");
            } else
              user = (await _firebaseAuth.createUserWithEmailAndPassword(
                      email: event.email, password: event.password))
                  ?.user;

            if (!user.isEmailVerified) await user.sendEmailVerification();

            yield JustRegisteredGuestUserState();
          } on PlatformException catch (exception) {
            yield CreateErrorState(error: exception, createEvent: event);
            yield previousState;
          }
        } else if (event is LinkWithEmailCredentialEvent) {
          if (state is LoggedInWithAnonymousUserState ||
              state is LoggedInWithPhoneNumberUserState) {
            //already logged in just have to link the user with the credential created here
            try {
              FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
              FirebaseUser firebaseUser = await _firebaseAuth.currentUser();

              AuthCredential credential = EmailAuthProvider.getCredential(
                  email: event.email, password: event.password);

              await firebaseUser.linkWithCredential(credential);
              await firebaseUser.sendEmailVerification();
              // logout as user has to use the new credentials
              await _logoutUser();
              yield JustRegisteredGuestUserState();
            } on PlatformException catch (exception) {
              // send error and restore the previous state
              yield ErrorState(error: exception);
              yield state;
            }
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
        } else if (event is ResendVerificationEmailEvent) {
          try {
            FirebaseAuth firebaseAuth = FirebaseAuth.instance;
            AuthCredential credential = EmailAuthProvider.getCredential(
                email: event.email, password: event.password);

            FirebaseUser firebaseUser =
                (await firebaseAuth.signInWithCredential(credential))?.user;
            if (firebaseUser != null) {
              await firebaseUser.sendEmailVerification();
              await _logoutUser();
            }

            yield JustResentVerificationEmailGuestUserState();
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
            link: _blocData.link,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);
      case Provider.anonymous:
        return LoggedInWithAnonymousUserState(
            user: _blocData.user,
            justLoggedIn: justLoggedIn,
            updateUserProfileEvent: event);
      case Provider.phone:
        return LoggedInWithPhoneNumberUserState(
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
      case Provider.phone:
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
