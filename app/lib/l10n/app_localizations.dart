import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'BookBridge'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'NEARBY'**
  String get nearby;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'DONATE'**
  String get donate;

  /// No description provided for @discoverBooks.
  ///
  /// In en, this message translates to:
  /// **'Discover books in your community'**
  String get discoverBooks;

  /// No description provided for @supportCommunity.
  ///
  /// In en, this message translates to:
  /// **'Support the BookBridge\nCommunity'**
  String get supportCommunity;

  /// No description provided for @supportDescription.
  ///
  /// In en, this message translates to:
  /// **'Your contribution helps us keep the platform free and accessible for all students.'**
  String get supportDescription;

  /// No description provided for @giveBooks.
  ///
  /// In en, this message translates to:
  /// **'Give books, create impact'**
  String get giveBooks;

  /// No description provided for @exploreNow.
  ///
  /// In en, this message translates to:
  /// **'Explore Now'**
  String get exploreNow;

  /// No description provided for @giveNow.
  ///
  /// In en, this message translates to:
  /// **'Give Now'**
  String get giveNow;

  /// No description provided for @featuredBooks.
  ///
  /// In en, this message translates to:
  /// **'Featured Books'**
  String get featuredBooks;

  /// No description provided for @yourNearbyBooks.
  ///
  /// In en, this message translates to:
  /// **'Your nearby books'**
  String get yourNearbyBooks;

  /// No description provided for @recentListings.
  ///
  /// In en, this message translates to:
  /// **'Recent Listings'**
  String get recentListings;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search title, author, or ISBN...'**
  String get searchHint;

  /// No description provided for @noBooksFound.
  ///
  /// In en, this message translates to:
  /// **'No Books Found'**
  String get noBooksFound;

  /// No description provided for @exploreNearby.
  ///
  /// In en, this message translates to:
  /// **'Explore Nearby'**
  String get exploreNearby;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get verified;

  /// No description provided for @sold.
  ///
  /// In en, this message translates to:
  /// **'SOLD'**
  String get sold;

  /// No description provided for @boosted.
  ///
  /// In en, this message translates to:
  /// **'BOOSTED'**
  String get boosted;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInSubtitle;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Join BookBridge'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to start browsing'**
  String get signUpSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get haveAccount;

  /// No description provided for @appBranding.
  ///
  /// In en, this message translates to:
  /// **'BookBridge: Knowledge for All'**
  String get appBranding;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Democratizing access to affordable books in Cameroon.'**
  String get appTagline;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'student@university.cm'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get passwordHint;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordContent.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to receive a password reset link.'**
  String get resetPasswordContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Link'**
  String get sendLink;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @signUpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sign up successful! Welcome.'**
  String get signUpSuccess;

  /// No description provided for @appMarketingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Connecting students, authors, and bookshops to end learning poverty.'**
  String get appMarketingHeadline;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. John Doe'**
  String get fullNameHint;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// No description provided for @localityLabel.
  ///
  /// In en, this message translates to:
  /// **'Locality / Neighborhood'**
  String get localityLabel;

  /// No description provided for @localityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Molyko, Buea'**
  String get localityHint;

  /// No description provided for @localityRequired.
  ///
  /// In en, this message translates to:
  /// **'Locality is required'**
  String get localityRequired;

  /// No description provided for @whatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money Number'**
  String get whatsappLabel;

  /// No description provided for @whatsappHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 677...'**
  String get whatsappHint;

  /// No description provided for @whatsappRequired.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money number is required'**
  String get whatsappRequired;

  /// No description provided for @whatsappInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 9-digit number'**
  String get whatsappInvalid;

  /// No description provided for @passwordRequirement.
  ///
  /// In en, this message translates to:
  /// **'Min. 6 characters'**
  String get passwordRequirement;

  /// No description provided for @pricesListedIn.
  ///
  /// In en, this message translates to:
  /// **'PRICES ARE LISTED IN FCFA'**
  String get pricesListedIn;

  /// No description provided for @logInButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logInButton;

  /// No description provided for @shareTextCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check out this book on BookBridge:'**
  String get shareTextCheckOut;

  /// No description provided for @shareTextCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get shareTextCondition;

  /// No description provided for @shareTextDownload.
  ///
  /// In en, this message translates to:
  /// **'Download BookBridge to view more details!'**
  String get shareTextDownload;

  /// No description provided for @whatsappNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No WhatsApp number available'**
  String get whatsappNotAvailable;

  /// No description provided for @whatsappDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi, I saw your book on BookBridge and I am interested!'**
  String get whatsappDefaultMessage;

  /// No description provided for @whatsappLaunchError.
  ///
  /// In en, this message translates to:
  /// **'Could not launch WhatsApp'**
  String get whatsappLaunchError;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get errorPrefix;

  /// No description provided for @phoneNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No phone number available'**
  String get phoneNotAvailable;

  /// No description provided for @dialerLaunchError.
  ///
  /// In en, this message translates to:
  /// **'Could not launch dialer'**
  String get dialerLaunchError;

  /// No description provided for @bookDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Details'**
  String get bookDetailsTitle;

  /// No description provided for @failedToLoadListing.
  ///
  /// In en, this message translates to:
  /// **'Failed to load listing'**
  String get failedToLoadListing;

  /// No description provided for @listingNotAvailableSnackBar.
  ///
  /// In en, this message translates to:
  /// **'This listing is no longer available.'**
  String get listingNotAvailableSnackBar;

  /// No description provided for @buyBackEligible.
  ///
  /// In en, this message translates to:
  /// **'Buy-Back Eligible'**
  String get buyBackEligible;

  /// No description provided for @buyBackDescription.
  ///
  /// In en, this message translates to:
  /// **'Sell this book back to the platform when you\'re done.'**
  String get buyBackDescription;

  /// No description provided for @sellerTypeIndividualDesc.
  ///
  /// In en, this message translates to:
  /// **'This student is selling to fund their next semester.'**
  String get sellerTypeIndividualDesc;

  /// No description provided for @sellerTypeBookshopDesc.
  ///
  /// In en, this message translates to:
  /// **'A verified local bookshop supporting the community.'**
  String get sellerTypeBookshopDesc;

  /// No description provided for @sellerTypeAuthorDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct from the author. Supporting local creativity.'**
  String get sellerTypeAuthorDesc;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get descriptionLabel;

  /// No description provided for @noDescriptionProvided.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get noDescriptionProvided;

  /// No description provided for @sellerInformationLabel.
  ///
  /// In en, this message translates to:
  /// **'SELLER INFORMATION'**
  String get sellerInformationLabel;

  /// No description provided for @unknownSeller.
  ///
  /// In en, this message translates to:
  /// **'Unknown Seller'**
  String get unknownSeller;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown Location'**
  String get unknownLocation;

  /// No description provided for @sellerTypeBookshopPromo.
  ///
  /// In en, this message translates to:
  /// **'Supporting local businesses democratizes access to knowledge.'**
  String get sellerTypeBookshopPromo;

  /// No description provided for @sellerTypeAuthorPromo.
  ///
  /// In en, this message translates to:
  /// **'Supporting local authors fosters a vibrant culture of learning.'**
  String get sellerTypeAuthorPromo;

  /// No description provided for @contactSellerWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Contact Seller via WhatsApp'**
  String get contactSellerWhatsApp;

  /// No description provided for @callSeller.
  ///
  /// In en, this message translates to:
  /// **'Call Seller'**
  String get callSeller;

  /// No description provided for @categoryTextbooks.
  ///
  /// In en, this message translates to:
  /// **'Textbooks'**
  String get categoryTextbooks;

  /// No description provided for @categoryFiction.
  ///
  /// In en, this message translates to:
  /// **'Fiction'**
  String get categoryFiction;

  /// No description provided for @categoryScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get categoryScience;

  /// No description provided for @categoryHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get categoryHistory;

  /// No description provided for @categoryGCE.
  ///
  /// In en, this message translates to:
  /// **'GCE'**
  String get categoryGCE;

  /// No description provided for @categoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// No description provided for @categoryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get categoryTechnology;

  /// No description provided for @categoryArts.
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get categoryArts;

  /// No description provided for @categoryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get categoryLanguage;

  /// No description provided for @categoryMathematics.
  ///
  /// In en, this message translates to:
  /// **'Mathematics'**
  String get categoryMathematics;

  /// No description provided for @categoryEngineering.
  ///
  /// In en, this message translates to:
  /// **'Engineering'**
  String get categoryEngineering;

  /// No description provided for @categoryMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get categoryMedicine;

  /// No description provided for @sellSuccessUpdate.
  ///
  /// In en, this message translates to:
  /// **'Listing updated successfully!'**
  String get sellSuccessUpdate;

  /// No description provided for @sellSuccessCreate.
  ///
  /// In en, this message translates to:
  /// **'Listing created successfully!'**
  String get sellSuccessCreate;

  /// No description provided for @selectImageSource.
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @editListing.
  ///
  /// In en, this message translates to:
  /// **'Edit Listing'**
  String get editListing;

  /// No description provided for @sellABook.
  ///
  /// In en, this message translates to:
  /// **'Sell a Book'**
  String get sellABook;

  /// No description provided for @bookTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Book Title'**
  String get bookTitleLabel;

  /// No description provided for @bookTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Pure Physics'**
  String get bookTitleHint;

  /// No description provided for @bookTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get bookTitleRequired;

  /// No description provided for @authorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get authorLabel;

  /// No description provided for @authorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nelkon & Parker'**
  String get authorHint;

  /// No description provided for @authorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an author'**
  String get authorRequired;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (FCFA)'**
  String get priceLabel;

  /// No description provided for @priceHint.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get priceHint;

  /// No description provided for @priceRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a price'**
  String get priceRequired;

  /// No description provided for @priceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get priceInvalid;

  /// No description provided for @descriptionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionFieldLabel;

  /// No description provided for @descriptionFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the book (edition, language, etc.)'**
  String get descriptionFieldHint;

  /// No description provided for @bookConditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Book Condition'**
  String get bookConditionLabel;

  /// No description provided for @conditionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get conditionNew;

  /// No description provided for @conditionLikeNew.
  ///
  /// In en, this message translates to:
  /// **'Like New'**
  String get conditionLikeNew;

  /// No description provided for @conditionGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get conditionGood;

  /// No description provided for @conditionFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get conditionFair;

  /// No description provided for @conditionPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get conditionPoor;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @selectCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategoryHint;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @socialVentureFeatures.
  ///
  /// In en, this message translates to:
  /// **'Social Venture Features'**
  String get socialVentureFeatures;

  /// No description provided for @sellerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller Type'**
  String get sellerTypeLabel;

  /// No description provided for @sellerTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual Student'**
  String get sellerTypeIndividual;

  /// No description provided for @sellerTypeBookshop.
  ///
  /// In en, this message translates to:
  /// **'Verified Bookshop'**
  String get sellerTypeBookshop;

  /// No description provided for @sellerTypeAuthor.
  ///
  /// In en, this message translates to:
  /// **'Local Author'**
  String get sellerTypeAuthor;

  /// No description provided for @eligibleForBuyBack.
  ///
  /// In en, this message translates to:
  /// **'Eligible for Buy-Back'**
  String get eligibleForBuyBack;

  /// No description provided for @buyBackSwitchDesc.
  ///
  /// In en, this message translates to:
  /// **'Permit students to sell this book back when finished.'**
  String get buyBackSwitchDesc;

  /// No description provided for @availableStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Available Stock'**
  String get availableStockLabel;

  /// No description provided for @stockHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10'**
  String get stockHint;

  /// No description provided for @locationInfo.
  ///
  /// In en, this message translates to:
  /// **'Listing will be visible in your current region'**
  String get locationInfo;

  /// No description provided for @updateListingButton.
  ///
  /// In en, this message translates to:
  /// **'Update Listing'**
  String get updateListingButton;

  /// No description provided for @postListingButton.
  ///
  /// In en, this message translates to:
  /// **'Post Listing'**
  String get postListingButton;

  /// No description provided for @addBookPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add book photos'**
  String get addBookPhotos;

  /// No description provided for @whatIsYourInterest.
  ///
  /// In en, this message translates to:
  /// **'What is your interest?'**
  String get whatIsYourInterest;

  /// No description provided for @academicCategories.
  ///
  /// In en, this message translates to:
  /// **'Academic Categories'**
  String get academicCategories;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// No description provided for @noResultsFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String noResultsFoundFor(Object query);

  /// No description provided for @resultsFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results found} =1{1 result found} other{{count} results found}}'**
  String resultsFoundCount(num count);

  /// No description provided for @cameroon.
  ///
  /// In en, this message translates to:
  /// **'Cameroon'**
  String get cameroon;

  /// No description provided for @myBooks.
  ///
  /// In en, this message translates to:
  /// **'My Books'**
  String get myBooks;

  /// No description provided for @noBooksListedYet.
  ///
  /// In en, this message translates to:
  /// **'No Books Listed Yet'**
  String get noBooksListedYet;

  /// No description provided for @startSellingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start selling by listing your first book!'**
  String get startSellingPrompt;

  /// No description provided for @listFirstBookButton.
  ///
  /// In en, this message translates to:
  /// **'List Your First Book'**
  String get listFirstBookButton;

  /// No description provided for @failedToLoadMyBooks.
  ///
  /// In en, this message translates to:
  /// **'Failed to Load Your Books'**
  String get failedToLoadMyBooks;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get pleaseTryAgain;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @deleteListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Listing'**
  String get deleteListingTitle;

  /// No description provided for @deleteListingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this listing? This action cannot be undone.'**
  String get deleteListingConfirmation;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @listingDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Listing deleted successfully'**
  String get listingDeletedSuccessfully;

  /// No description provided for @failedToDeleteNotification.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDeleteNotification(Object error);

  /// No description provided for @statusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get statusAvailable;

  /// No description provided for @statusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get statusSold;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something Went Wrong'**
  String get somethingWentWrong;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection.'**
  String get checkConnection;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @firstListingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Be the first to list a book in your area!'**
  String get firstListingPrompt;

  /// No description provided for @tryAnotherCategory.
  ///
  /// In en, this message translates to:
  /// **'Try another category or clear the filter.'**
  String get tryAnotherCategory;

  /// No description provided for @noBooksIn.
  ///
  /// In en, this message translates to:
  /// **'No Books in {category}'**
  String noBooksIn(Object category);

  /// No description provided for @priceFormat.
  ///
  /// In en, this message translates to:
  /// **'{price} FCFA'**
  String priceFormat(Object price);

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get myAccount;

  /// No description provided for @myProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'My Profile Edit'**
  String get myProfileEdit;

  /// No description provided for @myFavourites.
  ///
  /// In en, this message translates to:
  /// **'My Favourites'**
  String get myFavourites;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsConditions;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @inviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join me on BookBridge, the peer-to-peer marketplace for used books in Cameroon! 📚✨\n\nDownload or visit us at: https://book-bridge-three.vercel.app/'**
  String get inviteMessage;

  /// No description provided for @inviteSubject.
  ///
  /// In en, this message translates to:
  /// **'Invite to BookBridge'**
  String get inviteSubject;

  /// No description provided for @aboutBookBridge.
  ///
  /// In en, this message translates to:
  /// **'About BookBridge'**
  String get aboutBookBridge;

  /// No description provided for @activeBooks.
  ///
  /// In en, this message translates to:
  /// **'Active Books'**
  String get activeBooks;

  /// No description provided for @totalValue.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get totalValue;

  /// No description provided for @followUs.
  ///
  /// In en, this message translates to:
  /// **'Follow Us'**
  String get followUs;

  /// No description provided for @facebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get facebook;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @youtube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youtube;

  /// No description provided for @linkedin.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get linkedin;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmMessage;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccess;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile.'**
  String get profileUpdateFailed;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get enterFullName;

  /// No description provided for @localityNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Locality / Neighborhood'**
  String get localityNeighborhood;

  /// No description provided for @whatsappNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money Number'**
  String get whatsappNumber;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeYourProfile;

  /// No description provided for @justOneMoreStep.
  ///
  /// In en, this message translates to:
  /// **'Just one more step!'**
  String get justOneMoreStep;

  /// No description provided for @completeProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To start buying and selling, we need a few more details to help other students find you.'**
  String get completeProfileSubtitle;

  /// No description provided for @numberRequired.
  ///
  /// In en, this message translates to:
  /// **'Number is required'**
  String get numberRequired;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 9-digit number'**
  String get enterValidNumber;

  /// No description provided for @completeSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get completeSetup;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'BookBridge is a peer-to-peer marketplace designed for students in Cameroon. Our mission is to make educational resources accessible and affordable by connecting students who want to sell their used books with those who need them.'**
  String get aboutDescription;

  /// No description provided for @projectSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Project Source Code'**
  String get projectSourceCode;

  /// No description provided for @viewOnGitHub.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get viewOnGitHub;

  /// No description provided for @officialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Website'**
  String get officialWebsite;

  /// No description provided for @visitWebPlatform.
  ///
  /// In en, this message translates to:
  /// **'Visit our web platform'**
  String get visitWebPlatform;

  /// No description provided for @connectWithAuthor.
  ///
  /// In en, this message translates to:
  /// **'Connect with {name}'**
  String connectWithAuthor(Object name);

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} DCT-Berinyuy. All rights reserved.'**
  String copyright(Object year);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @errorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetails(Object error);

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Yet'**
  String get noNotificationsYet;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see alerts about your listings, messages, and activity here.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favourites'**
  String get myFavorites;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @favoritesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Books you heart will appear here.'**
  String get favoritesEmptySubtitle;

  /// No description provided for @exploreBooks.
  ///
  /// In en, this message translates to:
  /// **'Explore Books'**
  String get exploreBooks;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent!'**
  String get passwordResetSent;

  /// No description provided for @cameroonFcfa.
  ///
  /// In en, this message translates to:
  /// **'CAMEROON • FCFA'**
  String get cameroonFcfa;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @pleaseEnterFeedback.
  ///
  /// In en, this message translates to:
  /// **'Please enter your feedback'**
  String get pleaseEnterFeedback;

  /// No description provided for @feedbackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackSuccess;

  /// No description provided for @feedbackError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send feedback: {error}'**
  String feedbackError(Object error);

  /// No description provided for @weValueInput.
  ///
  /// In en, this message translates to:
  /// **'We value your input!'**
  String get weValueInput;

  /// No description provided for @feedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you like about BookBridge or what we can improve. Your feedback helps us build a better platform for everyone.'**
  String get feedbackSubtitle;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Type your feedback here...'**
  String get feedbackHint;

  /// No description provided for @submitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get submitFeedback;

  /// No description provided for @feedbackAggrement.
  ///
  /// In en, this message translates to:
  /// **'By submitting, you agree that your feedback may be used to improve our services.'**
  String get feedbackAggrement;

  /// No description provided for @getInTouch.
  ///
  /// In en, this message translates to:
  /// **'Get in touch'**
  String get getInTouch;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have a question, feedback, or need support? We\'re here to help you get the most out of BookBridge.'**
  String get contactSubtitle;

  /// No description provided for @whatsappSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get whatsappSupport;

  /// No description provided for @chatDirectly.
  ///
  /// In en, this message translates to:
  /// **'Chat with us directly'**
  String get chatDirectly;

  /// No description provided for @emailUs.
  ///
  /// In en, this message translates to:
  /// **'Email Us'**
  String get emailUs;

  /// No description provided for @availableHours.
  ///
  /// In en, this message translates to:
  /// **'Available Mon - Sat, 8 AM - 6 PM'**
  String get availableHours;

  /// No description provided for @privacyIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Introduction'**
  String get privacyIntroTitle;

  /// No description provided for @privacyIntroContent.
  ///
  /// In en, this message translates to:
  /// **'Welcome to BookBridge. We value your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we look after your personal data when you visit our application and tell you about your privacy rights.'**
  String get privacyIntroContent;

  /// No description provided for @privacyCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Data We Collect'**
  String get privacyCollectTitle;

  /// No description provided for @privacyCollectContent.
  ///
  /// In en, this message translates to:
  /// **'We may collect, use, store and transfer different kinds of personal data about you which we have grouped together as follows:\n\n• Identity Data: Name, username or similar identifier.\n• Contact Data: Email address and telephone numbers.\n• Technical Data: IP address, login data, browser type and version, time zone setting and location.\n• Profile Data: Your username, password, listings made by you, your interests, and favorites.'**
  String get privacyCollectContent;

  /// No description provided for @privacyUseTitle.
  ///
  /// In en, this message translates to:
  /// **'3. How We Use Your Data'**
  String get privacyUseTitle;

  /// No description provided for @privacyUseContent.
  ///
  /// In en, this message translates to:
  /// **'We only use your personal data when the law allows us to. Most commonly, we will use your personal data in the following circumstances:\n\n• To register you as a new user.\n• To facilitate the peer-to-peer marketplace (connecting buyers and sellers).\n• To improve our application, services, and user experience.\n• To manage our relationship with you.'**
  String get privacyUseContent;

  /// No description provided for @privacySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'4. Data Sharing'**
  String get privacySharingTitle;

  /// No description provided for @privacySharingContent.
  ///
  /// In en, this message translates to:
  /// **'When you list a book, your contact information will be shared with potential buyers to facilitate the transaction. We do not sell your personal data to third parties for marketing purposes.'**
  String get privacySharingContent;

  /// No description provided for @privacySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'5. Data Security'**
  String get privacySecurityTitle;

  /// No description provided for @privacySecurityContent.
  ///
  /// In en, this message translates to:
  /// **'We have put in place appropriate security measures to prevent your personal data from being accidentally lost, used or accessed in an unauthorized way, altered or disclosed.'**
  String get privacySecurityContent;

  /// No description provided for @privacyRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'6. Your Rights'**
  String get privacyRightsTitle;

  /// No description provided for @privacyRightsContent.
  ///
  /// In en, this message translates to:
  /// **'You have the right to request access to, correction of, or erasure of your personal data. You can manage most of your data directly through your profile settings in the application.'**
  String get privacyRightsContent;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String lastUpdated(Object date);

  /// No description provided for @termsAcceptanceTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get termsAcceptanceTitle;

  /// No description provided for @termsAcceptanceContent.
  ///
  /// In en, this message translates to:
  /// **'By accessing or using the BookBridge application, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you may not use our service.'**
  String get termsAcceptanceContent;

  /// No description provided for @termsMarketplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Marketplace Rules'**
  String get termsMarketplaceTitle;

  /// No description provided for @termsMarketplaceContent.
  ///
  /// In en, this message translates to:
  /// **'BookBridge is a platform that facilitates the sale and purchase of used books between users. We are not a party to the actual transactions between buyers and sellers.\n\n• Sellers are responsible for the accuracy of their listings.\n• Buyers are responsible for verifying the condition of the books before purchase.\n• All transactions are made directly between users.'**
  String get termsMarketplaceContent;

  /// No description provided for @termsResponsibilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'3. User Responsibilities'**
  String get termsResponsibilitiesTitle;

  /// No description provided for @termsResponsibilitiesContent.
  ///
  /// In en, this message translates to:
  /// **'You must provide accurate information when creating an account and listing books. You are prohibited from posting content that is illegal, offensive, or infringing on the rights of others.'**
  String get termsResponsibilitiesContent;

  /// No description provided for @termsPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'4. Payments'**
  String get termsPaymentsTitle;

  /// No description provided for @termsPaymentsContent.
  ///
  /// In en, this message translates to:
  /// **'Payments for books are generally handled in cash upon delivery or via direct mobile money transfer between the buyer and seller. BookBridge may offer integrated payment solutions (like Fapshi) for specific services or donations.'**
  String get termsPaymentsContent;

  /// No description provided for @termsLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'5. Limitation of Liability'**
  String get termsLiabilityTitle;

  /// No description provided for @termsLiabilityContent.
  ///
  /// In en, this message translates to:
  /// **'BookBridge is provided \"as is\" without any warranties. We are not liable for any disputes, losses, or damages arising from your use of the application or transactions with other users.'**
  String get termsLiabilityContent;

  /// No description provided for @termsChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'6. Changes to Terms'**
  String get termsChangesTitle;

  /// No description provided for @termsChangesContent.
  ///
  /// In en, this message translates to:
  /// **'We reserve the right to modify these terms at any time. Your continued use of the application following any changes constitutes acceptance of the new terms.'**
  String get termsChangesContent;

  /// No description provided for @faqGeneralCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get faqGeneralCategory;

  /// No description provided for @faqWhatIsBookBridgeQ.
  ///
  /// In en, this message translates to:
  /// **'What is BookBridge?'**
  String get faqWhatIsBookBridgeQ;

  /// No description provided for @faqWhatIsBookBridgeA.
  ///
  /// In en, this message translates to:
  /// **'BookBridge is a peer-to-peer marketplace designed specifically for students in Cameroon to buy and sell used physical books at affordable prices.'**
  String get faqWhatIsBookBridgeA;

  /// No description provided for @faqCreateAccountQ.
  ///
  /// In en, this message translates to:
  /// **'How do I create an account?'**
  String get faqCreateAccountQ;

  /// No description provided for @faqCreateAccountA.
  ///
  /// In en, this message translates to:
  /// **'You can sign up using your email address or quickly sign in with your Google account. After signing in, you\'ll need to complete your profile with a few details like your locality and Mobile Money number.'**
  String get faqCreateAccountA;

  /// No description provided for @faqBuyingCategory.
  ///
  /// In en, this message translates to:
  /// **'Buying Books'**
  String get faqBuyingCategory;

  /// No description provided for @faqHowToBuyQ.
  ///
  /// In en, this message translates to:
  /// **'How do I buy a book?'**
  String get faqHowToBuyQ;

  /// No description provided for @faqHowToBuyA.
  ///
  /// In en, this message translates to:
  /// **'Browse the listings on the Home screen or use the search bar. When you find a book you like, tap on it to see details, then use the \"Message Seller\" button to chat with them to arrange the purchase.'**
  String get faqHowToBuyA;

  /// No description provided for @faqHowToPayQ.
  ///
  /// In en, this message translates to:
  /// **'How do I pay for a book?'**
  String get faqHowToPayQ;

  /// No description provided for @faqHowToPayA.
  ///
  /// In en, this message translates to:
  /// **'Most transactions happen directly between the buyer and seller. You can pay in cash during a physical meeting or via Mobile Money if both parties agree. Always verify the book\'s condition before paying.'**
  String get faqHowToPayA;

  /// No description provided for @faqNearbyBooksQ.
  ///
  /// In en, this message translates to:
  /// **'Can I see books near me?'**
  String get faqNearbyBooksQ;

  /// No description provided for @faqNearbyBooksA.
  ///
  /// In en, this message translates to:
  /// **'Yes! The \"Your nearby books\" section on the Home screen uses your location to show books available in your immediate vicinity, sorted by distance.'**
  String get faqNearbyBooksA;

  /// No description provided for @faqSellingCategory.
  ///
  /// In en, this message translates to:
  /// **'Selling Books'**
  String get faqSellingCategory;

  /// No description provided for @faqHowToListQ.
  ///
  /// In en, this message translates to:
  /// **'How do I list a book for sale?'**
  String get faqHowToListQ;

  /// No description provided for @faqHowToListA.
  ///
  /// In en, this message translates to:
  /// **'Tap the \"Sell\" button in the bottom navigation bar. Upload a clear photo of the book, enter the title, author, price, and condition, then submit the listing.'**
  String get faqHowToListA;

  /// No description provided for @faqSellingFeesQ.
  ///
  /// In en, this message translates to:
  /// **'Is there a fee for selling?'**
  String get faqSellingFeesQ;

  /// No description provided for @faqSellingFeesA.
  ///
  /// In en, this message translates to:
  /// **'Currently, listing books on BookBridge is free for individual students. We want to make it as easy as possible for you to recycle your educational resources.'**
  String get faqSellingFeesA;

  /// No description provided for @faqBuyBackEligibleQ.
  ///
  /// In en, this message translates to:
  /// **'What is \"Buy-Back Eligible\"?'**
  String get faqBuyBackEligibleQ;

  /// No description provided for @faqBuyBackEligibleA.
  ///
  /// In en, this message translates to:
  /// **'Some listings from verified bookshops or the platform itself may be eligible for buy-back. This means you can sell the book back to the source at a pre-determined price once you\'re finished with it.'**
  String get faqBuyBackEligibleA;

  /// No description provided for @faqSafetyCategory.
  ///
  /// In en, this message translates to:
  /// **'Safety & Trust'**
  String get faqSafetyCategory;

  /// No description provided for @faqTrustworthySellerQ.
  ///
  /// In en, this message translates to:
  /// **'How do I know a seller is trustworthy?'**
  String get faqTrustworthySellerQ;

  /// No description provided for @faqTrustworthySellerA.
  ///
  /// In en, this message translates to:
  /// **'Check for the \"Verified\" badge on listings. For individual students, we encourage meeting in safe, public locations like your school campus or a busy library to complete transactions.'**
  String get faqTrustworthySellerA;

  /// No description provided for @faqProblemQ.
  ///
  /// In en, this message translates to:
  /// **'What should I do if there\'s a problem?'**
  String get faqProblemQ;

  /// No description provided for @faqProblemA.
  ///
  /// In en, this message translates to:
  /// **'If you encounter any issues with a transaction or another user, please use the \"Feedback\" or \"Contact Us\" options in your profile to report it to our team.'**
  String get faqProblemA;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount} FCFA'**
  String totalLabel(Object amount);

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (6xx...)'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 677777777'**
  String get phoneNumberHint;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @initiatingTransaction.
  ///
  /// In en, this message translates to:
  /// **'Initiating transaction...'**
  String get initiatingTransaction;

  /// No description provided for @confirmPaymentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the payment request on your phone!'**
  String get confirmPaymentPrompt;

  /// No description provided for @iHavePaid.
  ///
  /// In en, this message translates to:
  /// **'I have paid'**
  String get iHavePaid;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @faqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faqTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @termsAndConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditionsTitle;

  /// No description provided for @noListingFound.
  ///
  /// In en, this message translates to:
  /// **'Listing not found'**
  String get noListingFound;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @boostListing.
  ///
  /// In en, this message translates to:
  /// **'Boost Listing'**
  String get boostListing;

  /// No description provided for @boostListingDesc.
  ///
  /// In en, this message translates to:
  /// **'Boost your listing to the top for 7 days'**
  String get boostListingDesc;

  /// No description provided for @boostListingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Listing boosted successfully! It will be prioritized in searches.'**
  String get boostListingSuccess;

  /// No description provided for @boostListingPrice.
  ///
  /// In en, this message translates to:
  /// **'Boost Price: 500 FCFA'**
  String get boostListingPrice;

  /// No description provided for @messageSeller.
  ///
  /// In en, this message translates to:
  /// **'Message Seller'**
  String get messageSeller;

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @startConversationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Message a seller from any listing to start a conversation.'**
  String get startConversationPrompt;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello! Start the conversation.'**
  String get sayHello;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get buyNow;

  /// No description provided for @supportBookBridge.
  ///
  /// In en, this message translates to:
  /// **'Support BookBridge ☕'**
  String get supportBookBridge;

  /// No description provided for @selectDonationAmount.
  ///
  /// In en, this message translates to:
  /// **'Select Donation Amount'**
  String get selectDonationAmount;

  /// No description provided for @donationThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support!'**
  String get donationThanks;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchases;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @transactionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your history of bought and sold books will appear here.'**
  String get transactionsEmptySubtitle;

  /// No description provided for @orderId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get orderId;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @leaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a Review'**
  String get leaveReview;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get statusSuccessful;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review Submitted'**
  String get reviewSubmitted;

  /// No description provided for @rateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Experience'**
  String get rateYourExperience;

  /// No description provided for @howWasTransaction.
  ///
  /// In en, this message translates to:
  /// **'How was your transaction for'**
  String get howWasTransaction;

  /// No description provided for @leaveAComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)...'**
  String get leaveAComment;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get reviewSubmit;

  /// No description provided for @reviewLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can leave a review later from your Transaction History.'**
  String get reviewLaterHint;

  /// No description provided for @leaveAReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a Review'**
  String get leaveAReview;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @locationServices.
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get locationServices;

  /// No description provided for @socialImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Social Venture Mission'**
  String get socialImpactTitle;

  /// No description provided for @booksCirculated.
  ///
  /// In en, this message translates to:
  /// **'Circulated'**
  String get booksCirculated;

  /// No description provided for @moneySaved.
  ///
  /// In en, this message translates to:
  /// **'FCFA Saved'**
  String get moneySaved;

  /// No description provided for @co2Saved.
  ///
  /// In en, this message translates to:
  /// **'Tonnes CO2'**
  String get co2Saved;

  /// No description provided for @safetyGuidelinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety Guidelines'**
  String get safetyGuidelinesTitle;

  /// No description provided for @safeMeetupLocations.
  ///
  /// In en, this message translates to:
  /// **'Safe Meetup Locations'**
  String get safeMeetupLocations;

  /// No description provided for @whatToCheck.
  ///
  /// In en, this message translates to:
  /// **'What to Check'**
  String get whatToCheck;

  /// No description provided for @paymentSafety.
  ///
  /// In en, this message translates to:
  /// **'Payment Safety'**
  String get paymentSafety;

  /// No description provided for @reportIssues.
  ///
  /// In en, this message translates to:
  /// **'Report Issues'**
  String get reportIssues;

  /// No description provided for @meetupTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrange Meetup Safely'**
  String get meetupTipsTitle;

  /// No description provided for @meetupTipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always swap books in public campus areas and inspect before paying.'**
  String get meetupTipsSubtitle;

  /// No description provided for @viewSafetyGuidelines.
  ///
  /// In en, this message translates to:
  /// **'View Safety Guidelines'**
  String get viewSafetyGuidelines;

  /// No description provided for @campusMeetupZones.
  ///
  /// In en, this message translates to:
  /// **'Verified Meetup Zones'**
  String get campusMeetupZones;

  /// No description provided for @campusMeetupZonesDesc.
  ///
  /// In en, this message translates to:
  /// **'Pre-approved, highly visible locations on your campus.'**
  String get campusMeetupZonesDesc;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openInMaps;

  /// No description provided for @verifiedZone.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED ZONE'**
  String get verifiedZone;

  /// No description provided for @notifPaymentConfirmedLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmed'**
  String get notifPaymentConfirmedLabel;

  /// No description provided for @notifNewInquiryLabel.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get notifNewInquiryLabel;

  /// No description provided for @notifImpactMilestoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Milestone Reached'**
  String get notifImpactMilestoneLabel;

  /// No description provided for @notifWelcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get notifWelcomeLabel;

  /// No description provided for @tapToViewListing.
  ///
  /// In en, this message translates to:
  /// **'Tap to view listing'**
  String get tapToViewListing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
