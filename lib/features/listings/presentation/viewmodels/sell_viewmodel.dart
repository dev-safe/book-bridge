import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/update_listing_usecase.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/academic_filters_mixin.dart';

/// State enum for the Sell screen.
enum SellState { initial, loading, success, error }

/// ViewModel for managing the sell/create listing functionality.
///
/// This ViewModel handles the creation of new listings including
/// form state management and API interactions.
class SellViewModel extends ChangeNotifier with AcademicFiltersMixin {
  final CreateListingUseCase createListingUseCase;
  final UpdateListingUseCase updateListingUseCase;
  final ListingRepository repository;
  final LocationViewModel locationViewModel;

  SellState _sellState = SellState.initial;
  String? _errorMessage;
  Listing? _createdListing;
  Listing? _editingListing;

  // Form fields
  String? _title;
  String? _author;
  int? _priceFcfa;
  BookCondition _condition = BookCondition.good;
  List<String> _imageUrls = const [];
  String? _description;
  String? _category;
  String _sellerType = 'individual';
  bool _isBuyBackEligible = false;
  int _stockCount = 1;

  // Guards async school lookups (edit prefill / profile default) against
  // races with user selection or form resets.
  int _schoolLookupToken = 0;

  SellViewModel({
    required this.createListingUseCase,
    required this.updateListingUseCase,
    required this.repository,
    required this.locationViewModel,
  });

  // Getters
  SellState get sellState => _sellState;
  String? get errorMessage => _errorMessage;
  Listing? get createdListing => _createdListing;
  Listing? get editingListing => _editingListing;
  bool get isLoading => _sellState == SellState.loading;
  bool get isEditing => _editingListing != null;

  @override
  ListingRepository get academicRepository => repository;

  /// Academic fields are form inputs here, not feed filters: just redraw.
  @override
  Future<void> onAcademicFiltersChanged() async => notifyListeners();

  Future<void> setClassLevel(String? id) => setClassLevelFilter(id);
  Future<void> setSubject(String? id) => setSubjectFilter(id);

  Future<void> setSchool(School? school) {
    _schoolLookupToken++;
    return setSchoolFilter(school);
  }

  /// Pre-selects the seller's profile school on a fresh (non-edit) form.
  Future<void> applyDefaultSchool(String? schoolId) async {
    if (schoolId == null || isEditing || selectedSchool != null) return;
    final token = ++_schoolLookupToken;
    final result = await repository.getSchoolById(schoolId);
    final school = result.fold((_) => null, (s) => s);
    if (token != _schoolLookupToken || isEditing || school == null) return;
    await setSchoolFilter(school);
  }

  String? get title => _title;
  String? get author => _author;
  int? get priceFcfa => _priceFcfa;
  BookCondition get condition => _condition;

  /// The cover photo (first image), or null when none has been added.
  String? get imageUrl => _imageUrls.isEmpty ? null : _imageUrls.first;

  /// All photos, cover first.
  List<String> get imageUrls => _imageUrls;

  /// Whether another photo can be added (cap: [Listing.maxImages]).
  bool get canAddImage => _imageUrls.length < Listing.maxImages;
  String? get description => _description;
  String? get category => _category;
  String get sellerType => _sellerType;
  bool get isBuyBackEligible => _isBuyBackEligible;
  int get stockCount => _stockCount;

  /// Updates the title field.
  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }

  /// Updates the author field.
  void setAuthor(String author) {
    _author = author;
    notifyListeners();
  }

  /// Updates the price field.
  void setPrice(int price) {
    _priceFcfa = price;
    notifyListeners();
  }

  /// Updates the condition field.
  void setCondition(BookCondition condition) {
    _condition = condition;
    notifyListeners();
  }

  /// Sets the cover photo, replacing the current cover if there is one.
  void setImageUrl(String imageUrl) {
    _imageUrls = List.unmodifiable([imageUrl, ..._imageUrls.skip(1)]);
    notifyListeners();
  }

  /// Appends a photo; ignored once [Listing.maxImages] is reached.
  void addImageUrl(String imageUrl) {
    if (!canAddImage) return;
    _imageUrls = List.unmodifiable([..._imageUrls, imageUrl]);
    notifyListeners();
  }

  /// Removes the photo at [index]; the next photo becomes the cover.
  void removeImageAt(int index) {
    if (index < 0 || index >= _imageUrls.length) return;
    _imageUrls = List.unmodifiable([
      for (var i = 0; i < _imageUrls.length; i++)
        if (i != index) _imageUrls[i],
    ]);
    notifyListeners();
  }

  /// Moves the photo at [index] to the front so it becomes the cover.
  void setCoverAt(int index) {
    if (index <= 0 || index >= _imageUrls.length) return;
    _imageUrls = List.unmodifiable([
      _imageUrls[index],
      for (var i = 0; i < _imageUrls.length; i++)
        if (i != index) _imageUrls[i],
    ]);
    notifyListeners();
  }

  /// Updates the description field.
  void setDescription(String description) {
    _description = description;
    notifyListeners();
  }

  /// Updates the category field.
  void setCategory(String? category) {
    _category = category;
    notifyListeners();
  }

  /// Updates the seller type field.
  void setSellerType(String sellerType) {
    _sellerType = sellerType;
    notifyListeners();
  }

  /// Updates the buy-back eligibility field.
  void setIsBuyBackEligible(bool isBuyBackEligible) {
    _isBuyBackEligible = isBuyBackEligible;
    notifyListeners();
  }

  /// Updates the stock count field.
  void setStockCount(int stockCount) {
    _stockCount = stockCount;
    notifyListeners();
  }

  /// Sets the listing to be edited and populates form fields.
  void setEditingListing(Listing listing) {
    _editingListing = listing;
    _title = listing.title;
    _author = listing.author;
    _priceFcfa = listing.priceFcfa;
    _condition = listing.condition;
    _imageUrls = List.unmodifiable(listing.gallery.take(Listing.maxImages));
    _description = listing.description;
    _category = listing.category;
    _sellerType = listing.sellerType;
    _isBuyBackEligible = listing.isBuyBackEligible;
    _stockCount = listing.stockCount;
    _prefillAcademicFields(listing);
    notifyListeners();
  }

  Future<void> _prefillAcademicFields(Listing listing) async {
    final token = ++_schoolLookupToken;
    await setClassLevelFilter(listing.classLevelId);
    await setSubjectFilter(listing.subjectId);
    await setSchoolFilter(null);
    final schoolId = listing.schoolId;
    if (schoolId == null) return;
    final result = await repository.getSchoolById(schoolId);
    final school = result.fold((_) => null, (s) => s);
    if (token != _schoolLookupToken || _editingListing?.id != listing.id) {
      return;
    }
    await setSchoolFilter(school);
  }

  /// Resets the form to initial state.
  void resetForm() {
    _title = null;
    _author = null;
    _priceFcfa = null;
    _condition = BookCondition.good;
    _imageUrls = const [];
    _description = null;
    _category = null;
    _sellerType = 'individual';
    _isBuyBackEligible = false;
    _stockCount = 1;
    _sellState = SellState.initial;
    _errorMessage = null;
    _createdListing = null;
    _editingListing = null;
    _schoolLookupToken++;
    clearAcademicFilters();
    notifyListeners();
  }

  /// Validates the form fields.
  bool validateForm() {
    if (_title == null || _title!.isEmpty) {
      _errorMessage = 'Title is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    if (_author == null || _author!.isEmpty) {
      _errorMessage = 'Author is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    if (_priceFcfa == null || _priceFcfa! <= 0) {
      _errorMessage = 'Valid price is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    if (_imageUrls.isEmpty || _imageUrls.any((url) => url.isEmpty)) {
      _errorMessage = 'Book image is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    if (selectedClassLevelId == null) {
      _errorMessage = 'Class level is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    if (selectedSubjectId == null) {
      _errorMessage = 'Subject is required';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    // Check if any image URL is a local file path (not yet uploaded)
    if (_imageUrls.any((url) => url.startsWith('/'))) {
      _errorMessage = 'Please wait for image to upload';
      _sellState = SellState.error;
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Creates a new listing.
  Future<void> createListing() async {
    if (!validateForm()) return;

    _sellState = SellState.loading;
    _errorMessage = null;
    notifyListeners();

    // Get current location
    final position = await _getCurrentLocation();

    final params = CreateListingParams(
      title: _title!,
      author: _author!,
      priceFcfa: _priceFcfa!,
      condition: _condition,
      imageUrl: _imageUrls.first,
      imageUrls: _imageUrls,
      description: _description,
      category: _category,
      sellerType: _sellerType,
      isBuyBackEligible: _isBuyBackEligible,
      stockCount: _stockCount,
      latitude: position?.latitude,
      longitude: position?.longitude,
      classLevelId: selectedClassLevelId,
      subjectId: selectedSubjectId,
      schoolId: selectedSchool?.id,
    );

    final result = await createListingUseCase(params);

    result.fold(
      (failure) {
        _sellState = SellState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (listing) {
        _createdListing = listing;
        _sellState = SellState.success;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Updates an existing listing.
  Future<void> updateListing() async {
    if (_editingListing == null || !validateForm()) return;

    _sellState = SellState.loading;
    _errorMessage = null;
    notifyListeners();

    // Get current location (optional update)
    final position = await _getCurrentLocation();

    final params = UpdateListingParams(
      id: _editingListing!.id,
      title: _title,
      author: _author,
      priceFcfa: _priceFcfa,
      condition: _condition,
      imageUrl: _imageUrls.first,
      imageUrls: _imageUrls,
      description: _description,
      category: _category,
      sellerType: _sellerType,
      isBuyBackEligible: _isBuyBackEligible,
      stockCount: _stockCount,
      latitude: position?.latitude,
      longitude: position?.longitude,
      classLevelId: selectedClassLevelId,
      subjectId: selectedSubjectId,
      schoolId: selectedSchool?.id,
      clearSchool: selectedSchool == null && _editingListing!.schoolId != null,
    );

    final result = await updateListingUseCase(params);

    result.fold(
      (failure) {
        _sellState = SellState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (listing) {
        _editingListing = null; // Clear editing state after success
        _sellState = SellState.success;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Picks an image from the gallery and appends it.
  Future<void> pickImageFromGallery() async {
    if (!canAddImage) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await addImageFile(File(pickedFile.path));
    }
  }

  /// Takes a photo using the camera and appends it.
  Future<void> pickImageFromCamera() async {
    if (!canAddImage) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      await addImageFile(File(pickedFile.path));
    }
  }

  /// Gets the current location (returns null when location is disabled).
  Future<Position?> _getCurrentLocation() async {
    if (!locationViewModel.locationEnabled) return null;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  /// Uploads [imageFile] to Supabase Storage and appends its URL.
  Future<void> addImageFile(File imageFile) async {
    if (!canAddImage) return;
    _sellState = SellState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.uploadBookImage(imageFile);
      result.fold(
        (failure) {
          _sellState = SellState.error;
          _errorMessage = 'Failed to upload image: ${failure.message}';
          notifyListeners();
        },
        (imageUrl) {
          _sellState = SellState.initial;
          if (canAddImage) {
            _imageUrls = List.unmodifiable([..._imageUrls, imageUrl]);
          }
          notifyListeners();
        },
      );
    } on ServerException catch (e) {
      _sellState = SellState.error;
      _errorMessage = 'Failed to upload image: ${e.message}';
      notifyListeners();
    } catch (e) {
      _sellState = SellState.error;
      _errorMessage = 'Failed to process image: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clears the error message and resets the sell state to initial.
  void clearState() {
    _errorMessage = null;
    _sellState = SellState.initial;
    notifyListeners();
  }
}
