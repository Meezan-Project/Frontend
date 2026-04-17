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
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
  ];

  static const List<String> _userRegisteredAreaAliases = <String>[
    'الدقي',
    'dokki',
    'duqqi',
  ];

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Distance _distance = const Distance();

  final List<_GovernmentPlace> _places = <_GovernmentPlace>[];

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
    _loadPlacesForCurrentLocation();
  }

  @override
  void dispose() {
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

    final String q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q);
      });
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
            en: 'Could not load map places right now. Please tap "Search this area" to retry.',
            ar: 'تعذر تحميل الأماكن على الخريطة الآن. اضغط "بحث في هذه المنطقة" لإعادة المحاولة.',
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
            en: 'Could not search this area right now, the server is busy. Try again.',
            ar: 'تعذر البحث في هذه المنطقة، السيرفر مشغول. جرب مرة أخرى.',
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
    switch (type) {
      case _GovernmentPlaceType.traffic:
        return _txt(en: 'Traffic Department', ar: 'إدارة المرور');
      case _GovernmentPlaceType.registry:
        return _txt(
          en: 'Civil Registry / Real Estate Registration Office',
          ar: 'مكتب سجل مدني / شهر عقاري',
        );
      case _GovernmentPlaceType.court:
        return _txt(en: 'Court / Prosecution', ar: 'محكمة / نيابة');
      case _GovernmentPlaceType.police:
        return _txt(en: 'Police Station', ar: 'قسم شرطة');
      case _GovernmentPlaceType.general:
        return _txt(en: 'General Government Office', ar: 'جهة حكومية عامة');
    }
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
    final List<_GovernmentPlace> places = _visiblePlaces;
    if (places.isEmpty) return;
    final _GovernmentPlace place = places.first;
    _focusOnPlace(place);
    if (!_showListView) {
      _openPlaceSheet(place);
    }
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
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: const Color(0xFF0D2345).withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2345).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: const Color(0xFF0D2345),
                  size: 19.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onSubmitted: (_) => _focusOnFirstVisibleResult(),
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
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
                      fontSize: 13.sp,
                      color: const Color(0xFF0D2345).withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              _topActionButton(
                tooltip: _txt(en: 'Refresh area', ar: 'تحديث المنطقة'),
                onTap: _isLoading ? null : _searchCurrentMapArea,
                icon: _isLoading
                    ? SizedBox(
                        width: 14.w,
                        height: 14.h,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, size: 18.sp),
              ),
              if (_searchQuery.isNotEmpty)
                _topActionButton(
                  tooltip: _txt(en: 'Clear search', ar: 'مسح البحث'),
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: Icon(Icons.close_rounded, size: 18.sp),
                ),
              _topActionButton(
                tooltip: _txt(en: 'Toggle map/list', ar: 'تبديل خريطة/قائمة'),
                onTap: () => setState(() => _showListView = !_showListView),
                icon: Icon(
                  _showListView ? Icons.map_rounded : Icons.view_list_rounded,
                  size: 18.sp,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        _buildFilterBar(),
      ],
    );
  }

  Widget _topActionButton({
    required String tooltip,
    required VoidCallback? onTap,
    required Widget icon,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            width: 32.w,
            height: 32.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2345).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: icon,
          ),
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
      appBar: AppBar(
        toolbarHeight: 74.h,
        titleSpacing: 8.w,
        title: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _txt(
                  en: 'Government Service Map',
                  ar: 'خريطة الخدمات الحكومية',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 18.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFF0D2345), Color(0xFF1A3A6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18.r)),
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
                initialZoom: 13.5,
                onMapReady: () {
                  _mapReady = true;
                  _mapController.move(_userLocation, 14.5);
                  if (_lastSearchedBounds == null) {
                    _searchCurrentMapArea();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const <String>['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.mezaan',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          Positioned(
            top: 10.h,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTopControls()),
          ),
          if (!_showListView)
            Positioned(
              right: 16.w,
              bottom: 24.h,
              child: FloatingActionButton(
                onPressed: _centerOnUserLocation,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D2345),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(Icons.my_location_rounded, size: 26.sp),
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 100.h,
              child: Material(
                color: Colors.red.shade50,
                elevation: 4,
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
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
