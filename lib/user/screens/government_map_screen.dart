import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mezaan/shared/localization/localization_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class GovernmentMapScreen extends StatefulWidget {
  const GovernmentMapScreen({super.key});

  @override
  State<GovernmentMapScreen> createState() => _GovernmentMapScreenState();
}

class _GovernmentMapScreenState extends State<GovernmentMapScreen> {
  static const List<String> _overpassEndpoints = <String>[
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  static const List<String> _userRegisteredAreaAliases = <String>[
    'الدقي',
    'dokki',
    'duqqi',
  ];

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Distance _distance = const Distance();

  final List<_GovernmentPlace> _places = <_GovernmentPlace>[];
  final int _tileRevision = DateTime.now().millisecondsSinceEpoch;

  LatLng _userLocation = const LatLng(30.0444, 31.2357);
  bool _isLoading = false;
  bool _mapReady = false;
  bool _showListView = false;
  String _searchQuery = '';
  String? _errorMessage;
  LatLngBounds? _lastSearchedBounds;
  _GovernmentPlaceType? _selectedTypeFilter;
  _PlaceSort _sortMode = _PlaceSort.nearest;
  String? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPlacesForCurrentLocation();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isArabic =>
      LocalizationController.instance.currentLanguage.value == 'ar';

  String _txt({required String en, required String ar}) {
    return _isArabic ? ar : en;
  }

  List<_GovernmentPlace> get _visiblePlaces {
    Iterable<_GovernmentPlace> items = _places;

    if (_selectedTypeFilter != null) {
      items = items.where((p) => p.type == _selectedTypeFilter);
    }

    final String q = _normalizeSearchText(_searchQuery);
    if (q.isNotEmpty) {
      items = items.where((p) => _matchesSearchQuery(p, q));
    }

    final List<_GovernmentPlace> sorted = items.toList();

    switch (_sortMode) {
      case _PlaceSort.nearest:
        sorted.sort(
          (a, b) =>
              _distanceKmTo(a.position).compareTo(_distanceKmTo(b.position)),
        );
        break;
      case _PlaceSort.name:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    return sorted;
  }

  List<_GovernmentPlace> get _searchSuggestions {
    final String q = _normalizeSearchText(_searchQuery);
    if (q.isEmpty) return <_GovernmentPlace>[];

    Iterable<_GovernmentPlace> items = _places;
    if (_selectedTypeFilter != null) {
      items = items.where((p) => p.type == _selectedTypeFilter);
    }

    final List<_GovernmentPlace> matches = items
        .where((p) => _matchesSearchQuery(p, q))
        .toList();

    matches.sort((a, b) {
      final int scoreComparison = _searchScore(
        b,
        q,
      ).compareTo(_searchScore(a, q));
      if (scoreComparison != 0) return scoreComparison;
      return _distanceKmTo(a.position).compareTo(_distanceKmTo(b.position));
    });

    return matches.take(6).toList();
  }

  bool get _shouldShowSearchSuggestions {
    return _searchFocusNode.hasFocus &&
        _searchQuery.trim().isNotEmpty &&
        _searchSuggestions.isNotEmpty;
  }

  Future<void> _loadPlacesForCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    double latitude = _userLocation.latitude;
    double longitude = _userLocation.longitude;

    try {
      final Position position = await _resolveCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
      _userLocation = LatLng(latitude, longitude);
    } on MissingPluginException {
      _errorMessage = _txt(
        en: 'Location plugin is not available on this build. Showing places near the default location.',
        ar: 'إضافة الموقع غير متوفرة في هذا الإصدار. سيتم عرض الأماكن قرب الموقع الافتراضي.',
      );
    } catch (e) {
      _errorMessage = _txt(
        en: 'Could not read GPS location. ${e.toString()}',
        ar: 'تعذر قراءة موقع GPS. ${e.toString()}',
      );
    }

    final LatLngBounds initialBounds = _buildInitialBounds(
      latitude: latitude,
      longitude: longitude,
    );

    try {
      await _fetchGovernmentPlaces(bounds: initialBounds);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _txt(
            en: 'Map tiles are running on MapTiler. Government places data is temporarily unavailable; tap "Search this area" to retry.',
            ar: 'الخريطة تعمل عبر MapTiler. بيانات الجهات الحكومية غير متاحة مؤقتاً؛ اضغط "بحث في هذه المنطقة" لإعادة المحاولة.',
          );
        });
      }
    }

    if (mounted && _mapReady) {
      _mapController.move(_userLocation, 14.5);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<Position> _resolveCurrentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<void> _fetchGovernmentPlaces({required LatLngBounds bounds}) async {
    final String strictQuery =
        '''
[out:json][timeout:15][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
(
  nwr["amenity"~"police|courthouse"];
  nwr["name"~"مرور|سجل|شهر|محكمة|نيابة|قسم|شرطة"];
);
out center;
''';

    final String fallbackQuery =
        '''
[out:json][timeout:20][bbox:${bounds.south},${bounds.west},${bounds.north},${bounds.east}];
(
  nwr["amenity"~"police|courthouse|townhall"];
  nwr["office"="government"];
  nwr["government"];
  nwr["name"~"court|police|traffic|registry|government|service|مرور|سجل|شهر|محكمة|نيابة|قسم|شرطة", i];
);
out center;
''';

    List<dynamic> elements = await _requestElementsFromOverpass(
      query: strictQuery,
    );

    if (elements.isEmpty) {
      elements = await _requestElementsFromOverpass(query: fallbackQuery);
    }

    final List<_GovernmentPlace> places = <_GovernmentPlace>[];

    for (final dynamic element in elements) {
      if (element is! Map<String, dynamic>) continue;

      final Map<String, dynamic> tags =
          element['tags'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final String rawName = _readStringTag(tags, 'name');
      if (rawName.trim().isEmpty && tags['amenity'] == null) continue;

      final String name = rawName.trim().isNotEmpty
          ? rawName.trim()
          : _txt(en: 'Government Facility', ar: 'جهة حكومية');

      final double? lat = _extractLatitude(element);
      final double? lon = _extractLongitude(element);
      if (lat == null || lon == null) continue;

      final _GovernmentPlaceType type = _getPlaceType(name, tags);
      final String category = _getPlaceCategory(type);
      final IconData icon = _getPlaceIcon(type);
      final LatLng position = LatLng(lat, lon);
      final bool isUserJurisdiction = _isUserJurisdiction(name);

      String workingHours = _readStringTag(tags, 'opening_hours');
      if (workingHours.isEmpty) {
        workingHours = _txt(
          en: 'Usually from 8:00 AM to 3:00 PM (except Friday and Saturday)',
          ar: 'عادة من 8:00 ص إلى 3:00 م (ماعدا الجمعة والسبت)',
        );
      }

      final String street = _readStringTag(tags, 'addr:street');
      final String district = _readStringTag(tags, 'addr:suburb');
      String address = <String>[
        street,
        district,
      ].where((e) => e.isNotEmpty).join(_isArabic ? '، ' : ', ');
      if (address.isEmpty) {
        address = _txt(
          en: 'Detailed address is not available on the map',
          ar: 'العنوان التفصيلي غير متوفر على الخريطة',
        );
      }

      places.add(
        _GovernmentPlace(
          id: '${element['type']}_${element['id']}',
          name: name,
          type: type,
          category: category,
          icon: icon,
          position: position,
          isUserJurisdiction: isUserJurisdiction,
          workingHours: workingHours,
          address: address,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _places
        ..clear()
        ..addAll(places);
      _lastSearchedBounds = bounds;
      if (places.isEmpty) {
        _errorMessage = _txt(
          en: 'No government places found in this area. Try zooming out then search again.',
          ar: 'لم يتم العثور على جهات حكومية في هذه المنطقة. حاول تصغير الخريطة ثم ابحث مرة أخرى.',
        );
      }
    });
  }

  Future<List<dynamic>> _requestElementsFromOverpass({
    required String query,
  }) async {
    Object? lastError;

    for (final String endpoint in _overpassEndpoints) {
      try {
        final http.Response response = await http
            .post(
              Uri.parse(endpoint),
              headers: <String, String>{
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
                'Accept': 'application/json',
                'User-Agent': 'Mezaan-App/1.0',
              },
              body: 'data=${Uri.encodeQueryComponent(query)}',
            )
            .timeout(const Duration(seconds: 22));

        if (response.statusCode != 200) {
          lastError =
              'Overpass request failed (${response.statusCode}) via $endpoint';
          continue;
        }

        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          lastError = 'Unexpected response shape from $endpoint';
          continue;
        }

        return decoded['elements'] as List<dynamic>? ?? <dynamic>[];
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(lastError?.toString() ?? 'All Overpass endpoints failed.');
  }

  LatLngBounds _buildInitialBounds({
    required double latitude,
    required double longitude,
  }) {
    const double delta = 0.06;
    return LatLngBounds(
      LatLng(latitude - delta, longitude - delta),
      LatLng(latitude + delta, longitude + delta),
    );
  }

  Future<void> _searchCurrentMapArea() async {
    if (!_mapReady) return;

    if (_mapController.camera.zoom < 11.5) {
      setState(() {
        _errorMessage = _txt(
          en: 'The area is too large to search. Please zoom in and try again.',
          ar: 'المنطقة كبيرة جداً للبحث. يرجى تقريب الخريطة والمحاولة مرة أخرى.',
        );
      });
      return;
    }

    final LatLngBounds bounds = _mapController.camera.visibleBounds;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastSearchedBounds = bounds;
    });

    try {
      await _fetchGovernmentPlaces(bounds: bounds);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _txt(
            en: 'Government places service is busy right now. MapTiler map is still active; please try search again.',
            ar: 'خدمة بيانات الجهات الحكومية مشغولة الآن. خريطة MapTiler تعمل؛ حاول البحث مرة أخرى.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _centerOnUserLocation() {
    if (_mapReady) {
      _mapController.move(_userLocation, 14.5);
    }
  }

  Future<void> _openGoogleMaps(LatLng destination) async {
    final String googleMapsUrl = Platform.isIOS
        ? 'https://maps.apple.com/?q=${destination.latitude},${destination.longitude}'
        : 'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}';

    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(en: 'Could not open Maps app.', ar: 'تعذر فتح تطبيق الخرائط.'),
          ),
        ),
      );
    }
  }

  String _readStringTag(Map<String, dynamic> tags, String key) {
    final dynamic value = tags[key];
    return value?.toString() ?? '';
  }

  bool _containsAny(String source, List<String> needles) {
    final String lowerSource = source.toLowerCase();
    for (final String needle in needles) {
      if (lowerSource.contains(needle.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  String _normalizeSearchText(String text) {
    String normalized = text.toLowerCase();

    const Map<String, String> replacements = <String, String>{
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ٱ': 'ا',
      'ة': 'ه',
      'ى': 'ي',
      'ؤ': 'و',
      'ئ': 'ي',
    };

    replacements.forEach((String from, String to) {
      normalized = normalized.replaceAll(from, to);
    });

    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');
    normalized = normalized.replaceAll(
      RegExp(r'[^a-z0-9\u0600-\u06FF\s]'),
      ' ',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  String _getCategoryLabelForLanguage(
    _GovernmentPlaceType type, {
    required bool arabic,
  }) {
    switch (type) {
      case _GovernmentPlaceType.traffic:
        return arabic ? 'إدارة المرور' : 'Traffic Department';
      case _GovernmentPlaceType.registry:
        return arabic
            ? 'مكتب سجل مدني / شهر عقاري'
            : 'Civil Registry / Real Estate Registration Office';
      case _GovernmentPlaceType.court:
        return arabic ? 'محكمة / نيابة' : 'Court / Prosecution';
      case _GovernmentPlaceType.police:
        return arabic ? 'قسم شرطة' : 'Police Station';
      case _GovernmentPlaceType.general:
        return arabic ? 'جهة حكومية عامة' : 'General Government Office';
    }
  }

  List<String> _typeSearchKeywords(_GovernmentPlaceType type) {
    switch (type) {
      case _GovernmentPlaceType.traffic:
        return <String>['traffic', 'license', 'مرور', 'رخص', 'مركبات'];
      case _GovernmentPlaceType.registry:
        return <String>[
          'registry',
          'civil',
          'real estate',
          'سجل',
          'مدني',
          'شهر',
        ];
      case _GovernmentPlaceType.court:
        return <String>[
          'court',
          'prosecution',
          'judicial',
          'محكمه',
          'نيابه',
          'قضاء',
        ];
      case _GovernmentPlaceType.police:
        return <String>['police', 'station', 'security', 'شرطه', 'قسم', 'امن'];
      case _GovernmentPlaceType.general:
        return <String>[
          'government',
          'office',
          'service',
          'حكومي',
          'مكتب',
          'خدمه',
        ];
    }
  }

  String _searchCorpus(_GovernmentPlace place) {
    final String englishCategory = _getCategoryLabelForLanguage(
      place.type,
      arabic: false,
    );
    final String arabicCategory = _getCategoryLabelForLanguage(
      place.type,
      arabic: true,
    );
    final String keywords = _typeSearchKeywords(place.type).join(' ');

    return _normalizeSearchText(
      '${place.name} ${place.address} ${place.category} $englishCategory $arabicCategory $keywords',
    );
  }

  bool _matchesSearchQuery(_GovernmentPlace place, String normalizedQuery) {
    return _searchCorpus(place).contains(normalizedQuery);
  }

  int _searchScore(_GovernmentPlace place, String normalizedQuery) {
    final String normalizedName = _normalizeSearchText(place.name);
    final String normalizedAddress = _normalizeSearchText(place.address);
    final String normalizedCategory = _normalizeSearchText(place.category);

    if (normalizedName == normalizedQuery) return 150;
    if (normalizedName.startsWith(normalizedQuery)) return 120;
    if (normalizedName.contains(normalizedQuery)) return 100;
    if (normalizedCategory.startsWith(normalizedQuery)) return 80;
    if (normalizedCategory.contains(normalizedQuery)) return 70;
    if (normalizedAddress.contains(normalizedQuery)) return 50;
    return 10;
  }

  bool _isUserJurisdiction(String name) {
    final String lowerName = name.toLowerCase();
    return _userRegisteredAreaAliases.any(
      (String area) => lowerName.contains(area.toLowerCase()),
    );
  }

  _GovernmentPlaceType _getPlaceType(String name, Map<String, dynamic> tags) {
    if (_containsAny(name, <String>['مرور', 'traffic'])) {
      return _GovernmentPlaceType.traffic;
    }

    if (_containsAny(name, <String>['سجل', 'شهر', 'registry', 'civil'])) {
      return _GovernmentPlaceType.registry;
    }

    if (_containsAny(name, <String>[
          'محكمة',
          'نيابة',
          'court',
          'prosecution',
        ]) ||
        tags['amenity'] == 'courthouse') {
      return _GovernmentPlaceType.court;
    }

    if (_containsAny(name, <String>['قسم', 'شرطة', 'police']) ||
        tags['amenity'] == 'police') {
      return _GovernmentPlaceType.police;
    }

    return _GovernmentPlaceType.general;
  }

  String _getPlaceCategory(_GovernmentPlaceType type) {
    return _getCategoryLabelForLanguage(type, arabic: _isArabic);
  }

  IconData _getPlaceIcon(_GovernmentPlaceType type) {
    switch (type) {
      case _GovernmentPlaceType.traffic:
        return Icons.directions_car_rounded;
      case _GovernmentPlaceType.registry:
        return Icons.contact_page_rounded;
      case _GovernmentPlaceType.court:
        return Icons.account_balance_rounded;
      case _GovernmentPlaceType.police:
        return Icons.local_police_rounded;
      case _GovernmentPlaceType.general:
        return Icons.location_city_rounded;
    }
  }

  double? _extractLatitude(Map<String, dynamic> element) {
    final dynamic lat = element['lat'];
    if (lat is num) return lat.toDouble();
    final dynamic center = element['center'];
    if (center is Map<String, dynamic> && center['lat'] is num) {
      return (center['lat'] as num).toDouble();
    }
    return null;
  }

  double? _extractLongitude(Map<String, dynamic> element) {
    final dynamic lon = element['lon'];
    if (lon is num) return lon.toDouble();
    final dynamic center = element['center'];
    if (center is Map<String, dynamic> && center['lon'] is num) {
      return (center['lon'] as num).toDouble();
    }
    return null;
  }

  double _distanceKmTo(LatLng point) {
    return _distance.as(LengthUnit.Kilometer, _userLocation, point);
  }

  int _estimateMinutes(double distanceKm) {
    const double avgCitySpeedKmPerHour = 32.0;
    final int minutes = (distanceKm / avgCitySpeedKmPerHour * 60).round();
    return math.max(minutes, 2);
  }

  String _distanceLabel(double distanceKm) {
    if (distanceKm < 1) {
      final int meters = (distanceKm * 1000).round();
      return _txt(en: '$meters m', ar: '$meters م');
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String _sortLabel() {
    switch (_sortMode) {
      case _PlaceSort.nearest:
        return _txt(en: 'Nearest', ar: 'الأقرب');
      case _PlaceSort.name:
        return _txt(en: 'A-Z', ar: 'أ-ي');
    }
  }

  void _cycleSortMode() {
    setState(() {
      _sortMode = switch (_sortMode) {
        _PlaceSort.nearest => _PlaceSort.name,
        _PlaceSort.name => _PlaceSort.nearest,
      };
    });
  }

  void _focusOnPlace(_GovernmentPlace place) {
    setState(() => _selectedPlaceId = place.id);
    if (_mapReady) {
      _mapController.move(place.position, 15.0);
    }
  }

  void _focusOnFirstVisibleResult() {
    final List<_GovernmentPlace> suggestions = _searchSuggestions;
    if (suggestions.isNotEmpty) {
      _selectSearchSuggestion(suggestions.first);
      return;
    }

    final List<_GovernmentPlace> places = _visiblePlaces;
    if (places.isEmpty) return;
    final _GovernmentPlace place = places.first;
    _focusOnPlace(place);
    if (!_showListView) {
      _openPlaceSheet(place);
    }
  }

  void _selectSearchSuggestion(_GovernmentPlace place) {
    _searchController.text = place.name;
    _searchController.selection = TextSelection.collapsed(
      offset: place.name.length,
    );

    setState(() {
      _searchQuery = place.name;
      _showListView = false;
    });

    _searchFocusNode.unfocus();
    _focusOnPlace(place);
    _openPlaceSheet(place);
  }

  Widget _buildSearchSuggestionsPanel() {
    final List<_GovernmentPlace> suggestions = _searchSuggestions;
    if (!_shouldShowSearchSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF0D2345).withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 220.h),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: const Color(0xFF0D2345).withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final _GovernmentPlace place = suggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(
                place.icon,
                size: 18.sp,
                color: const Color(0xFF0D2345),
              ),
              title: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2345),
                ),
              ),
              subtitle: Text(
                '${place.category} • ${_distanceLabel(_distanceKmTo(place.position))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4E5D78),
                ),
              ),
              onTap: () => _selectSearchSuggestion(place),
            );
          },
        ),
      ),
    );
  }

  void _openPlaceSheet(_GovernmentPlace place) {
    setState(() => _selectedPlaceId = place.id);
    final double distanceKm = _distanceKmTo(place.position);
    final int eta = _estimateMinutes(distanceKm);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final Color accent = place.isUserJurisdiction
            ? Colors.green.shade600
            : (place.type == _GovernmentPlaceType.police
                  ? Colors.blue.shade800
                  : Colors.amber.shade800);

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20.w,
              12.h,
              20.w,
              24.h + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(place.icon, color: accent, size: 28.sp),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D2345),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${place.category} • ${_distanceLabel(distanceKm)} • $eta ${_txt(en: 'min', ar: 'د')}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        place.address,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        place.workingHours,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openGoogleMaps(place.position);
                    },
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(
                      _txt(en: 'Open In Google Maps', ar: 'افتح في خرائط جوجل'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2345),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _selectedPlaceId = null);
    });
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = <Marker>[];

    for (final _GovernmentPlace place in _visiblePlaces) {
      final bool isSelected = _selectedPlaceId == place.id;
      final Color tint = place.isUserJurisdiction
          ? Colors.green.shade600
          : (place.type == _GovernmentPlaceType.police
                ? Colors.blue.shade800
                : Colors.amber.shade800);

      markers.add(
        Marker(
          point: place.position,
          width: isSelected ? 78.w : 70.w,
          height: isSelected ? 78.h : 70.h,
          child: GestureDetector(
            onTap: () {
              _focusOnPlace(place);
              _openPlaceSheet(place);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSelected ? 48.w : 42.w,
                  height: isSelected ? 48.h : 42.h,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                  ),
                  child: Icon(
                    place.icon,
                    color: Colors.white,
                    size: isSelected ? 22.sp : 20.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    markers.add(
      Marker(
        point: _userLocation,
        width: 60.w,
        height: 60.h,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return markers;
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 42.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _chip(
            label: _txt(en: 'All', ar: 'الكل'),
            selected: _selectedTypeFilter == null,
            onTap: () => setState(() {
              _selectedTypeFilter = null;
            }),
          ),
          _chip(
            label: '${_txt(en: 'Sort', ar: 'ترتيب')}: ${_sortLabel()}',
            selected: false,
            onTap: _cycleSortMode,
          ),
          ..._GovernmentPlaceType.values.map((type) {
            return _chip(
              label: _getPlaceCategory(type),
              selected: _selectedTypeFilter == type,
              onTap: () => setState(() {
                _selectedTypeFilter = _selectedTypeFilter == type ? null : type;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999.r),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0D2345)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D2345)
                    : const Color(0xFF0D2345).withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF0D2345),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 14.w),
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: const Color(0xFF0D2345).withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: Offset(0, 10.h),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2345).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30.w,
                      height: 30.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2345).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: const Color(0xFF0D2345),
                        size: 17.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onSubmitted: (_) => _focusOnFirstVisibleResult(),
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D2345),
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: _txt(
                            en: 'Search service, office, address...',
                            ar: 'ابحث عن خدمة أو مكتب أو عنوان...',
                          ),
                          hintStyle: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: const Color(
                              0xFF0D2345,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        tooltip: _txt(en: 'Clear search', ar: 'مسح البحث'),
                        icon: Icon(Icons.close_rounded, size: 18.sp),
                        color: const Color(0xFF0D2345),
                      ),
                    SizedBox(width: 2.w),
                    SizedBox(
                      height: 30.h,
                      child: ElevatedButton(
                        onPressed: _focusOnFirstVisibleResult,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF0D2345),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Icon(Icons.arrow_forward_rounded, size: 16.sp),
                      ),
                    ),
                  ],
                ),
              ),
              _buildSearchSuggestionsPanel(),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Expanded(
                    child: _searchControlButton(
                      label: _txt(en: 'Refresh Area', ar: 'تحديث المنطقة'),
                      icon: _isLoading
                          ? SizedBox(
                              width: 14.w,
                              height: 14.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.refresh_rounded, size: 17.sp),
                      onTap: _isLoading ? null : _searchCurrentMapArea,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _searchControlButton(
                      label: _showListView
                          ? _txt(en: 'Map View', ar: 'عرض الخريطة')
                          : _txt(en: 'List View', ar: 'عرض القائمة'),
                      icon: Icon(
                        _showListView
                            ? Icons.map_rounded
                            : Icons.view_list_rounded,
                        size: 17.sp,
                      ),
                      onTap: () =>
                          setState(() => _showListView = !_showListView),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        _buildFilterBar(),
        SizedBox(height: 6.h),
        _buildQuickInfoRow(),
      ],
    );
  }

  Widget _buildQuickInfoRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          _infoPill(
            icon: Icons.place_rounded,
            text:
                '${_visiblePlaces.length} ${_txt(en: 'results', ar: 'نتيجة')}',
          ),
          SizedBox(width: 6.w),
          _infoPill(icon: Icons.sort_rounded, text: _sortLabel()),
          const Spacer(),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: SizedBox(
                width: 14.w,
                height: 14.h,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoPill({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: const Color(0xFF0D2345).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: const Color(0xFF0D2345)),
          SizedBox(width: 4.w),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D2345),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchControlButton({
    required String label,
    required VoidCallback? onTap,
    required Widget icon,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: icon,
      label: Text(
        label,
        style: GoogleFonts.cairo(fontSize: 12.sp, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF0D2345).withValues(alpha: 0.09),
        foregroundColor: const Color(0xFF0D2345),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  Widget _buildListView() {
    final List<_GovernmentPlace> places = _visiblePlaces;
    if (places.isEmpty) {
      return Center(
        child: Text(
          _txt(
            en: 'No places match your filters',
            ar: 'لا توجد نتائج مطابقة للفلاتر',
          ),
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 132.h, 16.w, 90.h),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final _GovernmentPlace place = places[index];
        final double distanceKm = _distanceKmTo(place.position);
        final int eta = _estimateMinutes(distanceKm);

        return Card(
          margin: EdgeInsets.only(bottom: 10.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(
              color: _selectedPlaceId == place.id
                  ? const Color(0xFF0D2345)
                  : Colors.transparent,
              width: 1.3,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18.r,
                      backgroundColor: const Color(
                        0xFF0D2345,
                      ).withValues(alpha: 0.08),
                      child: Icon(
                        place.icon,
                        color: const Color(0xFF0D2345),
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${place.category} • ${_distanceLabel(distanceKm)} • $eta ${_txt(en: 'min', ar: 'د')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  place.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _focusOnPlace(place);
                          _openPlaceSheet(place);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(
                              0xFF0D2345,
                            ).withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          _txt(en: 'Details', ar: 'التفاصيل'),
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D2345),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openGoogleMaps(place.position),
                        icon: Icon(Icons.navigation_rounded, size: 17.sp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2345),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        label: Text(
                          _txt(en: 'Google Maps', ar: 'خرائط جوجل'),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> markers = _buildMarkers();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        toolbarHeight: 68.h,
        titleSpacing: 8.w,
        title: Row(
          children: [
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                _txt(en: 'Gov Services Map', ar: 'خريطة الخدمات الحكومية'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Text(
              '${_visiblePlaces.length}',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
                color: Colors.white,
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFF0D2345), Color(0xFF1A3A6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_showListView)
            _buildListView()
          else
            FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.5, // ظبطنا الزووم من البداية
              onMapReady: () {
                _mapReady = true;
                // شلنا الـ _mapController.move من هنا عشان كانت بتعمل تعارض لحظة التحميل
              },
            ),
            children: [
              TileLayer(
                // السر هنا: ضفنا /256/ عشان الصور تنزل خفيفة وماتعملش Crash
                urlTemplate:
                    'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=HNGIJUr6VGmHEr8rxntj',
                userAgentPackageName: 'com.example.mezaan',
                tileSize: 256,
              ),
              MarkerLayer(markers: markers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© MapTiler',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.maptiler.com/copyright/'),
                    ),
                  ),
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!_showListView)
            Positioned(
              left: 12.w,
              bottom: 18.h,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFFD2DCE8),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _txt(en: 'MapTiler Streets v2', ar: 'MapTiler Streets v2'),
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF23436A),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8.h,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTopControls()),
          ),
          if (!_showListView)
            Positioned(
              right: 14.w,
              bottom: 22.h,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_refresh_btn',
                    onPressed: _isLoading ? null : _searchCurrentMapArea,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D2345),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 20.sp),
                  ),
                  SizedBox(height: 10.h),
                  FloatingActionButton(
                    heroTag: 'map_location_btn',
                    onPressed: _centerOnUserLocation,
                    backgroundColor: const Color(0xFF0D2345),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(Icons.my_location_rounded, size: 24.sp),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 98.h,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.red.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: Offset(0, 5.h),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Row(
                    children: [
                      Container(
                        width: 28.w,
                        height: 28.h,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade700,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.cairo(
                            color: Colors.red.shade900,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      TextButton(
                        onPressed: _isLoading ? null : _searchCurrentMapArea,
                        child: Text(
                          _txt(en: 'Retry', ar: 'إعادة'),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GovernmentPlace {
  final String id;
  final String name;
  final _GovernmentPlaceType type;
  final String category;
  final IconData icon;
  final LatLng position;
  final bool isUserJurisdiction;
  final String workingHours;
  final String address;

  const _GovernmentPlace({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.icon,
    required this.position,
    required this.isUserJurisdiction,
    required this.workingHours,
    required this.address,
  });
}

enum _GovernmentPlaceType { traffic, registry, court, police, general }

enum _PlaceSort { nearest, name }
