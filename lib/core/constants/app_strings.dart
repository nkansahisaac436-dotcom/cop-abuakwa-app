/// Standardized app strings and exact required text messages
class AppStrings {
  AppStrings._();

  static const String appName = 'Abuakwa Area Connect';
  static const String churchAreaName = 'The Church of Pentecost, Abuakwa Area';
  static const String welcomeBack = 'Welcome back';
  static const String loginSubtitle = 'Log in to see what is happening in your Area.';
  static const String email = 'Email';
  static const String emailPlaceholder = 'you@example.com';
  static const String password = 'Password';
  static const String passwordPlaceholder = '••••••••';
  static const String forgotPassword = 'Forgot password?';
  static const String logIn = 'Log in';
  static const String newHere = 'New here?';
  static const String createMemberAccount = 'Create a member account';
  static const String pastorInviteNote = 'Pastor or ministry leader? Use the invite from your Area Head.';

  // Sign-up Strings
  static const String createYourAccount = 'Create your account';
  static const String fullName = 'Full name';
  static const String fullNamePlaceholder = 'Kofi Mensah';
  static const String district = 'District';
  static const String chooseDistrict = 'Choose your district';
  static const String assembly = 'Assembly';
  static const String chooseAssembly = 'Choose your assembly';
  static const String createPassword = 'Create a password';
  static const String dataConsent = 'I agree to how my details are used.';
  static const String createAccount = 'Create account';

  // Exact Required Messages (Section 5.1 & Section 9)
  static const String districtNotApprovedTitle = 'District not approved yet';
  static const String districtNotApprovedMessage =
      'Please try to sign up again later, once your district is approved.';
  static const String districtInactiveBlockedToast =
      'Your district has not been approved yet. Please try to sign up again later, once your district is approved.';
  static const String invalidCredentialsMessage =
      'Email or password is not correct. Check and try again.';
  static const String transferConfirmMessage =
      'Are you sure? This will send a transfer request to the Area Head.';

  // Ministries
  static const List<String> ministries = [
    'Youth',
    'Evangelism',
    "Children's",
    'Pemem',
    "Women's",
  ];
}
