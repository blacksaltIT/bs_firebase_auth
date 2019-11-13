# bs_firebase_auth

Firebase authentication for Facebook, Google and Email accounts with persistent data between sessions and the option to store various data in the userbloc.

## Getting Started

Before you do anything, you will need a Firebase project linked to your app.
The following link will help you setting up the basics https://firebase.google.com/docs/flutter/setup.

This package depends heavily on the usage of the userBloc, you can authenticate and communicate with firebase through dispatching events.

```
dispatch(
    LoginWithEmailEvent(email: , password: );
    LoginWithEmailAndLinkAccountEvent(accountLinkingData: );

    LoginWithFacebookEvent(readOnlyScopes: );
    LinkFacebookEvent(readOnlyScopes: );
    LoginWithFacebookAndLinkAccountEvent(accountLinkingData: , readOnlyScopes: );

    LoginWithGoogleEvent(scopes: );
    LoginWithGoogleAndLinkAccountEvent(accountLinkingData: , scopes: );

    CreateUserEvent(email: , password: );
    
    UpdateUserProfileEvent<TUserProfile>(input: , displayName: , profilePicture: )

    LogoutEvent();
    PasswordReseTEvent(email: );
)
```


BlocData manages the authentication. Everything inside BlocData will be saved to persistency.
```
BlocData<TUserProfile> has the following properties:
  User<TUserProfile> user;
  bool tryLoginAtLoad = false;
  Provider provider;
  String facebookAccessToken;
  String googleIdToken;
  String googleAccessToken;
  String password;
```
To access BlocData instance in your application, it is advised to use a getter.
example;
```
 UserBloc<UserProfile> _userBloc;
 UserBloc<UserProfile> getInstance() {
  if (_userBloc == null) {
    _userBloc = UserBloc<UserProfile>(UserProfileManager());
    _userBloc.state.listen((state) async {
      if (state is LoggedInUserState<UserProfile>) {
        await _updateUserProfileOnServer(state: state);
      }
    });
  }
  return _userBloc;
}
```
In this example, we check if we have a userbloc already. If we have, we return that. If we don't, we create one and we subscribe to the state. We update our server on a state change.


Inside the BlocData, the User property holds information from that can be accessed in Firebase
User<TUserProfile> has the following properties:
```
  String email;
  String userName;
  String displayName;
  String profilePictureUrl;
  TUserProfile userProfile;
```
## TUserProfile

userProfile is the "joker" property, it's there so you can manage any kind of information you might want.
To access userProfile, you can override the following methods inside your application:
```
abstract class UserProfileManagerModel<TUserProfile> {
  Future<TUserProfile> create(String authToken, TUserProfile userProfile);
  TUserProfile fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(TUserProfile userP);
  Future<TUserProfile> merge(TUserProfile partial, TUserProfile full);
}
```
An example for overriding the "create" function:
```
    class UserProfileManager implements UserProfileManagerModel<UserProfile> {
  @override
  Future<UserProfile> create(String authToken, UserProfile userProfile) async {
    bool acceptPrivacyPolicy = false;
    bool termsAndConditions = false;

    gql.GetUserProfile_OperationResult result = await runGql(
        gql.GetUserProfile(),
        headers: GlobalHeaders.fromAuthToken(authToken));

    Currency currency =
        Currency(gql.toCurrencyString(result.profile.currency).toUpperCase());

    result.profile.usercontractSet.edges.forEach((edge) {
      if (edge.node.name == UserContracts.privacyPolicy.toString())
        acceptPrivacyPolicy = true;
      if (edge.node.name == UserContracts.termsAndConditions.toString())
        termsAndConditions = true;
    });

    return generateBackendPropertyHash(UserProfile(
        userId: result.profile.id,
        currency: currency,
        acceptPrivacyPolicy: acceptPrivacyPolicy,
        acceptTermsAndConditions: termsAndConditions));
  }
  ```
  As you can see, we have a UserProfile class that holds various properties we store on our gql server, we made a UserProfileManager interface that creates a UserProfile with the results.
