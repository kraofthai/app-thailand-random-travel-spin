import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AdMobConfig.supportsAds) {
    await MobileAds.instance.initialize();
  }
  runApp(const ThailandRandomTravelApp());
}

class ThailandRandomTravelApp extends StatelessWidget {
  const ThailandRandomTravelApp({super.key, this.adsEnabled = true});

  final bool adsEnabled;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1769FF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TeawNaiD',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.promptTextTheme(),
        primaryTextTheme: GoogleFonts.promptTextTheme(),
        scaffoldBackgroundColor: _softSky,
      ),
      home: LandingGateway(adsEnabled: adsEnabled),
    );
  }
}

class LandingGateway extends StatefulWidget {
  const LandingGateway({super.key, required this.adsEnabled});

  final bool adsEnabled;

  @override
  State<LandingGateway> createState() => _LandingGatewayState();
}

class _LandingGatewayState extends State<LandingGateway> {
  final _placesClient = const PlacesApiClient();
  List<TravelDestination>? _loadedPlaces;
  int? _loadedTotalPlaces;
  String _status = 'กำลังโหลดข้อมูลสถานที่จาก TAT API';
  bool _ready = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThenEnter());
  }

  Future<void> _loadThenEnter() async {
    try {
      final preview = await _placesClient.fetchPreviewBatch(limit: 120);
      if (!mounted) return;
      setState(() {
        _loadedPlaces = preview.places;
        _loadedTotalPlaces = preview.total;
        _status = 'พร้อมสุ่มจากฐานข้อมูล TAT';
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedPlaces = destinations;
        _status = 'ใช้ข้อมูลสำรองในแอพ';
        _ready = true;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted || _navigated) return;
    _enterApp();
  }

  void _enterApp() {
    if (_navigated || _loadedPlaces == null) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (context) => TravelSpinPage(
              initialDestinations: _loadedPlaces,
              initialTotalPlaces: _loadedTotalPlaces,
              initialSourceLabel: _status,
              adsEnabled: widget.adsEnabled,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: max(640, constraints.maxHeight - 40),
                child: _LandingCard(status: _status, ready: _ready),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum SpinMode { all, region, province }

enum PlaceCategoryFilter { all, nature, building, food, hotelResort, other }

enum ChallengeType { realTrip, fiveProvinces, cafeHunter }

const placesApiBaseUrl = String.fromEnvironment(
  'PLACES_API_BASE_URL',
  defaultValue: '',
);

class AdMobConfig {
  const AdMobConfig._();

  static bool get supportsAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-7751163285690243/8715793106';
    }
    return 'ca-app-pub-7751163285690243/4469886339';
  }

  static String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-7751163285690243/2042573548';
    }
    return 'ca-app-pub-7751163285690243/9302205754';
  }
}

const _dailySpinLimit = 1;
const _historyLimit = 12;
const _spinPointCost = 100;
const _firebaseEnabled = bool.fromEnvironment(
  'FIREBASE_ENABLED',
  defaultValue: true,
);
const _googleWebClientId =
    '155085357502-ru2s5kp02ftsd3nmkv2r8vn730ho47l7.apps.googleusercontent.com';
const _googleIosClientId =
    '155085357502-aar6lnr88e3t54705ok3c1khhj0c1e8j.apps.googleusercontent.com';
const _shareHashtags = '#TeawNaiD #สุ่มเที่ยวทั่วไทย';
const _brandBlue = Color(0xFF1769FF);
const _brandDeepBlue = Color(0xFF153D9B);
const _brandOrange = Color(0xFFFF981B);
const _ink = Color(0xFF08245E);
const _softSky = Color(0xFFEAF8FF);
const _cardBorder = Color(0xFFDDE9F7);

class TravelDestination {
  const TravelDestination({
    required this.name,
    required this.province,
    required this.wheelLabel,
    required this.region,
    required this.vibe,
    required this.bestFor,
    required this.color,
    required this.icon,
    this.imageUrl,
    this.filterText = '',
    this.categoryFilters = const {},
    this.latitude,
    this.longitude,
  });

  final String name;
  final String province;
  final String wheelLabel;
  final String region;
  final String vibe;
  final String bestFor;
  final Color color;
  final IconData icon;
  final String? imageUrl;
  final String filterText;
  final Set<PlaceCategoryFilter> categoryFilters;
  final double? latitude;
  final double? longitude;
}

class PlacesPreview {
  const PlacesPreview({required this.places, required this.total});

  final List<TravelDestination> places;
  final int total;
}

class TravelUser {
  const TravelUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.isGuest = false,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isGuest;
}

class AuthGateway {
  AuthGateway._();

  static final instance = AuthGateway._();

  bool _initialized = false;
  bool _firebaseReady = false;
  bool _googleSignInReady = false;

  bool get firebaseReady => _firebaseReady;

  Future<TravelUser?> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    if (_firebaseEnabled) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _firebaseReady = true;
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          final user = _fromFirebaseUser(firebaseUser);
          await _syncUserDocument(user);
          _initialized = true;
          return user;
        }
      } catch (_) {
        _firebaseReady = false;
      }
    }

    _initialized = true;
    final guestUid = prefs.getString('guestUid');
    if (guestUid == null) return null;
    return TravelUser(
      uid: guestUid,
      displayName: prefs.getString('guestName') ?? 'Guest Traveler',
      photoUrl: null,
      isGuest: true,
    );
  }

  Future<TravelUser> signInWithGoogle() async {
    await _ensureInitialized();
    if (!_firebaseReady) {
      throw StateError(
        'Firebase ยังไม่พร้อมใช้งาน กรุณาตรวจสอบไฟล์ config และการเชื่อมต่อ',
      );
    }

    await _ensureGoogleSignInInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google ไม่ได้ส่ง idToken กลับมา');
    }

    final credential = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    final user = _fromFirebaseUser(credential.user!);
    await _syncUserDocument(user);
    return user;
  }

  Future<TravelUser> signInWithApple() async {
    await _ensureInitialized();
    if (!_firebaseReady) {
      throw StateError(
        'Firebase ยังไม่พร้อมใช้งาน กรุณาตรวจสอบไฟล์ config และการเชื่อมต่อ',
      );
    }

    final provider =
        OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
    final credential = await FirebaseAuth.instance.signInWithProvider(provider);
    final user = _fromFirebaseUser(credential.user!);
    await _syncUserDocument(user);
    return user;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInReady) return;

    final clientId =
        kIsWeb
            ? _googleWebClientId
            : defaultTargetPlatform == TargetPlatform.iOS
            ? _googleIosClientId
            : null;
    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: _googleWebClientId,
    );
    _googleSignInReady = true;
  }

  Future<TravelUser> signInAsGuest({String name = 'Guest Traveler'}) async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString('guestUid');
    uid ??= 'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('guestUid', uid);
    await prefs.setString('guestName', name);
    return TravelUser(uid: uid, displayName: name, isGuest: true);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guestUid');
    await prefs.remove('guestName');
    if (_firebaseReady) {
      await FirebaseAuth.instance.signOut();
      if (_googleSignInReady) {
        await GoogleSignIn.instance.signOut();
      }
    }
  }

  Future<void> syncStats({
    required TravelUser user,
    required int points,
    required int totalSpin,
    required int level,
  }) async {
    if (!_firebaseReady || user.isGuest) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      return;
    }
  }

  Future<void> addPointTransaction({
    required TravelUser user,
    required String type,
    required int points,
    required String description,
  }) async {
    if (!_firebaseReady || user.isGuest) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('awardPointTransaction')
          .call({'type': type, 'points': points, 'description': description});
    } catch (_) {
      await _addBetaPointTransaction(
        user: user,
        type: type,
        points: points,
        description: description,
      );
    }
  }

  Future<void> _addBetaPointTransaction({
    required TravelUser user,
    required String type,
    required int points,
    required String description,
  }) async {
    final allowedPoints = <String, int>{
      'daily_open': 5,
      'spin_trip': 2,
      'save_place': 3,
      'check_in': 20,
      'review_upload': 10,
      'check_in_review': 30,
      'challenge_complete': 25,
      'invite_friend': 30,
    };
    if (allowedPoints[type] != points) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final txRef = firestore.collection('point_transactions').doc();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final leaderboardRef = firestore
        .collection('leaderboard')
        .doc('${monthKey}_${user.uid}');

    await firestore.runTransaction((transaction) async {
      transaction.set(userRef, {
        'uid': user.uid,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'points': FieldValue.increment(points),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(txRef, {
        'userId': user.uid,
        'type': type,
        'points': points,
        'description': description,
        'mode': 'beta_client_transaction',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(leaderboardRef, {
        'userId': user.uid,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'points': FieldValue.increment(points),
        'month': monthKey,
        'mode': 'beta_client_transaction',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String?> uploadCheckInImage({
    required TravelUser user,
    required Uint8List bytes,
    required String placeKey,
  }) async {
    if (!_firebaseReady || user.isGuest) return null;
    final safeKey = base64Url.encode(utf8.encode(placeKey));
    final path =
        'checkins/${user.uid}/$safeKey-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  TravelUser _fromFirebaseUser(User user) {
    return TravelUser(
      uid: user.uid,
      displayName: user.displayName ?? user.email ?? 'นักเดินทาง',
      photoUrl: user.photoURL,
    );
  }

  Future<void> _syncUserDocument(TravelUser user) async {
    if (!_firebaseReady || user.isGuest) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }
}

class PlacesApiClient {
  const PlacesApiClient({this.baseUrl = placesApiBaseUrl});

  final String baseUrl;

  Future<List<TravelDestination>> fetchPlaces() async {
    return fetchPreviewPlaces(limit: 120);
  }

  Future<List<TravelDestination>> fetchPreviewPlaces({int limit = 120}) async {
    final preview = await fetchPreviewBatch(limit: limit);
    return preview.places;
  }

  Future<PlacesPreview> fetchPreviewBatch({int limit = 120}) async {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw StateError('ยังไม่ได้ตั้งค่า PLACES_API_BASE_URL');
    }

    final uri = Uri.parse(
      '$normalizedBaseUrl/places',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await http.get(uri).timeout(const Duration(seconds: 18));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Places API returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final items = _extractItems(decoded);
    final places =
        items.map(_destinationFromJson).whereType<TravelDestination>().toList();

    if (places.isEmpty) {
      throw Exception('Places API returned no usable places');
    }

    return PlacesPreview(
      total: _extractTotal(decoded) ?? places.length,
      places: places,
    );
  }

  Future<TravelDestination> fetchRandomPlace({
    PlaceCategoryFilter category = PlaceCategoryFilter.all,
    SpinMode mode = SpinMode.all,
    String? region,
    String? province,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw StateError('ยังไม่ได้ตั้งค่า PLACES_API_BASE_URL');
    }

    final query = <String, String>{};
    final categoryKey = _categoryFilterApiKey(category);
    if (categoryKey != null) query['categoryFilter'] = categoryKey;
    if (mode == SpinMode.region && region != null && region.isNotEmpty) {
      query['region'] = region;
    }
    if (mode == SpinMode.province && province != null && province.isNotEmpty) {
      query['province'] = province;
    }

    final uri = Uri.parse(
      '$normalizedBaseUrl/places/random',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri).timeout(const Duration(seconds: 18));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Random places API returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final item =
        decoded is Map<String, dynamic> && decoded['data'] != null
            ? decoded['data']
            : decoded;
    final place = _destinationFromJson(item);
    if (place == null) {
      throw Exception('Random places API returned no usable place');
    }
    return place;
  }

  String? _categoryFilterApiKey(PlaceCategoryFilter category) {
    return switch (category) {
      PlaceCategoryFilter.all => null,
      PlaceCategoryFilter.nature => 'nature',
      PlaceCategoryFilter.building => 'building',
      PlaceCategoryFilter.food => 'food',
      PlaceCategoryFilter.hotelResort => 'hotelResort',
      PlaceCategoryFilter.other => 'other',
    };
  }

  List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map<String, dynamic>) return const [];

    for (final key in ['data', 'places', 'results', 'items', 'response']) {
      final value = decoded[key];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final nested = _extractItems(value);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  int? _extractTotal(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final pagination = decoded['pagination'];
    if (pagination is Map<String, dynamic>) {
      final total = pagination['total'];
      if (total is int) return total;
      if (total is num) return total.toInt();
      if (total is String) return int.tryParse(total);
    }

    for (final key in ['total', 'count', 'totalCount']) {
      final value = decoded[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  TravelDestination? _destinationFromJson(dynamic item) {
    if (item is! Map<String, dynamic>) return null;

    final name = _firstString(item, [
      'name',
      'place_name',
      'title',
      'destination_name',
      'name_en',
      'name_th',
    ]);
    if (name == null || name.trim().isEmpty) return null;

    final province =
        _firstString(item, [
          'province',
          'province_name',
          'location_province',
          'province_en',
          'province_th',
        ]) ??
        _firstString(_map(item['location']), [
          'province',
          'province_name',
          'province_en',
          'province_th',
        ]) ??
        'Thailand';

    final region =
        _normalizeRegion(
          _firstString(item, [
            'region',
            'region_name',
            'region_en',
            'region_th',
          ]),
        ) ??
        provinceToRegion[province.trim()] ??
        'จาก API';

    final color = regionColors[region] ?? _colorFromText(name);
    final imageUrl = _firstImageUrl(item);
    final filterText = _filterText(item);
    final categoryFilters = _categoryFiltersForText(
      '$name $province $region $filterText',
    );
    final latitude =
        _firstDouble(item, ['latitude', 'lat', 'location_latitude']) ??
        _firstDouble(_map(item['location']), ['latitude', 'lat']) ??
        _firstDouble(_map(item['geo']), ['latitude', 'lat']);
    final longitude =
        _firstDouble(item, ['longitude', 'lng', 'lon', 'location_longitude']) ??
        _firstDouble(_map(item['location']), ['longitude', 'lng', 'lon']) ??
        _firstDouble(_map(item['geo']), ['longitude', 'lng', 'lon']);

    return TravelDestination(
      name: name.trim(),
      province: province.trim(),
      wheelLabel: _shortWheelLabel(province.trim()),
      region: region,
      vibe:
          _firstString(item, [
            'description',
            'introduction',
            'detail',
            'category',
            'place_type',
          ]) ??
          'สถานที่จากฐานข้อมูล TAT',
      bestFor: 'ลองสุ่มแล้วเปิดทริปใหม่จากข้อมูลจริง',
      color: color,
      icon: _iconForText(name),
      imageUrl: imageUrl,
      filterText: filterText,
      categoryFilters: categoryFilters,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Map<String, dynamic>? _map(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  String? _firstString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;

    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is Map<String, dynamic>) {
        final nested = _firstString(value, ['en', 'th', 'name', 'title']);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  double? _firstDouble(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;

    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      if (value is Map<String, dynamic>) {
        final nested = _firstDouble(value, keys);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  String _filterText(Map<String, dynamic> item) {
    final parts = <String>[jsonEncode(item)];
    return parts.join(' ').toLowerCase();
  }

  String? _firstImageUrl(Map<String, dynamic> item) {
    String? fromValue(dynamic value) {
      if (value is String && value.startsWith('http')) return value;
      if (value is List) {
        for (final entry in value) {
          final image = fromValue(entry);
          if (image != null) return image;
        }
      }
      if (value is Map<String, dynamic>) {
        for (final key in [
          'thumbnailUrl',
          'detailThumbnail',
          'imageUrl',
          'photoUrl',
          'url',
          'src',
          'detailPicture',
          'images',
          'photos',
        ]) {
          final image = fromValue(value[key]);
          if (image != null) return image;
        }
      }
      return null;
    }

    for (final key in [
      'thumbnailUrl',
      'detailThumbnail',
      'imageUrl',
      'photoUrl',
      'coverImage',
      'sha',
      'images',
      'photos',
    ]) {
      final image = fromValue(item[key]);
      if (image != null) return _proxiedImageUrl(image);
    }

    return null;
  }

  String _proxiedImageUrl(String imageUrl) {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isEmpty) return imageUrl;

    final proxy = Uri.parse(
      '$normalizedBaseUrl/api/image',
    ).replace(queryParameters: {'url': imageUrl});
    return proxy.toString();
  }

  String? _normalizeRegion(String? region) {
    if (region == null) return null;
    final value = region.trim().toLowerCase();
    if (value.contains('north') || value.contains('เหนือ')) return 'ภาคเหนือ';
    if (value.contains('north-east') ||
        value.contains('northeast') ||
        value.contains('อีสาน')) {
      return 'ภาคอีสาน';
    }
    if (value.contains('central') || value.contains('กลาง')) return 'ภาคกลาง';
    if (value.contains('east') || value.contains('ตะวันออก')) {
      return 'ภาคตะวันออก';
    }
    if (value.contains('west') || value.contains('ตะวันตก')) {
      return 'ภาคตะวันตก';
    }
    if (value.contains('south') || value.contains('ใต้')) return 'ภาคใต้';
    return region;
  }

  Color _colorFromText(String text) {
    const palette = [
      Color(0xFF4F8A5B),
      Color(0xFFD19A3E),
      Color(0xFFC77736),
      Color(0xFF278EA5),
      Color(0xFF8A6F4D),
      Color(0xFF1E9FB2),
    ];
    return palette[text.hashCode.abs() % palette.length];
  }

  IconData _iconForText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('beach') ||
        lower.contains('island') ||
        lower.contains('หาด') ||
        lower.contains('เกาะ')) {
      return Icons.beach_access_rounded;
    }
    if (lower.contains('temple') || lower.contains('วัด')) {
      return Icons.temple_buddhist_rounded;
    }
    if (lower.contains('park') || lower.contains('forest')) {
      return Icons.forest_rounded;
    }
    if (lower.contains('waterfall') || lower.contains('น้ำตก')) {
      return Icons.waterfall_chart_rounded;
    }
    return Icons.place_rounded;
  }
}

class _ChallengeSpec {
  const _ChallengeSpec({
    required this.type,
    required this.title,
    required this.description,
    required this.target,
    required this.icon,
    required this.color,
    required this.badge,
    required this.rewardPoints,
  });

  final ChallengeType type;
  final String title;
  final String description;
  final int target;
  final IconData icon;
  final Color color;
  final String badge;
  final int rewardPoints;
}

const _challengeSpecs = [
  _ChallengeSpec(
    type: ChallengeType.realTrip,
    title: 'สุ่มแล้วต้องไปจริง',
    description: 'เก็บ 1 ทริปที่สุ่มได้เป็นแผนจริง',
    target: 1,
    icon: Icons.flag_rounded,
    color: Color(0xFFF99B32),
    badge: 'นักเดินทางตัวจริง',
    rewardPoints: 30,
  ),
  _ChallengeSpec(
    type: ChallengeType.fiveProvinces,
    title: 'เที่ยว 5 จังหวัดให้ครบ',
    description: 'สุ่มให้เจอจังหวัดไม่ซ้ำ 5 จังหวัด',
    target: 5,
    icon: Icons.map_rounded,
    color: Color(0xFF0F8B8D),
    badge: 'นักล่า 5 จังหวัด',
    rewardPoints: 25,
  ),
  _ChallengeSpec(
    type: ChallengeType.cafeHunter,
    title: 'สายคาเฟ่ 3 ที่',
    description: 'สุ่มหมวดร้านอาหาร/คาเฟ่ให้ครบ 3 ครั้ง',
    target: 3,
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFE08B6B),
    badge: 'นักล่าสายคาเฟ่',
    rewardPoints: 25,
  ),
];

_ChallengeSpec _challengeSpec(ChallengeType type) {
  return _challengeSpecs.firstWhere((spec) => spec.type == type);
}

String _placeKey(TravelDestination place) {
  return '${place.name}|${place.province}';
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

const regionColors = {
  'ภาคเหนือ': Color(0xFFEF3E45),
  'ภาคอีสาน': Color(0xFF1687C2),
  'ภาคกลาง': Color(0xFF78B941),
  'ภาคตะวันออก': Color(0xFFE91E7A),
  'ภาคตะวันตก': Color(0xFF244A88),
  'ภาคใต้': Color(0xFFFF981B),
};

const regionMapAssets = {
  'ภาคเหนือ': 'assets/maps/thaimap_north.png',
  'ภาคอีสาน': 'assets/maps/thaimap_isan.png',
  'ภาคกลาง': 'assets/maps/thaimap_central.png',
  'ภาคตะวันออก': 'assets/maps/thaimap_east.png',
  'ภาคตะวันตก': 'assets/maps/thaimap_west.png',
  'ภาคใต้': 'assets/maps/thaimap_south.png',
};

const provinceToRegion = {
  'Chiang Mai': 'ภาคเหนือ',
  'Chiang Rai': 'ภาคเหนือ',
  'Mae Hong Son': 'ภาคเหนือ',
  'Phra Nakhon Si Ayutthaya': 'ภาคกลาง',
  'Ayutthaya': 'ภาคกลาง',
  'Nonthaburi': 'ภาคกลาง',
  'Samut Songkhram': 'ภาคกลาง',
  'Ubon Ratchathani': 'ภาคอีสาน',
  'Loei': 'ภาคอีสาน',
  'Buri Ram': 'ภาคอีสาน',
  'Buriram': 'ภาคอีสาน',
  'Nakhon Ratchasima': 'ภาคตะวันออก',
  'Rayong': 'ภาคตะวันออก',
  'Chon Buri': 'ภาคตะวันออก',
  'Chonburi': 'ภาคตะวันออก',
  'Surat Thani': 'ภาคใต้',
  'Phuket': 'ภาคใต้',
  'Satun': 'ภาคใต้',
  'Kanchanaburi': 'ภาคตะวันตก',
  'Prachuap Khiri Khan': 'ภาคตะวันตก',
  'Chai Nat': 'ภาคกลาง',
  'Trang': 'ภาคใต้',
  'เชียงใหม่': 'ภาคเหนือ',
  'เชียงราย': 'ภาคเหนือ',
  'แม่ฮ่องสอน': 'ภาคเหนือ',
  'ลำพูน': 'ภาคเหนือ',
  'ลำปาง': 'ภาคเหนือ',
  'แพร่': 'ภาคเหนือ',
  'น่าน': 'ภาคเหนือ',
  'พะเยา': 'ภาคเหนือ',
  'อุตรดิตถ์': 'ภาคเหนือ',
  'ตาก': 'ภาคเหนือ',
  'สุโขทัย': 'ภาคเหนือ',
  'พิษณุโลก': 'ภาคเหนือ',
  'พิจิตร': 'ภาคเหนือ',
  'กำแพงเพชร': 'ภาคเหนือ',
  'เพชรบูรณ์': 'ภาคเหนือ',
  'พระนครศรีอยุธยา': 'ภาคกลาง',
  'นนทบุรี': 'ภาคกลาง',
  'สมุทรสงคราม': 'ภาคกลาง',
  'กรุงเทพมหานคร': 'ภาคกลาง',
  'กรุงเทพฯ': 'ภาคกลาง',
  'ปทุมธานี': 'ภาคกลาง',
  'สมุทรปราการ': 'ภาคกลาง',
  'นครปฐม': 'ภาคกลาง',
  'สมุทรสาคร': 'ภาคกลาง',
  'สระบุรี': 'ภาคกลาง',
  'ลพบุรี': 'ภาคกลาง',
  'สิงห์บุรี': 'ภาคกลาง',
  'ชัยนาท': 'ภาคกลาง',
  'อ่างทอง': 'ภาคกลาง',
  'นครสวรรค์': 'ภาคกลาง',
  'อุทัยธานี': 'ภาคกลาง',
  'สุพรรณบุรี': 'ภาคกลาง',
  'อุบลราชธานี': 'ภาคอีสาน',
  'เลย': 'ภาคอีสาน',
  'บุรีรัมย์': 'ภาคอีสาน',
  'ขอนแก่น': 'ภาคอีสาน',
  'อุดรธานี': 'ภาคอีสาน',
  'หนองคาย': 'ภาคอีสาน',
  'บึงกาฬ': 'ภาคอีสาน',
  'หนองบัวลำภู': 'ภาคอีสาน',
  'สกลนคร': 'ภาคอีสาน',
  'นครพนม': 'ภาคอีสาน',
  'มุกดาหาร': 'ภาคอีสาน',
  'กาฬสินธุ์': 'ภาคอีสาน',
  'ร้อยเอ็ด': 'ภาคอีสาน',
  'มหาสารคาม': 'ภาคอีสาน',
  'ยโสธร': 'ภาคอีสาน',
  'อำนาจเจริญ': 'ภาคอีสาน',
  'ศรีสะเกษ': 'ภาคอีสาน',
  'สุรินทร์': 'ภาคอีสาน',
  'ชัยภูมิ': 'ภาคอีสาน',
  'นครราชสีมา': 'ภาคตะวันออก',
  'ระยอง': 'ภาคตะวันออก',
  'ชลบุรี': 'ภาคตะวันออก',
  'ฉะเชิงเทรา': 'ภาคตะวันออก',
  'ปราจีนบุรี': 'ภาคตะวันออก',
  'สระแก้ว': 'ภาคตะวันออก',
  'จันทบุรี': 'ภาคตะวันออก',
  'ตราด': 'ภาคตะวันออก',
  'สุราษฎร์ธานี': 'ภาคใต้',
  'ภูเก็ต': 'ภาคใต้',
  'สตูล': 'ภาคใต้',
  'ชุมพร': 'ภาคใต้',
  'ระนอง': 'ภาคใต้',
  'พังงา': 'ภาคใต้',
  'กระบี่': 'ภาคใต้',
  'นครศรีธรรมราช': 'ภาคใต้',
  'ตรัง': 'ภาคใต้',
  'พัทลุง': 'ภาคใต้',
  'สงขลา': 'ภาคใต้',
  'ปัตตานี': 'ภาคใต้',
  'ยะลา': 'ภาคใต้',
  'นราธิวาส': 'ภาคใต้',
  'กาญจนบุรี': 'ภาคตะวันตก',
  'ประจวบคีรีขันธ์': 'ภาคตะวันตก',
  'ราชบุรี': 'ภาคตะวันตก',
  'เพชรบุรี': 'ภาคตะวันตก',
};

String _shortWheelLabel(String value) {
  const aliases = {
    'Phra Nakhon Si Ayutthaya': 'Ayutthaya',
    'Nakhon Ratchasima': 'Korat',
    'Samut Songkhram': 'Samut',
    'Surat Thani': 'Surat',
    'Prachuap Khiri Khan': 'Prachuap',
    'พระนครศรีอยุธยา': 'อยุธยา',
    'นครราชสีมา': 'โคราช',
    'สมุทรสงคราม': 'สมุทรฯ',
    'สุราษฎร์ธานี': 'สุราษฎร์ฯ',
    'ประจวบคีรีขันธ์': 'ประจวบฯ',
  };

  final trimmed = value.trim();
  if (aliases.containsKey(trimmed)) return aliases[trimmed]!;
  return trimmed.length > 10 ? '${trimmed.substring(0, 9)}…' : trimmed;
}

bool _matchesCategory(TravelDestination place, PlaceCategoryFilter category) {
  if (category == PlaceCategoryFilter.all) return true;
  if (place.categoryFilters.isNotEmpty) {
    return place.categoryFilters.contains(category);
  }

  final text =
      [
        place.name,
        place.province,
        place.region,
        place.vibe,
        place.bestFor,
        place.filterText,
      ].join(' ').toLowerCase();

  return switch (category) {
    PlaceCategoryFilter.all => true,
    _ => _categoryFiltersForText(text).contains(category),
  };
}

Set<PlaceCategoryFilter> _categoryFiltersForText(String rawText) {
  final text = rawText.toLowerCase();
  final categories = <PlaceCategoryFilter>{};
  final isFood = _hasAnyKeyword(text, _foodKeywords);
  final isHotel = _hasAnyKeyword(text, _hotelKeywords);
  final isTravelBusiness = isFood || isHotel;

  if (isFood) {
    categories.add(PlaceCategoryFilter.food);
  }
  if (isHotel) {
    categories.add(PlaceCategoryFilter.hotelResort);
  }
  if (!isTravelBusiness && _hasAnyKeyword(text, _natureKeywords)) {
    categories.add(PlaceCategoryFilter.nature);
  }
  if (!isTravelBusiness && _hasAnyKeyword(text, _buildingKeywords)) {
    categories.add(PlaceCategoryFilter.building);
  }

  if (categories.isEmpty) categories.add(PlaceCategoryFilter.other);
  return categories;
}

bool _hasAnyKeyword(String text, List<String> keywords) {
  return keywords.any(text.contains);
}

const _natureKeywords = [
  'nature',
  'natural',
  'park',
  'national park',
  'forest',
  'waterfall',
  'mountain',
  'hill',
  'cave',
  'beach',
  'island',
  'sea',
  'river',
  'lake',
  'garden',
  'สวน',
  'อุทยาน',
  'ป่า',
  'วนอุทยาน',
  'น้ำตก',
  'ภูเขา',
  'ดอย',
  'ถ้ำ',
  'หาด',
  'เกาะ',
  'ทะเล',
  'แม่น้ำ',
  'เขื่อน',
];

const _buildingKeywords = [
  'temple',
  'museum',
  'palace',
  'building',
  'architecture',
  'historical',
  'monument',
  'shrine',
  'castle',
  'bridge',
  'market',
  'วัด',
  'พิพิธภัณฑ์',
  'พระราชวัง',
  'อาคาร',
  'สถาปัตยกรรม',
  'โบราณสถาน',
  'อนุสาวรีย์',
  'ศาล',
  'ปราสาท',
  'เจดีย์',
  'สะพาน',
  'ตลาด',
];

const _foodKeywords = [
  'restaurant',
  'restaurants',
  'food',
  'dining',
  'cafe',
  'café',
  'coffee',
  'bakery',
  'bar',
  'pub',
  'ร้าน',
  'สวนอาหาร',
  'ร้านอาหาร',
  'อาหาร',
  'กาแฟ',
  'คาเฟ่',
  'คาเฟ',
  'เบเกอรี่',
  'ครัว',
  'ห้องอาหาร',
  'บาร์',
  'ผับ',
];

const _hotelKeywords = [
  'resort',
  'hotel',
  'hostel',
  'homestay',
  'accommodation',
  'รีสอร์ต',
  'รีสอร์ท',
  'โรงแรม',
  'โฮเทล',
  'โฮสเทล',
  'โฮมสเตย์',
  'ที่พัก',
];

const destinations = <TravelDestination>[
  TravelDestination(
    name: 'ดอยอินทนนท์',
    province: 'เชียงใหม่',
    wheelLabel: 'เชียงใหม่',
    region: 'ภาคเหนือ',
    vibe: 'ยอดดอย อากาศเย็น เส้นทางธรรมชาติ',
    bestFor: 'เช้าวันสบาย ๆ และถ่ายรูปวิวหมอก',
    color: Color(0xFF4F8A5B),
    icon: Icons.terrain_rounded,
  ),
  TravelDestination(
    name: 'ปาย',
    province: 'แม่ฮ่องสอน',
    wheelLabel: 'แม่ฮ่องสอน',
    region: 'ภาคเหนือ',
    vibe: 'เมืองเล็ก คาเฟ่ วิวภูเขา',
    bestFor: 'ทริปช้า ๆ 2-3 วัน',
    color: Color(0xFF7D9D59),
    icon: Icons.local_cafe_rounded,
  ),
  TravelDestination(
    name: 'วัดร่องขุ่น',
    province: 'เชียงราย',
    wheelLabel: 'เชียงราย',
    region: 'ภาคเหนือ',
    vibe: 'ศิลปะร่วมสมัย แลนด์มาร์กสีขาว',
    bestFor: 'แวะเที่ยวครึ่งวันและถ่ายภาพ',
    color: Color(0xFF80A7B3),
    icon: Icons.temple_buddhist_rounded,
  ),
  TravelDestination(
    name: 'อยุธยาเมืองเก่า',
    province: 'พระนครศรีอยุธยา',
    wheelLabel: 'อยุธยา',
    region: 'ภาคกลาง',
    vibe: 'วัดโบราณ ริมแม่น้ำ ร้านอาหารท้องถิ่น',
    bestFor: 'เดย์ทริปใกล้กรุงเทพฯ',
    color: Color(0xFFC77736),
    icon: Icons.account_balance_rounded,
  ),
  TravelDestination(
    name: 'เกาะเกร็ด',
    province: 'นนทบุรี',
    wheelLabel: 'นนทบุรี',
    region: 'ภาคกลาง',
    vibe: 'ชุมชนริมน้ำ เครื่องปั้นดินเผา ของกิน',
    bestFor: 'เดินเล่นวันหยุดแบบไม่ไกลเมือง',
    color: Color(0xFFB55D3A),
    icon: Icons.directions_boat_filled_rounded,
  ),
  TravelDestination(
    name: 'ตลาดน้ำอัมพวา',
    province: 'สมุทรสงคราม',
    wheelLabel: 'สมุทรฯ',
    region: 'ภาคกลาง',
    vibe: 'ตลาดเย็น เรือ หิ่งห้อย อาหารทะเล',
    bestFor: 'ทริปเสาร์อาทิตย์กับเพื่อน',
    color: Color(0xFF2E7D78),
    icon: Icons.set_meal_rounded,
  ),
  TravelDestination(
    name: 'สามพันโบก',
    province: 'อุบลราชธานี',
    wheelLabel: 'อุบลฯ',
    region: 'ภาคอีสาน',
    vibe: 'แก่งหินริมโขง รูปทรงแปลกตา',
    bestFor: 'สายถ่ายภาพและธรรมชาติ',
    color: Color(0xFFD19A3E),
    icon: Icons.water_rounded,
  ),
  TravelDestination(
    name: 'ภูกระดึง',
    province: 'เลย',
    wheelLabel: 'เลย',
    region: 'ภาคอีสาน',
    vibe: 'เดินป่า ผาหล่มสัก พระอาทิตย์ตก',
    bestFor: 'ทริปวัดใจที่คุ้มเหนื่อย',
    color: Color(0xFF4E7A50),
    icon: Icons.hiking_rounded,
  ),
  TravelDestination(
    name: 'ปราสาทหินพนมรุ้ง',
    province: 'บุรีรัมย์',
    wheelLabel: 'บุรีรัมย์',
    region: 'ภาคอีสาน',
    vibe: 'สถาปัตยกรรมเขมรโบราณบนภูเขาไฟ',
    bestFor: 'คนชอบประวัติศาสตร์และมุมภาพสวย',
    color: Color(0xFF9C5B34),
    icon: Icons.castle_rounded,
  ),
  TravelDestination(
    name: 'เขาใหญ่',
    province: 'นครราชสีมา',
    wheelLabel: 'โคราช',
    region: 'ภาคตะวันออก',
    vibe: 'อุทยาน น้ำตก ไร่องุ่น คาเฟ่',
    bestFor: 'ขับรถเที่ยวกับครอบครัว',
    color: Color(0xFF56876D),
    icon: Icons.forest_rounded,
  ),
  TravelDestination(
    name: 'เกาะเสม็ด',
    province: 'ระยอง',
    wheelLabel: 'ระยอง',
    region: 'ภาคตะวันออก',
    vibe: 'หาดทรายขาว น้ำใส เดินทางง่าย',
    bestFor: 'พักทะเลแบบสั้น ๆ',
    color: Color(0xFF278EA5),
    icon: Icons.beach_access_rounded,
  ),
  TravelDestination(
    name: 'บางแสน',
    province: 'ชลบุรี',
    wheelLabel: 'ชลบุรี',
    region: 'ภาคตะวันออก',
    vibe: 'ทะเลใกล้กรุง คาเฟ่ ซีฟู้ด',
    bestFor: 'ทริปฉับไวแบบไปเช้าเย็นกลับ',
    color: Color(0xFF2F9C95),
    icon: Icons.waves_rounded,
  ),
  TravelDestination(
    name: 'เขื่อนเชี่ยวหลาน',
    province: 'สุราษฎร์ธานี',
    wheelLabel: 'สุราษฎร์ฯ',
    region: 'ภาคใต้',
    vibe: 'แพกลางน้ำ ภูเขาหินปูน หมอกเช้า',
    bestFor: 'พักผ่อนเงียบ ๆ ท่ามกลางธรรมชาติ',
    color: Color(0xFF237C89),
    icon: Icons.kayaking_rounded,
  ),
  TravelDestination(
    name: 'ย่านเมืองเก่าภูเก็ต',
    province: 'ภูเก็ต',
    wheelLabel: 'ภูเก็ต',
    region: 'ภาคใต้',
    vibe: 'ตึกชิโนโปรตุกีส สตรีทฟู้ด คาเฟ่',
    bestFor: 'เดินเล่น ถ่ายรูป และกินของท้องถิ่น',
    color: Color(0xFFE08B6B),
    icon: Icons.storefront_rounded,
  ),
  TravelDestination(
    name: 'เกาะหลีเป๊ะ',
    province: 'สตูล',
    wheelLabel: 'สตูล',
    region: 'ภาคใต้',
    vibe: 'ทะเลใส ดำน้ำ ปะการัง',
    bestFor: 'ทริปทะเลที่รู้สึกเหมือนได้รีเซ็ต',
    color: Color(0xFF1E9FB2),
    icon: Icons.scuba_diving_rounded,
  ),
  TravelDestination(
    name: 'สะพานมอญ',
    province: 'กาญจนบุรี',
    wheelLabel: 'กาญจนบุรี',
    region: 'ภาคตะวันตก',
    vibe: 'ชุมชนมอญ วิวทะเลสาบ หมอกเช้า',
    bestFor: 'ตื่นเช้าเดินสะพานและกินโจ๊ก',
    color: Color(0xFF8A6F4D),
    icon: Icons.brush_rounded,
  ),
  TravelDestination(
    name: 'หัวหิน',
    province: 'ประจวบคีรีขันธ์',
    wheelLabel: 'ประจวบฯ',
    region: 'ภาคตะวันตก',
    vibe: 'ทะเล ตลาดกลางคืน คาเฟ่ รีสอร์ต',
    bestFor: 'พักผ่อนแบบครบจบในเมืองเดียว',
    color: Color(0xFFB98054),
    icon: Icons.deck_rounded,
  ),
  TravelDestination(
    name: 'น้ำตกเอราวัณ',
    province: 'กาญจนบุรี',
    wheelLabel: 'กาญจนบุรี',
    region: 'ภาคตะวันตก',
    vibe: 'น้ำตกสีมรกต เดินป่าเบา ๆ',
    bestFor: 'วันธรรมชาติที่สดชื่นมาก',
    color: Color(0xFF3C9183),
    icon: Icons.waterfall_chart_rounded,
  ),
];

class TravelSpinPage extends StatefulWidget {
  const TravelSpinPage({
    super.key,
    this.initialDestinations,
    this.initialTotalPlaces,
    this.initialSourceLabel,
    this.adsEnabled = true,
  });

  final List<TravelDestination>? initialDestinations;
  final int? initialTotalPlaces;
  final String? initialSourceLabel;
  final bool adsEnabled;

  @override
  State<TravelSpinPage> createState() => _TravelSpinPageState();
}

class _TravelSpinPageState extends State<TravelSpinPage>
    with SingleTickerProviderStateMixin {
  final _placesClient = const PlacesApiClient();
  late final AnimationController _shuffleController;
  final _random = Random();

  List<TravelDestination> _destinations = destinations;
  SpinMode _mode = SpinMode.all;
  String? _selectedRegion;
  String? _selectedProvince;
  TravelDestination _selected = destinations.first;
  PlaceCategoryFilter _categoryFilter = PlaceCategoryFilter.all;
  PlaceCategoryFilter? _eligibleCacheCategory;
  List<TravelDestination>? _eligibleCache;
  int _dailySpinsLeft = _dailySpinLimit;
  int _bonusSpins = 0;
  int _streakDays = 1;
  String _lastDailyDate = '';
  bool _smartMode = false;
  bool _nearbyMode = false;
  int _nearbyRadiusKm = 50;
  Position? _currentPosition;
  bool _isLocating = false;
  String _locationLabel = 'ยังไม่ได้เปิด GPS';
  ChallengeType _activeChallenge = ChallengeType.realTrip;
  int _challengeProgress = 0;
  int _travelPoints = 0;
  int _checkInCount = 0;
  TravelUser? _travelUser;
  bool _authReady = false;
  final Set<String> _challengeProvinceKeys = {};
  final Set<String> _savedPlaceKeys = {};
  final Set<String> _badgeNames = {};
  final List<String> _historyKeys = [];
  InterstitialAd? _interstitialAd;
  int _selectedTab = 0;
  bool _showFilters = false;
  bool _isRandomizing = false;
  bool _isLoadingPlaces = true;
  String _placesSourceLabel = 'กำลังโหลดสถานที่ทั้งหมดจาก TAT API';
  int _totalPlaces = destinations.length;

  int get _availableSpins => _dailySpinsLeft + _bonusSpins;

  bool get _hasSeventhDayBonus => _streakDays > 0 && _streakDays % 7 == 0;

  List<TravelDestination> get _eligibleDestinations {
    if (_eligibleCacheCategory == _categoryFilter && _eligibleCache != null) {
      return _eligibleCache!;
    }

    final next =
        _categoryFilter == PlaceCategoryFilter.all
            ? _destinations
            : _destinations
                .where((place) => _matchesCategory(place, _categoryFilter))
                .toList();
    _eligibleCacheCategory = _categoryFilter;
    _eligibleCache = next;
    return next;
  }

  List<String> get _regions =>
      _eligibleDestinations
          .map((place) => place.region)
          .where((region) => region != 'จาก API')
          .toSet()
          .toList()
        ..sort();

  List<String> get _provinces =>
      _eligibleDestinations.map((place) => place.province).toSet().toList()
        ..sort();

  List<TravelDestination> get _pool {
    final areaPool = switch (_mode) {
      SpinMode.all => _eligibleDestinations,
      SpinMode.region =>
        _eligibleDestinations
            .where((place) => place.region == _selectedRegion)
            .toList(),
      SpinMode.province =>
        _eligibleDestinations
            .where((place) => place.province == _selectedProvince)
            .toList(),
    };

    final nearbyPool = _nearbyMode ? _nearbyFiltered(areaPool) : areaPool;
    return _smartMode ? _smartFiltered(nearbyPool) : nearbyPool;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDestinations;
    if (initial != null && initial.isNotEmpty) {
      _destinations = initial;
      _selected = initial.first;
      _isLoadingPlaces = false;
      _totalPlaces = max(
        widget.initialTotalPlaces ?? initial.length,
        initial.length,
      );
      _placesSourceLabel = widget.initialSourceLabel ?? 'โหลดข้อมูลเรียบร้อย';
    }
    _selectedRegion = _regions.first;
    _selectedProvince = _provinces.first;
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _loadGameState();
    if (_shouldUseAds) {
      _loadInterstitialAd();
    }
    unawaited(_loadAuthState());
    if (initial == null || initial.isEmpty) {
      _loadPlaces();
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _shuffleController.dispose();
    super.dispose();
  }

  bool get _shouldUseAds => widget.adsEnabled && AdMobConfig.supportsAds;

  Future<void> _loadAuthState() async {
    final user = await AuthGateway.instance.initialize();
    if (!mounted) return;
    setState(() {
      _travelUser = user;
      _authReady = true;
    });
    if (user != null) {
      await _awardDailyLoginPoints();
      await _syncAccountStats();
    }
  }

  Future<void> _randomizeTrip() async {
    if (_isRandomizing) return;

    final pool =
        _pool.isNotEmpty
            ? _pool
            : _eligibleDestinations.isNotEmpty
            ? _eligibleDestinations
            : _destinations;
    if (pool.isEmpty) return;
    if (_availableSpins <= 0) {
      _showSnack('Daily spin หมดแล้ว กดรับ spin เพิ่มได้');
      return;
    }

    setState(() {
      _isRandomizing = true;
    });
    _shuffleController.repeat();

    for (var i = 0; i < 14; i++) {
      await Future<void>.delayed(Duration(milliseconds: 42 + (i * 14)));
      if (!mounted) return;
      setState(() {
        _selected = pool[_random.nextInt(pool.length)];
      });
    }

    if (!mounted) return;
    _shuffleController.stop();
    await _shuffleController.forward(from: 0);

    final next = await _nextRandomDestination(pool);
    _ChallengeSpec? completedChallenge;
    setState(() {
      _selected = next;
      if (_dailySpinsLeft > 0) {
        _dailySpinsLeft -= 1;
      } else if (_bonusSpins > 0) {
        _bonusSpins -= 1;
      }
      completedChallenge = _recordTrip(next);
      _isRandomizing = false;
    });
    unawaited(_saveGameState());

    if (!mounted) return;
    unawaited(
      _awardPoints(
        type: 'spin_trip',
        points: 2,
        description: 'กดสุ่มทริป',
        silent: true,
      ),
    );
    final rewardChallenge = completedChallenge;
    if (rewardChallenge != null) {
      unawaited(
        _awardPoints(
          type: 'challenge_complete',
          points: rewardChallenge.rewardPoints,
          description: 'สำเร็จภารกิจ ${rewardChallenge.title}',
        ),
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => PlaceDetailPage(
              destination: next,
              isSaved: _savedPlaceKeys.contains(_placeKey(next)),
              onSave: () => _toggleSaved(next),
              onShare: () => _shareTrip(next),
            ),
      ),
    );
  }

  Future<TravelDestination> _nextRandomDestination(
    List<TravelDestination> fallbackPool,
  ) async {
    if (_nearbyMode) {
      return fallbackPool[_random.nextInt(fallbackPool.length)];
    }

    try {
      return await _placesClient.fetchRandomPlace(
        category: _effectiveRandomCategory(),
        mode: _mode,
        region: _selectedRegion,
        province: _selectedProvince,
      );
    } catch (_) {
      return fallbackPool[_random.nextInt(fallbackPool.length)];
    }
  }

  PlaceCategoryFilter _effectiveRandomCategory() {
    if (_categoryFilter != PlaceCategoryFilter.all) return _categoryFilter;
    if (!_smartMode) return PlaceCategoryFilter.all;

    final hour = DateTime.now().hour;
    return hour < 11
        ? PlaceCategoryFilter.nature
        : hour < 17
        ? PlaceCategoryFilter.food
        : PlaceCategoryFilter.building;
  }

  void _changeMode(SpinMode mode) {
    setState(() {
      _mode = mode;
      _syncSelectionWithPool();
    });
  }

  List<TravelDestination> _nearbyFiltered(List<TravelDestination> places) {
    final current = _currentPosition;
    if (current != null) {
      final withDistance =
          places
              .where(
                (place) => place.latitude != null && place.longitude != null,
              )
              .where((place) {
                final distanceKm = _distanceKm(
                  current.latitude,
                  current.longitude,
                  place.latitude!,
                  place.longitude!,
                );
                return distanceKm <= _nearbyRadiusKm;
              })
              .toList();
      if (withDistance.isNotEmpty) return withDistance;
    }

    final anchorProvince = _selectedProvince ?? _selected.province;
    final nearby =
        places.where((place) => place.province == anchorProvince).toList();
    return nearby.isEmpty ? places : nearby;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degToRad(double degree) => degree * pi / 180;

  Future<void> _setNearbyMode(bool value) async {
    if (!value) {
      setState(() {
        _nearbyMode = false;
        _syncSelectionWithPool();
      });
      return;
    }

    setState(() {
      _isLocating = true;
      _locationLabel = 'กำลังขอตำแหน่ง GPS...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location service is disabled');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _nearbyMode = true;
        _isLocating = false;
        _locationLabel =
            'GPS พร้อม • ${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
        _syncSelectionWithPool();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyMode = false;
        _isLocating = false;
        _locationLabel = 'เปิด GPS ไม่สำเร็จ ใช้จังหวัดแทน';
        _syncSelectionWithPool();
      });
      _showSnack('เปิดตำแหน่งไม่ได้ เลยยังใช้ Nearby จาก GPS ไม่ได้');
    }
  }

  List<TravelDestination> _smartFiltered(List<TravelDestination> places) {
    if (places.isEmpty || _categoryFilter != PlaceCategoryFilter.all) {
      return places;
    }

    final hour = DateTime.now().hour;
    final suggested =
        hour < 11
            ? PlaceCategoryFilter.nature
            : hour < 17
            ? PlaceCategoryFilter.food
            : PlaceCategoryFilter.building;
    final smart =
        places.where((place) => _matchesCategory(place, suggested)).toList();
    return smart.isEmpty ? places : smart;
  }

  Future<void> _loadGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString('lastDailyDate') ?? '';
    var streak = prefs.getInt('streakDays') ?? 0;
    var dailySpins = prefs.getInt('dailySpinsLeft') ?? _dailySpinLimit;
    var bonusSpins = prefs.getInt('bonusSpins') ?? 0;

    if (lastDate != today) {
      streak = lastDate.isEmpty ? 1 : streak + 1;
      dailySpins = _dailySpinLimit;
      if (streak % 7 == 0) bonusSpins += 2;
    }

    if (!mounted) return;
    setState(() {
      _lastDailyDate = today;
      _streakDays = max(1, streak);
      _dailySpinsLeft = dailySpins;
      _bonusSpins = bonusSpins;
      _activeChallenge =
          ChallengeType.values[prefs.getInt('activeChallenge') ?? 0];
      _challengeProgress = prefs.getInt('challengeProgress') ?? 0;
      _travelPoints = prefs.getInt('travelPoints') ?? 0;
      _checkInCount = prefs.getInt('checkInCount') ?? 0;
      _challengeProvinceKeys
        ..clear()
        ..addAll(prefs.getStringList('challengeProvinces') ?? const []);
      _savedPlaceKeys
        ..clear()
        ..addAll(prefs.getStringList('savedPlaces') ?? const []);
      _badgeNames
        ..clear()
        ..addAll(prefs.getStringList('badges') ?? const []);
      _historyKeys
        ..clear()
        ..addAll(prefs.getStringList('history') ?? const []);
    });
    await _saveGameState();
  }

  Future<void> _saveGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDailyDate', _lastDailyDate);
    await prefs.setInt('streakDays', _streakDays);
    await prefs.setInt('dailySpinsLeft', _dailySpinsLeft);
    await prefs.setInt('bonusSpins', _bonusSpins);
    await prefs.setInt('activeChallenge', _activeChallenge.index);
    await prefs.setInt('challengeProgress', _challengeProgress);
    await prefs.setInt('travelPoints', _travelPoints);
    await prefs.setInt('checkInCount', _checkInCount);
    await prefs.setStringList(
      'challengeProvinces',
      _challengeProvinceKeys.toList(),
    );
    await prefs.setStringList('savedPlaces', _savedPlaceKeys.toList());
    await prefs.setStringList('badges', _badgeNames.toList());
    await prefs.setStringList('history', _historyKeys);
  }

  Future<bool> _ensureLoginFor(String action) async {
    if (_travelUser != null) return true;
    await _showLoginSheet(reason: action);
    return _travelUser != null;
  }

  Future<void> _awardDailyLoginPoints() async {
    final user = _travelUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = 'dailyPointDate_${user.uid}';
    if (prefs.getString(key) == today) return;
    await prefs.setString(key, today);
    await _awardPoints(
      type: 'daily_open',
      points: 5,
      description: 'เปิดแอพรายวัน',
      silent: true,
    );
  }

  Future<void> _awardPoints({
    required String type,
    required int points,
    required String description,
    bool silent = false,
  }) async {
    final user = _travelUser;
    if (user == null) return;

    setState(() {
      _travelPoints += points;
    });
    await _saveGameState();
    unawaited(
      AuthGateway.instance.addPointTransaction(
        user: user,
        type: type,
        points: points,
        description: description,
      ),
    );
    unawaited(_syncAccountStats());
    if (!silent) _showSnack('+$points Point • $description');
  }

  Future<void> _syncAccountStats() async {
    final user = _travelUser;
    if (user == null) return;
    await AuthGateway.instance.syncStats(
      user: user,
      points: _travelPoints,
      totalSpin: _historyKeys.length,
      level: max(1, _badgeNames.length + 1),
    );
  }

  Future<void> _showLoginSheet({required String reason}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เข้าสู่ระบบเพื่อเก็บแต้ม',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _brandDeepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _LoginButton(
                  leading: const _GoogleMark(size: 22),
                  label: 'Login ด้วย Google',
                  color: Colors.white,
                  foregroundColor: _brandDeepBlue,
                  borderColor: const Color(0xFFE0E6F2),
                  onTap: () async {
                    try {
                      final user =
                          await AuthGateway.instance.signInWithGoogle();
                      if (!mounted || !context.mounted) return;
                      setState(() => _travelUser = user);
                      Navigator.of(context).pop();
                      await _awardDailyLoginPoints();
                      await _syncAccountStats();
                    } catch (error) {
                      if (!mounted) return;
                      _showSnack('Login Google ไม่สำเร็จ: $error');
                    }
                  },
                ),
                const SizedBox(height: 10),
                _LoginButton(
                  icon: Icons.apple_rounded,
                  label: 'Login ด้วย Apple',
                  color: _ink,
                  onTap: () async {
                    try {
                      final user = await AuthGateway.instance.signInWithApple();
                      if (!mounted || !context.mounted) return;
                      setState(() => _travelUser = user);
                      Navigator.of(context).pop();
                      await _awardDailyLoginPoints();
                      await _syncAccountStats();
                    } catch (error) {
                      if (!mounted) return;
                      _showSnack('Login Apple ไม่สำเร็จ: $error');
                    }
                  },
                ),
                const SizedBox(height: 10),
                _LoginButton(
                  icon: Icons.person_outline_rounded,
                  label: 'ใช้แบบ Guest ชั่วคราว',
                  color: _brandOrange,
                  onTap: () async {
                    final user = await AuthGateway.instance.signInAsGuest();
                    if (!mounted || !context.mounted) return;
                    setState(() => _travelUser = user);
                    Navigator.of(context).pop();
                    await _awardDailyLoginPoints();
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  AuthGateway.instance.firebaseReady
                      ? 'แต้มและ leaderboard จะผูกกับ Firebase account'
                      : 'ยังไม่สามารถเชื่อมบัญชีได้ ตอนนี้ใช้ข้อมูลในเครื่องชั่วคราว',
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _ChallengeSpec? _recordTrip(TravelDestination place) {
    final key = _placeKey(place);
    _historyKeys.remove(key);
    _historyKeys.insert(0, key);
    if (_historyKeys.length > _historyLimit) {
      _historyKeys.removeRange(_historyLimit, _historyKeys.length);
    }

    final spec = _challengeSpec(_activeChallenge);
    final wasCompleted = _badgeNames.contains(spec.badge);
    switch (_activeChallenge) {
      case ChallengeType.realTrip:
        break;
      case ChallengeType.fiveProvinces:
        _challengeProvinceKeys.add(place.province);
        _challengeProgress = min(spec.target, _challengeProvinceKeys.length);
      case ChallengeType.cafeHunter:
        if (_matchesCategory(place, PlaceCategoryFilter.food)) {
          _challengeProgress = min(spec.target, _challengeProgress + 1);
        }
    }

    _ChallengeSpec? completedChallenge;
    if (_challengeProgress >= spec.target) {
      _badgeNames.add(spec.badge);
      if (!wasCompleted && spec.type != ChallengeType.realTrip) {
        completedChallenge = spec;
      }
    }
    if (_historyKeys.length >= 10) _badgeNames.add('สุ่มครบ 10 ทริป');
    if (_coveredRegionsCount() >= 4) _badgeNames.add('เที่ยวครบ 4 ภาค');
    return completedChallenge;
  }

  int _coveredRegionsCount() {
    final byKey = {for (final place in _destinations) _placeKey(place): place};
    return _historyKeys
        .map((key) => byKey[key]?.region)
        .whereType<String>()
        .toSet()
        .length;
  }

  void _selectChallenge(ChallengeType type) {
    setState(() {
      _activeChallenge = type;
      _challengeProgress = 0;
      _challengeProvinceKeys.clear();
    });
    unawaited(_saveGameState());
  }

  Future<void> _watchRewardAd() async {
    final allowed = await _ensureLoginFor(
      'รับ spin เพิ่ม และผูก Spin กับบัญชีของคุณ',
    );
    if (!allowed) return;

    await _showInterstitialAd();
    if (!mounted) return;

    setState(() {
      _bonusSpins += 1;
    });
    unawaited(_saveGameState());
    unawaited(_syncAccountStats());
    _showSnack('ได้รับ spin เพิ่มแล้ว');
  }

  void _toggleSaved(TravelDestination place) {
    final key = _placeKey(place);
    var added = false;
    setState(() {
      if (_savedPlaceKeys.contains(key)) {
        _savedPlaceKeys.remove(key);
      } else {
        _savedPlaceKeys.add(key);
        added = true;
        _badgeNames.add('นักสะสมทริป');
      }
    });
    unawaited(_saveGameState());
    if (added) {
      unawaited(
        _awardPoints(
          type: 'save_place',
          points: 3,
          description: 'บันทึกสถานที่',
          silent: true,
        ),
      );
    }
    _showSnack(
      _savedPlaceKeys.contains(key) ? 'บันทึกทริปแล้ว' : 'ลบทริปออกแล้ว',
    );
  }

  void _loadInterstitialAd() {
    if (!_shouldUseAds || _interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> _showInterstitialAd() async {
    final ad = _interstitialAd;
    if (!_shouldUseAds || ad == null) return;

    _interstitialAd = null;
    final completed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completed.isCompleted) completed.complete();
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completed.isCompleted) completed.complete();
        _loadInterstitialAd();
      },
    );

    await ad.show();
    await completed.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  Future<void> _openCheckInSheet(TravelDestination place) async {
    final allowed = await _ensureLoginFor(
      'Check-in สถานที่จริง อัปโหลดรูป และรับแต้มสะสม',
    );
    if (!allowed) return;
    if (!mounted) return;

    final noteController = TextEditingController();
    XFile? pickedImage;
    Uint8List? pickedImageBytes;
    int rating = 5;
    var isCheckingLocation = false;
    var isLocationVerified = false;
    var locationMessage = 'กรุณาไปยัง ${place.name} เพื่อ Check-in และแชร์ได้';

    Future<void> verifyLocation(StateSetter setSheetState) async {
      if (place.latitude == null || place.longitude == null) {
        setSheetState(() {
          isLocationVerified = false;
          locationMessage =
              'สถานที่นี้ยังไม่มีพิกัด GPS จึงยัง Check-in ไม่ได้';
        });
        return;
      }

      setSheetState(() {
        isCheckingLocation = true;
        isLocationVerified = false;
        locationMessage = 'กำลังตรวจตำแหน่ง GPS...';
      });

      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) throw Exception('Location service is disabled');

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied');
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        final distanceKm = _distanceKm(
          position.latitude,
          position.longitude,
          place.latitude!,
          place.longitude!,
        );

        setSheetState(() {
          isCheckingLocation = false;
          isLocationVerified = distanceKm <= 1;
          locationMessage =
              isLocationVerified
                  ? 'GPS ยืนยันแล้ว อยู่ในระยะ ${distanceKm.toStringAsFixed(2)} กม.'
                  : 'คุณอยู่ห่าง ${distanceKm.toStringAsFixed(2)} กม. กรุณาไปยัง ${place.name} ภายใน 1 กม. เพื่อ Check-in';
        });
      } catch (_) {
        setSheetState(() {
          isCheckingLocation = false;
          isLocationVerified = false;
          locationMessage =
              'ตรวจ GPS ไม่สำเร็จ กรุณาเปิดตำแหน่งและไปยัง ${place.name} เพื่อ Check-in';
        });
      }
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ไปจริง Check-in',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _brandDeepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${place.name}, ${place.province} • รับ 30 Point',
                    style: TextStyle(
                      color: _ink.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'น่ามาเที่ยว',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: () => setSheetState(() => rating = i),
                          icon: Icon(
                            i <= rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFFFB12E),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'เล่าว่าไปจริงแล้วเป็นยังไง...',
                      filled: true,
                      fillColor: _softSky,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isLocationVerified
                              ? const Color(0xFFEAFBF6)
                              : const Color(0xFFFFF7E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isLocationVerified
                                ? const Color(0xFF36B653)
                                : const Color(0xFFFFB12E),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLocationVerified
                              ? Icons.gps_fixed_rounded
                              : Icons.gps_not_fixed_rounded,
                          color:
                              isLocationVerified
                                  ? const Color(0xFF36B653)
                                  : const Color(0xFFFF8F1F),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locationMessage,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          isCheckingLocation
                              ? null
                              : () => verifyLocation(setSheetState),
                      icon:
                          isCheckingLocation
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.my_location_rounded),
                      label: Text(
                        isCheckingLocation ? 'กำลังตรวจ GPS...' : 'ตรวจ GPS',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pickedImageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.memory(
                              pickedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.48),
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed:
                                    () => setSheetState(() {
                                      pickedImage = null;
                                      pickedImageBytes = null;
                                    }),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 78,
                      );
                      if (image == null) return;
                      final bytes = await image.readAsBytes();
                      setSheetState(() {
                        pickedImage = image;
                        pickedImageBytes = bytes;
                      });
                    },
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                      pickedImage == null
                          ? 'อัปโหลดรูป Check-in'
                          : 'เลือกรูปแล้ว: ${pickedImage!.name}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                          pickedImage == null || !isLocationVerified
                              ? null
                              : () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.pin_drop_rounded),
                      label: const Text('Check-in และ Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    if (submitted != true || !mounted) return;

    setState(() {
      _checkInCount += 1;
      _badgeNames.add('นักเช็คอินตัวจริง');
      if (_activeChallenge == ChallengeType.realTrip) {
        final spec = _challengeSpec(ChallengeType.realTrip);
        _challengeProgress = min(spec.target, _challengeProgress + 1);
        if (_challengeProgress >= spec.target) {
          _badgeNames.add(spec.badge);
        }
      }
    });
    unawaited(_saveGameState());
    if (pickedImageBytes != null && _travelUser != null) {
      unawaited(
        AuthGateway.instance.uploadCheckInImage(
          user: _travelUser!,
          bytes: pickedImageBytes!,
          placeKey: _placeKey(place),
        ),
      );
    }
    unawaited(
      _awardPoints(
        type: 'check_in_review',
        points: 30,
        description: 'Check-in สถานที่จริงและรีวิว',
      ),
    );
    final stars = '★' * rating;
    final note = noteController.text.trim();
    await _shareWithAppLogo(
      subject: 'TeawNaiD Check-in: ${place.name}',
      text:
          'มาเที่ยวจริงแล้ว! $stars\n${place.name}, ${place.province}\n${note.isEmpty ? 'สุ่มทริปจาก TeawNaiD แล้วได้มาที่นี่' : note}\n\n$_shareHashtags',
    );
  }

  Future<void> _openSavedTripActions(TravelDestination place) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _brandDeepBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${place.province} • Saved Trip',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(_openCheckInSheet(place));
                  },
                  icon: const Icon(Icons.pin_drop_rounded),
                  label: const Text('Check in มาเที่ยวจริง'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('ยกเลิกทริปนี้?'),
                            content: Text(
                              'ถ้ายืนยัน จะลบ ${place.name} ออกจากบันทึก',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('ไม่ยกเลิก'),
                              ),
                              FilledButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text('ยืนยันลบ'),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true && mounted) {
                      _toggleSaved(place);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('ยกเลิกทริป'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _redeemSpinWithPoints() async {
    final allowed = await _ensureLoginFor(
      'แลก Point เป็น Spin ต้อง Login เพื่อป้องกันแต้มสูญหาย',
    );
    if (!allowed) return;
    if (_travelPoints < _spinPointCost) {
      _showSnack('ต้องใช้ $_spinPointCost Point เพื่อแลก 1 spin');
      return;
    }
    setState(() {
      _travelPoints -= _spinPointCost;
      _bonusSpins += 1;
    });
    unawaited(_saveGameState());
    unawaited(_syncAccountStats());
    _showSnack('แลก +1 spin สำเร็จ');
  }

  Future<void> _shareTrip(TravelDestination place) async {
    final text =
        'AI สุ่มให้ไปนี่ 😂\n${place.name}, ${place.province}\nเปิดแอพ TeawNaiD แล้วสุ่มทริปต่อกัน!\n\n$_shareHashtags';
    await _shareWithAppLogo(text: text, subject: 'TeawNaiD: ${place.name}');
  }

  Future<void> _shareWithAppLogo({
    required String text,
    required String subject,
  }) async {
    try {
      final logoBytes =
          (await rootBundle.load(
            'assets/branding/teawnaid_logo.png',
          )).buffer.asUint8List();
      final logo = XFile.fromData(
        logoBytes,
        mimeType: 'image/png',
        name: 'TeawNaiD.png',
      );
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          title: subject,
          files: [logo],
          fileNameOverrides: const ['TeawNaiD.png'],
          previewThumbnail: logo,
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, title: subject),
      );
    }
  }

  void _openPlaceDetail(TravelDestination place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => PlaceDetailPage(
              destination: place,
              isSaved: _savedPlaceKeys.contains(_placeKey(place)),
              onSave: () => _toggleSaved(place),
              onShare: () => _shareTrip(place),
            ),
      ),
    );
  }

  List<TravelDestination> _suggestedPlaces() {
    final source = _pool.isNotEmpty ? _pool : _eligibleDestinations;
    final places =
        source
            .where((place) => _placeKey(place) != _placeKey(_selected))
            .toList();
    if (places.isEmpty) return source.take(4).toList();

    final seed = Object.hash(
      _selected.name,
      _categoryFilter.index,
      _mode.index,
      _selectedRegion,
      _selectedProvince,
    );
    places.shuffle(Random(seed));
    return places.take(6).toList();
  }

  List<TravelDestination> _nearbySuggestions() {
    final source =
        _nearbyFiltered(
          _eligibleDestinations,
        ).where((place) => _placeKey(place) != _placeKey(_selected)).toList();
    final places = source.isEmpty ? _eligibleDestinations : source;

    final current = _currentPosition;
    if (current != null) {
      places.sort((a, b) {
        final ad =
            a.latitude == null || a.longitude == null
                ? double.infinity
                : _distanceKm(
                  current.latitude,
                  current.longitude,
                  a.latitude!,
                  a.longitude!,
                );
        final bd =
            b.latitude == null || b.longitude == null
                ? double.infinity
                : _distanceKm(
                  current.latitude,
                  current.longitude,
                  b.latitude!,
                  b.longitude!,
                );
        return ad.compareTo(bd);
      });
    }

    return places.take(6).toList();
  }

  List<TravelDestination> _placesForKeys(Iterable<String> keys) {
    final byKey = {for (final place in _destinations) _placeKey(place): place};
    return keys
        .map((key) => byKey[key])
        .whereType<TravelDestination>()
        .toList();
  }

  int _historyProvinceCount() {
    final byKey = {for (final place in _destinations) _placeKey(place): place};
    return _historyKeys
        .map((key) => byKey[key]?.province)
        .whereType<String>()
        .toSet()
        .length;
  }

  // ignore: unused_element
  void _showTripListSheet(String title, Iterable<String> keys) {
    final places = _placesForKeys(keys);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F3EA),
      builder:
          (context) => _TripListSheet(
            title: title,
            places: places,
            emptyText:
                title == 'History'
                    ? 'ยังไม่มีประวัติการสุ่ม'
                    : 'ยังไม่มีทริปที่บันทึกไว้',
            onOpen: (place) {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (context) => PlaceDetailPage(
                        destination: place,
                        isSaved: _savedPlaceKeys.contains(_placeKey(place)),
                        onSave: () => _toggleSaved(place),
                        onShare: () => _shareTrip(place),
                      ),
                ),
              );
            },
          ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _currentFilterLabel() {
    final category = _categoryMeta(_categoryFilter).label;
    final area = switch (_mode) {
      SpinMode.all => 'ทั่วไทย',
      SpinMode.region => _selectedRegion ?? 'เลือกภาค',
      SpinMode.province => _selectedProvince ?? 'เลือกจังหวัด',
    };
    return '$category • $area';
  }

  void _syncSelectionWithPool() {
    final regions = _regions;
    final provinces = _provinces;
    if (regions.isNotEmpty && !regions.contains(_selectedRegion)) {
      _selectedRegion = regions.first;
    }
    if (provinces.isNotEmpty && !provinces.contains(_selectedProvince)) {
      _selectedProvince = provinces.first;
    }

    final pool = _pool;
    if (pool.isNotEmpty && !pool.contains(_selected)) {
      _selected = pool.first;
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final preview = await _placesClient.fetchPreviewBatch(limit: 120);
      if (!mounted) return;
      setState(() {
        _destinations = preview.places;
        _totalPlaces = max(preview.total, preview.places.length);
        _eligibleCacheCategory = null;
        _eligibleCache = null;
        if (_regions.isNotEmpty) _selectedRegion = _regions.first;
        if (_provinces.isNotEmpty) _selectedProvince = _provinces.first;
        _syncSelectionWithPool();
        _isLoadingPlaces = false;
        _placesSourceLabel = 'โหลดตัวอย่างแล้ว • สุ่มจากฐานข้อมูลทั้งหมด';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destinations = destinations;
        _eligibleCacheCategory = null;
        _eligibleCache = null;
        if (_regions.isNotEmpty) _selectedRegion = _regions.first;
        if (_provinces.isNotEmpty) _selectedProvince = _provinces.first;
        _syncSelectionWithPool();
        _isLoadingPlaces = false;
        _placesSourceLabel = 'ใช้ข้อมูลสำรองในแอพ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeSlivers(),
      _buildSavedSlivers(),
      _buildMissionSlivers(),
      _buildLeaderboardSlivers(),
      _buildHistorySlivers(),
      _buildProfileSlivers(),
    ];

    return Scaffold(
      bottomNavigationBar: _TeawBottomNav(
        selectedIndex: _selectedTab,
        onChanged: (index) => setState(() => _selectedTab = index),
      ),
      body: SafeArea(child: CustomScrollView(slivers: pages[_selectedTab])),
    );
  }

  List<Widget> _buildHomeSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: _RandomTopBar(
            onRewardsTap: () => setState(() => _selectedTab = 2),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _HomeMapSpinHero(
            selected: _selected,
            enabledCount: _pool.length,
            totalCount: _totalPlaces,
            remainingSpins: _availableSpins,
            progress: _shuffleController,
            isRandomizing: _isRandomizing,
            onRandomize: _randomizeTrip,
            onRewardSpin: _watchRewardAd,
            onNearby: () => _setNearbyMode(!_nearbyMode),
            onFilter: () => setState(() => _showFilters = !_showFilters),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _ModeSelector(mode: _mode, onChanged: _changeMode),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _QuickActions(
            filterLabel: _currentFilterLabel(),
            gameLabel: 'Reward • Day $_streakDays',
            showFilters: _showFilters,
            showGameHub: false,
            onToggleFilters: () => setState(() => _showFilters = !_showFilters),
            onToggleGameHub: () => setState(() => _selectedTab = 2),
          ),
        ),
      ),
      if (_showFilters) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _CategoryFilterPanel(
              selected: _categoryFilter,
              totalCount: _totalPlaces,
              selectedCount: _eligibleDestinations.length,
              onChanged: (value) {
                setState(() {
                  _categoryFilter = value;
                  _syncSelectionWithPool();
                });
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _FilterPanel(
              mode: _mode,
              regions: _regions,
              provinces: _provinces,
              selectedRegion: _selectedRegion,
              selectedProvince: _selectedProvince,
              onRegionChanged: (value) {
                setState(() {
                  _selectedRegion = value;
                  _syncSelectionWithPool();
                });
              },
              onProvinceChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _syncSelectionWithPool();
                });
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _RandomSettingsPanel(
              smartMode: _smartMode,
              nearbyMode: _nearbyMode,
              nearbyRadiusKm: _nearbyRadiusKm,
              isLocating: _isLocating,
              locationLabel: _locationLabel,
              onSmartChanged: (value) {
                setState(() {
                  _smartMode = value;
                  _syncSelectionWithPool();
                });
              },
              onNearbyChanged: _setNearbyMode,
              onRadiusChanged:
                  (value) => setState(() => _nearbyRadiusKm = value),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _HomeSuggestionSection(
            title: 'แนะนำให้ลอง',
            subtitle: 'สุ่มจากตัวเลือกในรอบนี้',
            places: _suggestedPlaces(),
            onOpen: _openPlaceDetail,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _HomeSuggestionSection(
            title: 'ที่เที่ยวใกล้ฉัน',
            subtitle:
                _nearbyMode
                    ? 'เรียงจากตำแหน่ง GPS ในระยะ $_nearbyRadiusKm กม.'
                    : 'แนะนำจากจังหวัดหรือพื้นที่ที่เลือกอยู่',
            places: _nearbySuggestions(),
            onOpen: _openPlaceDetail,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _AdMobBanner(enabled: _shouldUseAds),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _DataSourceFootnote(
            isLoading: _isLoadingPlaces,
            text: _placesSourceLabel,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }

  List<Widget> _buildSavedSlivers() {
    return _buildTripListPage(
      title: 'บันทึกที่เที่ยว',
      subtitle: 'ที่เที่ยวที่คุณเก็บไว้',
      places: _placesForKeys(_savedPlaceKeys),
      emptyText: 'ยังไม่มีทริปที่บันทึกไว้',
    );
  }

  List<Widget> _buildHistorySlivers() {
    return _buildTripListPage(
      title: 'ประวัติ',
      subtitle: 'รายการที่เคยสุ่มได้',
      places: _placesForKeys(_historyKeys),
      emptyText: 'ยังไม่มีประวัติการสุ่ม',
    );
  }

  List<Widget> _buildMissionSlivers() {
    return [
      SliverToBoxAdapter(
        child: _PageHeader(
          title: 'ภารกิจ',
          subtitle: 'ทำภารกิจเพื่อเก็บ Point, badge และ streak',
          onBack: () => setState(() => _selectedTab = 0),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _GameHubPanel(
            dailySpinsLeft: _dailySpinsLeft,
            bonusSpins: _bonusSpins,
            streakDays: _streakDays,
            hasSeventhDayBonus: _hasSeventhDayBonus,
            activeChallenge: _activeChallenge,
            challengeProgress: _challengeProgress,
            badges: _badgeNames.toList(),
            historyCount: _historyKeys.length,
            savedCount: _savedPlaceKeys.length,
            onRewardSpin: _watchRewardAd,
            onChallengeChanged: _selectChallenge,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }

  List<Widget> _buildLeaderboardSlivers() {
    return [
      SliverToBoxAdapter(
        child: _PageHeader(
          title: 'อันดับ',
          subtitle: 'แต้ม Point และรางวัลจากการไปจริง',
          onBack: () => setState(() => _selectedTab = 0),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _LeaderboardPanel(
            user: _travelUser,
            points: _travelPoints,
            checkIns: _checkInCount,
            bonusSpins: _bonusSpins,
            firebaseReady: AuthGateway.instance.firebaseReady,
            onLogin:
                () => _showLoginSheet(
                  reason: 'Leaderboard และ Point ต้องผูกกับบัญชี',
                ),
            onRedeemSpin: _redeemSpinWithPoints,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }

  List<Widget> _buildProfileSlivers() {
    return [
      SliverToBoxAdapter(
        child: _ProfileHero(
          user: _travelUser,
          authReady: _authReady,
          points: _travelPoints,
          streakDays: _streakDays,
          bonusSpins: _bonusSpins,
          historyCount: _historyKeys.length,
          savedCount: _savedPlaceKeys.length,
          badgeCount: _badgeNames.length,
          provinceCount: _historyProvinceCount(),
          onLogin:
              () => _showLoginSheet(
                reason: 'ผูกบัญชีเพื่อเก็บแต้ม Spin และประวัติข้ามเครื่อง',
              ),
          onSignOut: () async {
            await AuthGateway.instance.signOut();
            if (!mounted) return;
            setState(() => _travelUser = null);
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _ProfileMenu(
            onRewards: () => setState(() => _selectedTab = 2),
            onHistory: () => setState(() => _selectedTab = 4),
            onSaved: () => setState(() => _selectedTab = 1),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }

  List<Widget> _buildTripListPage({
    required String title,
    required String subtitle,
    required List<TravelDestination> places,
    required String emptyText,
  }) {
    return [
      SliverToBoxAdapter(
        child: _PageHeader(
          title: title,
          subtitle: subtitle,
          onBack: () => setState(() => _selectedTab = 0),
        ),
      ),
      if (places.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _EmptyStateCard(text: emptyText),
          ),
        )
      else
        SliverList.separated(
          itemCount: places.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final place = places[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TripListTile(
                place: place,
                saved: _savedPlaceKeys.contains(_placeKey(place)),
                onTap:
                    title == 'บันทึกที่เที่ยว'
                        ? () => _openSavedTripActions(place)
                        : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (context) => PlaceDetailPage(
                                  destination: place,
                                  isSaved: _savedPlaceKeys.contains(
                                    _placeKey(place),
                                  ),
                                  onSave: () => _toggleSaved(place),
                                  onShare: () => _shareTrip(place),
                                ),
                          ),
                        ),
              ),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }
}

class _TeawBottomNav extends StatelessWidget {
  const _TeawBottomNav({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'หน้าหลัก'),
      (Icons.bookmark_border_rounded, 'บันทึก'),
      (Icons.emoji_events_outlined, 'ภารกิจ'),
      (Icons.leaderboard_rounded, 'อันดับ'),
      (Icons.history_rounded, 'ประวัติ'),
      (Icons.person_rounded, 'ฉัน'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: _brandDeepBlue.withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _BottomNavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: selectedIndex == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient:
                selected
                    ? const LinearGradient(
                      colors: [Color(0xFFEAF2FF), Color(0xFFDCE8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? _brandBlue : const Color(0xFF4A4F5C),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _brandBlue : const Color(0xFF4A4F5C),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMapSpinHero extends StatelessWidget {
  const _HomeMapSpinHero({
    required this.selected,
    required this.enabledCount,
    required this.totalCount,
    required this.remainingSpins,
    required this.progress,
    required this.isRandomizing,
    required this.onRandomize,
    required this.onRewardSpin,
    required this.onNearby,
    required this.onFilter,
  });

  final TravelDestination selected;
  final int enabledCount;
  final int totalCount;
  final int remainingSpins;
  final Animation<double> progress;
  final bool isRandomizing;
  final VoidCallback onRandomize;
  final VoidCallback onRewardSpin;
  final VoidCallback onNearby;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final activeMapAsset = regionMapAssets[selected.region];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFDFF7FF), Color(0xFFFFF0C9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/illustrations/thai_travel_hero.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'สุ่ม แล้วไปเที่ยวกัน!',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: _brandDeepBlue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 420,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 0,
                          child: SizedBox(
                            width: 246,
                            height: 300,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/maps/thaimap_grey.png',
                                  fit: BoxFit.contain,
                                ),
                                if (activeMapAsset != null)
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 260),
                                    child: Image.asset(
                                      activeMapAsset,
                                      key: ValueKey(activeMapAsset),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 88,
                          child: Column(
                            children: [
                              _FloatingToolButton(
                                icon: Icons.my_location_rounded,
                                label: 'ใกล้ฉัน',
                                onTap: onNearby,
                              ),
                              const SizedBox(height: 10),
                              _FloatingToolButton(
                                icon: Icons.filter_alt_outlined,
                                label: 'ตัวกรอง',
                                onTap: onFilter,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: -10,
                          child: _BigDiceButton(
                            progress: progress,
                            isRandomizing: isRandomizing,
                            enabled: enabledCount > 0,
                            onTap: onRandomize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    enabledCount == 0
                        ? 'ไม่มีตัวเลือกในเงื่อนไขนี้'
                        : '${max(totalCount, enabledCount)} ตัวเลือกทั่วไทย • เหลือ $remainingSpins spin',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(child: _RewardSpinButton(onTap: onRewardSpin)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardSpinButton extends StatelessWidget {
  const _RewardSpinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 10,
      shadowColor: _brandBlue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: _brandOrange,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'รับ spin เพิ่ม',
                style: TextStyle(
                  color: _brandDeepBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigDiceButton extends StatelessWidget {
  const _BigDiceButton({
    required this.progress,
    required this.isRandomizing,
    required this.enabled,
    required this.onTap,
  });

  final Animation<double> progress;
  final bool isRandomizing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final pulse = isRandomizing ? sin(progress.value * pi * 2).abs() : 0.0;
        return Transform.scale(scale: 1 + pulse * 0.04, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !isRandomizing ? onTap : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.28, -0.32),
                radius: 0.9,
                colors: [Color(0xFF8DCAFF), _brandBlue, Color(0xFF1738E8)],
              ),
              border: Border.all(color: Colors.white, width: 9),
              boxShadow: [
                BoxShadow(
                  color: _brandBlue.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.70),
                  blurRadius: 0,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RotationTransition(
                    turns: progress,
                    child: const Icon(
                      Icons.casino_rounded,
                      color: _brandBlue,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRandomizing ? 'สุ่มอยู่' : 'สุ่มเลย!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingToolButton extends StatelessWidget {
  const _FloatingToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: _ink, size: 20),
              Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({
    required this.user,
    required this.points,
    required this.checkIns,
    required this.bonusSpins,
    required this.firebaseReady,
    required this.onLogin,
    required this.onRedeemSpin,
  });

  final TravelUser? user;
  final int points;
  final int checkIns;
  final int bonusSpins;
  final bool firebaseReady;
  final VoidCallback onLogin;
  final VoidCallback onRedeemSpin;

  @override
  Widget build(BuildContext context) {
    final signedIn = user != null;
    final rows = [
      (user?.displayName ?? 'คุณ', points, checkIns, true),
      ('นักเที่ยวสายเหนือ', max(60, points - 30), max(0, checkIns - 1), false),
      ('Cafe Hopper', max(20, points - 90), max(0, checkIns - 2), false),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF245BFF), Color(0xFF8A5CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Travel Point',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$points Point',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                signedIn
                    ? '$checkIns check-in • $bonusSpins bonus spin'
                    : 'Login เพื่อสะสมแต้มและขึ้นอันดับ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (signedIn && user!.isGuest) ...[
                const SizedBox(height: 8),
                Text(
                  'Guest mode: แต้มอยู่บนเครื่องนี้ ควรผูก Google/Apple ภายหลัง',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (signedIn && !user!.isGuest) ...[
                const SizedBox(height: 8),
                Text(
                  firebaseReady
                      ? 'ซิงก์ Firebase แล้ว'
                      : 'รอเชื่อม Firebase config',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: signedIn ? onRedeemSpin : onLogin,
                  icon: Icon(
                    signedIn ? Icons.casino_rounded : Icons.login_rounded,
                  ),
                  label: Text(
                    signedIn
                        ? 'แลก $_spinPointCost Point เป็น +1 spin'
                        : 'Login เพื่อเก็บ Point',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: rows[i].$4 ? const Color(0xFFEAF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    rows[i].$4
                        ? _brandBlue.withValues(alpha: 0.22)
                        : Colors.white,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: rows[i].$4 ? _brandBlue : _softSky,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: rows[i].$4 ? Colors.white : _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].$1,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${rows[i].$3} check-in',
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${rows[i].$2} pt',
                  style: const TextStyle(
                    color: _brandBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _brandDeepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripListTile extends StatelessWidget {
  const _TripListTile({
    required this.place,
    required this.saved,
    required this.onTap,
  });

  final TravelDestination place;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 64,
                  child:
                      place.imageUrl == null
                          ? _ImageFallback(selected: place)
                          : Image.network(
                            place.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => _ImageFallback(selected: place),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${place.province} • ${place.region}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _brandBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.travel_explore_rounded, color: _brandBlue, size: 42),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.authReady,
    required this.points,
    required this.streakDays,
    required this.bonusSpins,
    required this.historyCount,
    required this.savedCount,
    required this.badgeCount,
    required this.provinceCount,
    required this.onLogin,
    required this.onSignOut,
  });

  final TravelUser? user;
  final bool authReady;
  final int points;
  final int streakDays;
  final int bonusSpins;
  final int historyCount;
  final int savedCount;
  final int badgeCount;
  final int provinceCount;
  final VoidCallback onLogin;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final signedIn = user != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/illustrations/thai_travel_hero.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0.88),
              Colors.white.withValues(alpha: 0.64),
              Colors.white.withValues(alpha: 0.24),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      user?.photoUrl == null
                          ? null
                          : NetworkImage(user!.photoUrl!),
                  child:
                      user?.photoUrl == null
                          ? ClipOval(
                            child: Image.asset(
                              'assets/branding/teawnaid_logo.png',
                              fit: BoxFit.cover,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'นักเดินทาง',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _brandDeepBlue,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        signedIn
                            ? 'Lv. ${max(1, badgeCount + 1)} • $points Point • $bonusSpins spin'
                            : authReady
                            ? 'Login เพื่อเก็บแต้มและผูกบัญชี'
                            : 'กำลังตรวจบัญชี...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _brandDeepBlue.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (authReady)
                  TextButton(
                    onPressed: signedIn ? onSignOut : onLogin,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: _brandBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(signedIn ? 'ออก' : 'Login'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ProfileStat(label: 'สุ่มทั้งหมด', value: '$historyCount'),
                _ProfileStat(label: 'บันทึกไว้', value: '$savedCount'),
                _ProfileStat(label: 'จังหวัด', value: '$provinceCount'),
                _ProfileStat(label: 'Streak', value: '$streakDays'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _brandDeepBlue,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.onRewards,
    required this.onHistory,
    required this.onSaved,
  });

  final VoidCallback onRewards;
  final VoidCallback onHistory;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileMenuRow(
          icon: Icons.card_giftcard_rounded,
          label: 'รางวัลของฉัน',
          onTap: onRewards,
        ),
        _ProfileMenuRow(
          icon: Icons.bar_chart_rounded,
          label: 'สถิติการเดินทาง',
          onTap: onHistory,
        ),
        _ProfileMenuRow(
          icon: Icons.bookmark_rounded,
          label: 'ที่เที่ยวที่บันทึก',
          onTap: onSaved,
        ),
      ],
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: _brandBlue),
          title: Text(
            label,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: _ink),
        ),
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({required this.status, required this.ready});

  final String status;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 640),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/illustrations/thai_travel_hero.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.18),
                      const Color(0xFF104CA8).withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _RoundIconButton(icon: Icons.menu_rounded, onTap: () {}),
                      const Spacer(),
                      _RewardBubble(),
                    ],
                  ),
                  const SizedBox(height: 42),
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _brandBlue.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/branding/teawnaid_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.prompt(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: _brandDeepBlue,
                      ),
                      children: const [
                        TextSpan(text: 'เที่ยว'),
                        TextSpan(
                          text: 'ไหนดี',
                          style: TextStyle(color: _brandOrange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'สุ่มที่เที่ยวไทย...ไปได้ทุกที่',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TeawNaiD',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _brandDeepBlue.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _WoodSign(label: 'ภาคเหนือ'),
                      _WoodSign(label: 'ภาคอีสาน'),
                      _WoodSign(label: 'ภาคกลาง'),
                      _WoodSign(label: 'ภาคตะวันออก'),
                      _WoodSign(label: 'ภาคใต้'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        if (!ready) ...[
                          const LinearProgressIndicator(
                            minHeight: 6,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ready ? 'กำลังพาไปหน้าสุ่ม...' : 'เตรียมทริปให้คุณอยู่',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: _ink.withValues(alpha: 0.34),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: _ink)),
      ),
    );
  }
}

class _RewardBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.card_giftcard_rounded, color: _brandOrange),
    );
  }
}

class _WoodSign extends StatelessWidget {
  const _WoodSign({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFB8782E),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _RandomTopBar extends StatelessWidget {
  const _RandomTopBar({required this.onRewardsTap});

  final VoidCallback onRewardsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/branding/teawnaid_logo.png',
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.prompt(
                      color: _brandDeepBlue,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    children: const [
                      TextSpan(text: 'เที่ยว'),
                      TextSpan(
                        text: 'ไหนดี',
                        style: TextStyle(color: _brandOrange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TeawNaiD พร้อมสุ่มทริปให้คุณ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ink.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onRewardsTap,
            icon: const Icon(Icons.card_giftcard_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFF2D8),
              foregroundColor: _brandOrange,
              fixedSize: const Size(46, 46),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final SpinMode mode;
  final ValueChanged<SpinMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (SpinMode.all, Icons.public_rounded, 'ทั้งหมด'),
      (SpinMode.region, Icons.explore_rounded, 'ภาค'),
      (SpinMode.province, Icons.location_city_rounded, 'จังหวัด'),
    ];

    return Container(
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink.withValues(alpha: 0.38), width: 1.4),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _ModeTabButton(
                  icon: item.$2,
                  label: item.$3,
                  selected: mode == item.$1,
                  onTap: () => onChanged(item.$1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _brandBlue.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _ink, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SpinStatusBar extends StatelessWidget {
  const _SpinStatusBar({
    required this.dailySpinsLeft,
    required this.bonusSpins,
    required this.streakDays,
    required this.historyCount,
    required this.savedCount,
    required this.onHistoryTap,
    required this.onSavedTap,
  });

  final int dailySpinsLeft;
  final int bonusSpins;
  final int streakDays;
  final int historyCount;
  final int savedCount;
  final VoidCallback onHistoryTap;
  final VoidCallback onSavedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactStat(
              icon: Icons.casino_rounded,
              label: '${dailySpinsLeft + bonusSpins}',
              color: _brandBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactStat(
              icon: Icons.local_fire_department_rounded,
              label: '$streakDays',
              color: _brandOrange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactStat(
              icon: Icons.history_rounded,
              label: '$historyCount',
              color: const Color(0xFF6D5BD0),
              onTap: onHistoryTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactStat(
              icon: Icons.favorite_rounded,
              label: '$savedCount',
              color: const Color(0xFFFF3B74),
              onTap: onSavedTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripListSheet extends StatelessWidget {
  const _TripListSheet({
    required this.title,
    required this.places,
    required this.emptyText,
    required this.onOpen,
  });

  final String title;
  final List<TravelDestination> places;
  final String emptyText;
  final ValueChanged<TravelDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (places.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(emptyText),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return ListTile(
                      onTap: () => onOpen(place),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(place.icon, color: place.color),
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text('${place.province} • ${place.region}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.58)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSuggestionSection extends StatelessWidget {
  const _HomeSuggestionSection({
    required this.title,
    required this.subtitle,
    required this.places,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final List<TravelDestination> places;
  final ValueChanged<TravelDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _brandBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: _brandDeepBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.54),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final place = places[index];
                return _HomePlaceCard(place: place, onTap: () => onOpen(place));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePlaceCard extends StatelessWidget {
  const _HomePlaceCard({required this.place, required this.onTap});

  final TravelDestination place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _categoryMeta(
      place.categoryFilters.isEmpty
          ? PlaceCategoryFilter.other
          : place.categoryFilters.first,
    );

    return SizedBox(
      width: 178,
      child: Material(
        color: const Color(0xFFF9FCFF),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(21),
                  ),
                  child: SizedBox(
                    height: 92,
                    width: double.infinity,
                    child:
                        place.imageUrl == null
                            ? _CompactImageFallback(place: place)
                            : Image.network(
                              place.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      _CompactImageFallback(place: place),
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            color: _brandOrange,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.province,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ink.withValues(alpha: 0.56),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(meta.icon, color: meta.color, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                meta.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: meta.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactImageFallback extends StatelessWidget {
  const _CompactImageFallback({required this.place});

  final TravelDestination place;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/thai_travel_hero.png',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                place.color.withValues(alpha: 0.36),
                _brandDeepBlue.withValues(alpha: 0.16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(place.icon, color: place.color, size: 26),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.filterLabel,
    required this.gameLabel,
    required this.showFilters,
    required this.showGameHub,
    required this.onToggleFilters,
    required this.onToggleGameHub,
  });

  final String filterLabel;
  final String gameLabel;
  final bool showFilters;
  final bool showGameHub;
  final VoidCallback onToggleFilters;
  final VoidCallback onToggleGameHub;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ActionChipButton(
          icon: Icons.tune_rounded,
          label: filterLabel,
          active: showFilters,
          onTap: onToggleFilters,
        ),
        _ActionChipButton(
          icon: Icons.emoji_events_rounded,
          label: gameLabel,
          active: showGameHub,
          onTap: onToggleGameHub,
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _brandBlue : Colors.white;
    final foreground = active ? Colors.white : _ink;

    return Material(
      color: color,
      elevation: active ? 8 : 0,
      shadowColor: _brandBlue.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? _brandBlue : _cardBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.leading,
    this.foregroundColor = Colors.white,
    this.borderColor,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color color;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: leading ?? Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: borderColor ?? color, width: 1.4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.08, 1.45, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.22, 1.32, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.48, 1.12, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.48, 1.22, false, paint);

    final barPaint =
        Paint()
          ..color = const Color(0xFF4285F4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.square;
    final center = Offset(size.width * 0.53, size.height * 0.52);
    canvas.drawLine(
      center,
      Offset(size.width * 0.86, size.height * 0.52),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GameHubPanel extends StatelessWidget {
  const _GameHubPanel({
    required this.dailySpinsLeft,
    required this.bonusSpins,
    required this.streakDays,
    required this.hasSeventhDayBonus,
    required this.activeChallenge,
    required this.challengeProgress,
    required this.badges,
    required this.historyCount,
    required this.savedCount,
    required this.onRewardSpin,
    required this.onChallengeChanged,
  });

  final int dailySpinsLeft;
  final int bonusSpins;
  final int streakDays;
  final bool hasSeventhDayBonus;
  final ChallengeType activeChallenge;
  final int challengeProgress;
  final List<String> badges;
  final int historyCount;
  final int savedCount;
  final VoidCallback onRewardSpin;
  final ValueChanged<ChallengeType> onChallengeChanged;

  @override
  Widget build(BuildContext context) {
    final challenge = _challengeSpec(activeChallenge);
    final progress = challengeProgress / challenge.target;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MetricTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: 'Day $streakDays',
                color: const Color(0xFFF99B32),
              ),
              const SizedBox(width: 8),
              _MetricTile(
                icon: Icons.casino_rounded,
                label: 'Spin',
                value: '${dailySpinsLeft + bonusSpins}',
                color: const Color(0xFF0F8B8D),
              ),
            ],
          ),
          if (hasSeventhDayBonus) ...[
            const SizedBox(height: 10),
            const _QuietInfo(
              icon: Icons.card_giftcard_rounded,
              text: 'โบนัส Day 7: ได้ +2 spin แล้ว',
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRewardSpin,
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('รับ spin เพิ่ม'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Challenge Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _brandDeepBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _RewardPill(points: challenge.rewardPoints),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            activeChallenge == ChallengeType.realTrip
                ? 'ภารกิจนี้รับ Point ตอน Check-in พร้อมรูปและรีวิว'
                : 'สำเร็จครั้งแรกจะรับ Point อัตโนมัติ',
            style: TextStyle(
              color: _ink.withValues(alpha: 0.56),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          for (final spec in _challengeSpecs) ...[
            _ChallengeMissionCard(
              spec: spec,
              selected: spec.type == activeChallenge,
              progress:
                  spec.type == activeChallenge
                      ? challengeProgress / spec.target
                      : 0,
              progressLabel:
                  spec.type == activeChallenge
                      ? '$challengeProgress/${spec.target}'
                      : 'เลือกเพื่อเริ่ม',
              completed: badges.contains(spec.badge),
              onTap: () => onChallengeChanged(spec.type),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: challenge.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: challenge.color.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(challenge.icon, color: challenge.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        challenge.title,
                        style: const TextStyle(
                          color: _brandDeepBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$challengeProgress/${challenge.target}',
                      style: TextStyle(
                        color: challenge.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 9,
                    backgroundColor: Colors.white,
                    color: challenge.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.description,
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftStat(
                icon: Icons.history_rounded,
                label: '$historyCount history',
              ),
              _SoftStat(
                icon: Icons.favorite_rounded,
                label: '$savedCount saved',
              ),
              for (final badge in badges.take(3))
                _SoftStat(icon: Icons.workspace_premium_rounded, label: badge),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeMissionCard extends StatelessWidget {
  const _ChallengeMissionCard({
    required this.spec,
    required this.selected,
    required this.progress,
    required this.progressLabel,
    required this.completed,
    required this.onTap,
  });

  final _ChallengeSpec spec;
  final bool selected;
  final double progress;
  final String progressLabel;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? spec.color.withValues(alpha: 0.12) : const Color(0xFFF8FAFF);
    final border = selected ? spec.color.withValues(alpha: 0.62) : _cardBorder;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? spec.color : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  completed ? Icons.check_rounded : spec.icon,
                  color: selected ? Colors.white : spec.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _brandDeepBlue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _RewardPill(points: spec.rewardPoints, compact: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      completed
                          ? 'สำเร็จแล้ว • ${spec.badge}'
                          : spec.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0, 1),
                                minHeight: 6,
                                backgroundColor: Colors.white,
                                color: spec.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progressLabel,
                            style: TextStyle(
                              color: spec.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.points, this.compact = false});

  final int points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFC36B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            size: compact ? 14 : 16,
            color: _brandOrange,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            '+$points Point',
            style: TextStyle(
              color: _brandDeepBlue,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RandomSettingsPanel extends StatelessWidget {
  const _RandomSettingsPanel({
    required this.smartMode,
    required this.nearbyMode,
    required this.nearbyRadiusKm,
    required this.isLocating,
    required this.locationLabel,
    required this.onSmartChanged,
    required this.onNearbyChanged,
    required this.onRadiusChanged,
  });

  final bool smartMode;
  final bool nearbyMode;
  final int nearbyRadiusKm;
  final bool isLocating;
  final String locationLabel;
  final ValueChanged<bool> onSmartChanged;
  final ValueChanged<bool> onNearbyChanged;
  final ValueChanged<int> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsSectionTitle(
            title: 'Random Settings',
            subtitle: 'ปรับวิธีสุ่มหลังเลือกหมวดและพื้นที่',
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: smartMode,
            onChanged: onSmartChanged,
            title: const Text('Smart Random'),
            subtitle: const Text('เลือกแนวตามเวลา'),
            secondary: const Icon(Icons.psychology_rounded),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: nearbyMode,
            onChanged: isLocating ? null : onNearbyChanged,
            title: const Text('Nearby Mode'),
            subtitle: Text(
              isLocating
                  ? 'กำลังเปิด GPS...'
                  : 'สุ่มใกล้เคียง $nearbyRadiusKm km',
            ),
            secondary: const Icon(Icons.near_me_rounded),
            contentPadding: EdgeInsets.zero,
          ),
          _QuietInfo(
            icon: nearbyMode ? Icons.gps_fixed_rounded : Icons.gps_not_fixed,
            text: locationLabel,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final radius in const [10, 50])
                ChoiceChip(
                  label: Text('$radius km'),
                  selected: nearbyRadiusKm == radius,
                  onSelected: (_) => onRadiusChanged(radius),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftStat extends StatelessWidget {
  const _SoftStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF0F8B8D)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CategoryFilterPanel extends StatelessWidget {
  const _CategoryFilterPanel({
    required this.selected,
    required this.totalCount,
    required this.selectedCount,
    required this.onChanged,
  });

  final PlaceCategoryFilter selected;
  final int totalCount;
  final int selectedCount;
  final ValueChanged<PlaceCategoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeMeta = _categoryMeta(selected);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4DED1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: activeMeta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(activeMeta.icon, color: activeMeta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เลือกแนวที่อยากสุ่ม',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      selected == PlaceCategoryFilter.all
                          ? 'พร้อมสุ่มจาก $totalCount สถานที่'
                          : '${activeMeta.label} มี $selectedCount ตัวเลือก',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final category in PlaceCategoryFilter.values)
                _CategoryChip(
                  meta: _categoryMeta(category),
                  selected: selected == category,
                  onTap: () => onChanged(category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final _CategoryMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _ink;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 94,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? meta.color : meta.color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? Colors.white.withValues(alpha: 0.0)
                      : meta.color.withValues(alpha: 0.18),
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: meta.color.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.white24 : meta.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                meta.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryMeta {
  const _CategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_CategoryMeta _categoryMeta(PlaceCategoryFilter category) {
  return switch (category) {
    PlaceCategoryFilter.all => const _CategoryMeta(
      label: 'ทั้งหมด',
      icon: Icons.grid_view_rounded,
      color: _brandBlue,
    ),
    PlaceCategoryFilter.nature => const _CategoryMeta(
      label: 'ธรรมชาติ',
      icon: Icons.forest_rounded,
      color: Color(0xFF36B653),
    ),
    PlaceCategoryFilter.building => const _CategoryMeta(
      label: 'อาคาร',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFFFB12E),
    ),
    PlaceCategoryFilter.food => const _CategoryMeta(
      label: 'ร้านอาหาร',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF6F31),
    ),
    PlaceCategoryFilter.hotelResort => const _CategoryMeta(
      label: 'โรงแรมและรีสอร์ต',
      icon: Icons.hotel_rounded,
      color: Color(0xFF8F5CFF),
    ),
    PlaceCategoryFilter.other => const _CategoryMeta(
      label: 'อื่นๆ',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF18BFC8),
    ),
  };
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.mode,
    required this.regions,
    required this.provinces,
    required this.selectedRegion,
    required this.selectedProvince,
    required this.onRegionChanged,
    required this.onProvinceChanged,
  });

  final SpinMode mode;
  final List<String> regions;
  final List<String> provinces;
  final String? selectedRegion;
  final String? selectedProvince;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onProvinceChanged;

  @override
  Widget build(BuildContext context) {
    if (mode == SpinMode.all) {
      return const _QuietInfo(
        icon: Icons.auto_awesome_rounded,
        text: 'กำลังสุ่มจากสถานที่ทั้งหมดในแอพ',
      );
    }

    final items = mode == SpinMode.region ? regions : provinces;
    final value = mode == SpinMode.region ? selectedRegion : selectedProvince;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4DED1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              mode == SpinMode.region
                  ? onRegionChanged(value)
                  : onProvinceChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _QuietInfo extends StatelessWidget {
  const _QuietInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4DED1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F8B8D)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DataSourceFootnote extends StatelessWidget {
  const _DataSourceFootnote({required this.isLoading, required this.text});

  final bool isLoading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isLoading ? Icons.sync_rounded : Icons.cloud_done_rounded,
          size: 14,
          color: Colors.black.withValues(alpha: 0.38),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.46),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({required this.enabled});

  final bool enabled;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void didUpdateWidget(covariant _AdMobBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (!widget.enabled || !AdMobConfig.supportsAds) return;

    final banner = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    if (!widget.enabled || banner == null || !_isLoaded) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cardBorder),
        ),
        child: AdWidget(ad: banner),
      ),
    );
  }
}

// ignore: unused_element
class _RandomTripPanel extends StatelessWidget {
  const _RandomTripPanel({
    required this.selected,
    required this.enabledCount,
    required this.remainingSpins,
    required this.progress,
    required this.onRandomize,
    required this.isRandomizing,
  });

  final TravelDestination selected;
  final int enabledCount;
  final int remainingSpins;
  final Animation<double> progress;
  final VoidCallback onRandomize;
  final bool isRandomizing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final wave = sin(progress.value * pi * 2);
        final lift =
            isRandomizing ? wave.abs() * 8 : sin(progress.value * pi) * 12;
        final scale =
            isRandomizing
                ? 1 + (wave.abs() * 0.012)
                : 1 + (sin(progress.value * pi) * 0.018);

        return Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: _brandBlue.withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _RandomStage(
                selected: selected,
                isRandomizing: isRandomizing,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.travel_explore_rounded,
                    color: selected.color,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRandomizing
                        ? 'กำลังเลือกที่เที่ยวให้...'
                        : 'พร้อมไปที่ใหม่!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRandomizing
                        ? 'ผลลัพธ์จะแสดงในหน้ารายละเอียดหลังสุ่มเสร็จ'
                        : 'กดปุ่มด้านล่าง แล้วระบบจะพาไปหน้ารายละเอียดทันที',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.58),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: progress,
                      builder: (context, child) {
                        final pulse =
                            isRandomizing ? sin(progress.value * pi * 2) : 0.0;
                        return Transform.scale(
                          scale: 1 + pulse.abs() * 0.06,
                          child: child,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _brandBlue.withValues(alpha: 0.08),
                              _brandBlue.withValues(alpha: 0.30),
                              _brandDeepBlue.withValues(alpha: 0.50),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          isRandomizing || enabledCount == 0
                              ? null
                              : onRandomize,
                      style: FilledButton.styleFrom(
                        fixedSize: const Size(138, 138),
                        shape: const CircleBorder(),
                        backgroundColor: _brandBlue,
                        disabledBackgroundColor: _brandBlue.withValues(
                          alpha: 0.34,
                        ),
                        elevation: 14,
                        shadowColor: _brandBlue.withValues(alpha: 0.45),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotationTransition(
                            turns: progress,
                            child: Icon(
                              isRandomizing
                                  ? Icons.autorenew_rounded
                                  : Icons.casino_rounded,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRandomizing ? 'กำลังสุ่ม' : 'สุ่มเลย!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: isRandomizing ? 8 : 0,
              margin: EdgeInsets.only(top: isRandomizing ? 12 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  backgroundColor: const Color(0xFFE4DED1),
                  color: selected.color,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                isRandomizing
                    ? 'กำลังเลือกทริปที่ใช่จาก $enabledCount ตัวเลือก'
                    : enabledCount == 0
                    ? 'ยังไม่มีตัวเลือกในเงื่อนไขนี้ ลองเปลี่ยนหมวดหรือพื้นที่'
                    : 'มี $enabledCount ตัวเลือกในรอบนี้ • เหลือ $remainingSpins spin',
                key: ValueKey(isRandomizing),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.56)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuffleOverlay extends StatelessWidget {
  const _ShuffleOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.2, 0.5, 0.8],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _RandomStage extends StatelessWidget {
  const _RandomStage({required this.selected, required this.isRandomizing});

  final TravelDestination selected;
  final bool isRandomizing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _StagePlaceholder(selected: selected),
          if (selected.imageUrl != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Image.network(
                selected.imageUrl!,
                key: ValueKey(selected.imageUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return _StagePlaceholder(selected: selected);
                },
                errorBuilder:
                    (context, error, stackTrace) =>
                        _StagePlaceholder(selected: selected),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  selected.color.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.24),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _StageBadge(
              icon: Icons.place_rounded,
              label: selected.province,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                isRandomizing ? 'กำลังสุ่ม...' : selected.name,
                key: ValueKey('${selected.name}-$isRandomizing'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isRandomizing) const _ShuffleOverlay(),
        ],
      ),
    );
  }
}

class _StagePlaceholder extends StatelessWidget {
  const _StagePlaceholder({required this.selected});

  final TravelDestination selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/thai_travel_hero.png',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                selected.color.withValues(alpha: 0.20),
                _brandDeepBlue.withValues(alpha: 0.22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: selected.color.withValues(alpha: 0.18)),
            ),
            child: Icon(selected.icon, color: selected.color, size: 44),
          ),
        ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MapAndResult extends StatelessWidget {
  const _MapAndResult({required this.selected});

  final TravelDestination selected;

  @override
  Widget build(BuildContext context) {
    final activeMapAsset = regionMapAssets[selected.region];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_rounded, color: _brandBlue),
                  const SizedBox(width: 8),
                  Text(
                    'แผนที่ไทยย่อ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 430,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDDF6FF), Color(0xFFFFF5D6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 292,
                    height: 410,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: selected.color.withValues(alpha: 0.18),
                                  blurRadius: 48,
                                  spreadRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Image.asset(
                            'assets/maps/thaimap_grey.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (activeMapAsset != null)
                          Positioned.fill(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: Image.asset(
                                activeMapAsset,
                                key: ValueKey(activeMapAsset),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MapSummaryCard(selected: selected),
      ],
    );
  }
}

class _MapSummaryCard extends StatelessWidget {
  const _MapSummaryCard({required this.selected});

  final TravelDestination selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.explore_rounded, color: selected.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พิกัดที่สุ่มได้',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${selected.province} · ${selected.region}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(
            icon: Icons.map_rounded,
            text: 'แผนที่กำลังไฮไลต์ ${selected.region} ตามสถานที่ที่สุ่มได้',
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.selected});

  final TravelDestination selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/thai_travel_hero.png',
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                selected.color.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.22),
                _brandDeepBlue.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_rounded, size: 16, color: _ink),
                SizedBox(width: 6),
                Text(
                  'ภาพประกอบ',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: selected.color.withValues(alpha: 0.18)),
            ),
            child: Icon(selected.icon, color: selected.color, size: 44),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'ยังไม่มีรูปจริงจากแหล่งข้อมูล',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({
    super.key,
    required this.destination,
    required this.isSaved,
    required this.onSave,
    required this.onShare,
  });

  final TravelDestination destination;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  late bool _isSaved;

  TravelDestination get destination => widget.destination;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  void _toggleSaved() {
    setState(() {
      _isSaved = !_isSaved;
    });
    widget.onSave();
  }

  Future<void> _openMap() async {
    final query =
        destination.latitude != null && destination.longitude != null
            ? '${destination.latitude},${destination.longitude}'
            : '${destination.name} ${destination.province} Thailand';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(uri)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิด Google Maps ไม่สำเร็จ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _detailStyle(destination);
    final rarity = _dropTier(destination);

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBF6),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PlaceDetailHero(
              destination: destination,
              style: style,
              rarity: rarity,
              isSaved: _isSaved,
              onSave: _toggleSaved,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverList.list(
              children: [
                _DetailSection(
                  title: 'ทำไมที่นี่น่าไป',
                  body: _whyThisPlace(destination),
                  children: [
                    _DetailChip(
                      icon: destination.icon,
                      label: style,
                      color: destination.color,
                    ),
                    _DetailChip(
                      icon: Icons.schedule_rounded,
                      label: 'เหมาะกับทริปยืดหยุ่น',
                      color: destination.color,
                    ),
                    _DetailChip(
                      icon: Icons.auto_awesome_rounded,
                      label: rarity,
                      color: destination.color,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'ข้อมูลสถานที่',
                  body: destination.vibe,
                  children: [
                    _FactTile(
                      icon: Icons.place_rounded,
                      label: 'จังหวัด',
                      value: destination.province,
                      color: destination.color,
                    ),
                    _FactTile(
                      icon: Icons.map_rounded,
                      label: 'ภาค',
                      value: destination.region,
                      color: destination.color,
                    ),
                    _FactTile(
                      icon: destination.icon,
                      label: 'สไตล์',
                      value: style,
                      color: destination.color,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Next move',
                  body:
                      'บันทึกไว้เป็นทริป แล้วไปจัดการ Check-in ต่อใน Tab บันทึก',
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _openMap,
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Open Map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1769FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _toggleSaved,
                        icon: Icon(
                          _isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        label: Text(_isSaved ? 'Saved Place' : 'Save Trip'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              _isSaved ? const Color(0xFFEAFBF6) : Colors.white,
                          foregroundColor:
                              _isSaved
                                  ? const Color(0xFF0F8B8D)
                                  : const Color(0xFF1769FF),
                          side: BorderSide(
                            color:
                                _isSaved
                                    ? const Color(0xFF0F8B8D)
                                    : const Color(0xFF1769FF),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: widget.onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share Place'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Back to Spinner'),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceDetailHero extends StatelessWidget {
  const _PlaceDetailHero({
    required this.destination,
    required this.style,
    required this.rarity,
    required this.isSaved,
    required this.onSave,
  });

  final TravelDestination destination;
  final String style;
  final String rarity;
  final bool isSaved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final heroHeight = max(620.0, MediaQuery.sizeOf(context).height * 0.72);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (destination.imageUrl != null)
            Image.network(
              destination.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) =>
                      _ImageFallback(selected: destination),
            )
          else
            _ImageFallback(selected: destination),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF54C7F7).withValues(alpha: 0.72),
                  destination.color.withValues(alpha: 0.46),
                  const Color(0xFF0B3D66).withValues(alpha: 0.84),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: onSave,
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: const Color(0xFF1769FF),
                          fixedSize: const Size(52, 52),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      'ไปที่นี่กัน!',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child:
                                destination.imageUrl != null
                                    ? Image.network(
                                      destination.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _ImageFallback(
                                                selected: destination,
                                              ),
                                    )
                                    : _ImageFallback(selected: destination),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Pill(
                        icon: Icons.place_rounded,
                        label: destination.province,
                      ),
                      _Pill(icon: destination.icon, label: style),
                      _Pill(icon: Icons.auto_awesome_rounded, label: rarity),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    destination.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    destination.vibe,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: const Color(0xFF245D59),
        fixedSize: const Size(56, 56),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.body,
    required this.children,
  });

  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F8B8D).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF123D39),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF5F7874),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: children),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF456B67),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF78918D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF123D39),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _detailStyle(TravelDestination destination) {
  final text =
      '${destination.name} ${destination.vibe} ${destination.filterText}'
          .toLowerCase();
  if (text.contains('temple') || text.contains('วัด')) return 'Culture';
  if (text.contains('beach') ||
      text.contains('island') ||
      text.contains('หาด') ||
      text.contains('เกาะ')) {
    return 'Beach';
  }
  if (text.contains('park') ||
      text.contains('forest') ||
      text.contains('waterfall') ||
      text.contains('อุทยาน') ||
      text.contains('น้ำตก')) {
    return 'Nature';
  }
  if (text.contains('market') || text.contains('ตลาด')) return 'Local';
  return 'Explore';
}

String _dropTier(TravelDestination destination) {
  final bucket = destination.name.hashCode.abs() % 3;
  return switch (bucket) {
    0 => 'COMMON',
    1 => 'RARE',
    _ => 'POPULAR',
  };
}

String _whyThisPlace(TravelDestination destination) {
  final style = _detailStyle(destination);
  return switch (style) {
    'Culture' =>
      'เหมาะถ้าอยากได้ทริปที่มีเรื่องราว วัฒนธรรม และบรรยากาศท้องถิ่นชัดเจน',
    'Beach' =>
      'เหมาะถ้าอยากพักสายตากับทะเล เดินเล่นสบาย ๆ และปล่อยให้ทริปเบาลง',
    'Nature' =>
      'เหมาะถ้าอยากได้พื้นที่สีเขียว อากาศโปร่ง และจังหวะเที่ยวที่ช้าขึ้น',
    'Local' =>
      'เหมาะถ้าอยากสัมผัสชีวิตท้องถิ่น เดินดูของ กินง่าย และเก็บบรรยากาศเมือง',
    _ => 'เป็นตัวเลือกที่ยืดหยุ่น ใช้วางเป็นจุดเริ่มต้นของทริปใหม่ได้ง่าย',
  };
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F8B8D)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    );
  }
}
