import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/convoy.dart';
import '../models/expense.dart';
import 'connectivity_service.dart';
import 'places_service.dart' show PlaceDetails;

/// Thin wrapper around the backend's REST endpoints. Every convoy write
/// (create, join, lock, propose) goes through here; live updates after that
/// point arrive over the socket connection in [SocketService].
class ApiService {
  // Automatically routes to 10.0.2.2:4000 on Android emulators to reach the host
  // machine's backend server, or localhost:4000 on iOS / macOS / web.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('CONVOY_API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://localhost:4000';
  }

  String? _token;
  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> register(String name, String email, String password) =>
      _post('/auth/register', {'name': name, 'email': email, 'password': password}, auth: false);

  Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password}, auth: false);

  Future<Map<String, dynamic>> googleAuth({
    String? idToken,
    required String email,
    String? name,
    String? providerId,
  }) =>
      _post(
        '/auth/google',
        {
          if (idToken != null) 'idToken': idToken,
          'email': email,
          if (name != null) 'name': name,
          if (providerId != null) 'providerId': providerId,
        },
        auth: false,
      );

  Future<Map<String, dynamic>> appleAuth({
    String? identityToken,
    required String email,
    String? name,
    String? providerId,
  }) =>
      _post(
        '/auth/apple',
        {
          if (identityToken != null) 'identityToken': identityToken,
          'email': email,
          if (name != null) 'name': name,
          if (providerId != null) 'providerId': providerId,
        },
        auth: false,
      );

  Future<Convoy> createConvoy({
    required String name,
    required String startLabel,
    required double startLat,
    required double startLng,
    required String destLabel,
    required double destLat,
    required double destLng,
    required String vehicleName,
    required int passengers,
    List<PlaceDetails> waypoints = const [],
  }) async {
    final j = await _post('/convoys', {
      'name': name,
      'startLabel': startLabel,
      'startLat': startLat,
      'startLng': startLng,
      'destLabel': destLabel,
      'destLat': destLat,
      'destLng': destLng,
      'vehicleName': vehicleName,
      'passengers': passengers,
      'waypoints': waypoints.map((w) => {'label': w.label, 'lat': w.lat, 'lng': w.lng}).toList(),
    });
    return Convoy.fromJson(j);
  }

  Future<List<RouteOption>> routeOptions(String code) async {
    final j = await _get('/convoys/$code/route-options');
    return (j['options'] as List).map((o) => RouteOption.fromJson(o)).toList();
  }

  Future<Convoy> lockRoute(
    String code, {
    required RouteOption chosen,
    required List<Stop> stops,
  }) async {
    final j = await _post('/convoys/$code/lock', {
      'summary': chosen.summary,
      'polyline': chosen.polyline,
      'distanceM': chosen.distanceM,
      'durationS': chosen.durationS,
      'stops': stops
          .map((s) => {
                'label': s.label,
                'lat': s.lat,
                'lng': s.lng,
                'distanceAlongM': s.distanceAlongM,
                'kind': s.kind,
              })
          .toList(),
    });
    return Convoy.fromJson(j);
  }

  Future<Convoy> joinConvoy(String code, {required String vehicleName, required int passengers}) async {
    final j = await _post('/convoys/$code/join', {'vehicleName': vehicleName, 'passengers': passengers});
    return Convoy.fromJson(j);
  }

  Future<ConvoyMember> updateVehicle(String code, {required String vehicleName}) async {
    final j = await _patch('/convoys/$code/vehicle', {'vehicleName': vehicleName});
    return ConvoyMember.fromJson(j['member'] as Map<String, dynamic>);
  }

  Future<Convoy> getConvoy(String code) async {
    final j = await _get('/convoys/$code');
    return Convoy.fromJson(j);
  }

  Future<void> endConvoy(String code) => _post('/convoys/$code/end', {});

  Future<Convoy> reroute({
    required String code,
    String? destLabel,
    double? destLat,
    double? destLng,
    List<PlaceDetails>? waypoints,
  }) async {
    final j = await _post('/convoys/$code/reroute', {
      if (destLabel != null) 'destLabel': destLabel,
      if (destLat != null) 'destLat': destLat,
      if (destLng != null) 'destLng': destLng,
      if (waypoints != null)
        'waypoints': waypoints.map((w) => {'label': w.label, 'lat': w.lat, 'lng': w.lng}).toList(),
    });
    return Convoy.fromJson(j);
  }

  Future<void> proposeChange(String code, {required String summary, String? destLabel, double? destLat, double? destLng}) =>
      _post('/convoys/$code/proposals', {
        'summary': summary,
        if (destLabel != null) 'destLabel': destLabel,
        if (destLat != null) 'destLat': destLat,
        if (destLng != null) 'destLng': destLng,
      });

  Future<List<RouteProposal>> pendingProposals(String code) async {
    final j = await _get('/convoys/$code/proposals');
    return (j['proposals'] as List).map((p) => RouteProposal.fromJson(p)).toList();
  }

  /// Resolves a proposal. If accepted and the proposal carried a new
  /// destination, the server re-locks the route automatically — the
  /// returned `convoy` key is non-null in that case.
  Future<Convoy?> resolveProposal(String code, String proposalId, {required bool accept}) async {
    final j = await _post('/convoys/$code/proposals/$proposalId/resolve', {
      'decision': accept ? 'accepted' : 'declined',
    });
    final convoyJson = j['convoy'];
    return convoyJson == null ? null : Convoy.fromJson(convoyJson);
  }

  Future<T> _runWithNetworkGuard<T>(Future<T> Function() call) async {
    try {
      final result = await call().timeout(const Duration(seconds: 15));
      ConnectivityService.instance.setOnline();
      return result;
    } on SocketException catch (e) {
      final hasInternet = await ConnectivityService.instance.checkConnection();
      if (!hasInternet) {
        ConnectivityService.instance.setOffline();
        ConnectivityService.instance.showNoInternetDialog();
        throw const NoInternetException();
      }
      throw ApiException('Unable to reach server. Please ensure the backend is running.');
    } on http.ClientException catch (e) {
      final hasInternet = await ConnectivityService.instance.checkConnection();
      if (!hasInternet) {
        ConnectivityService.instance.setOffline();
        ConnectivityService.instance.showNoInternetDialog();
        throw const NoInternetException();
      }
      throw ApiException('Server connection error. Please try again.');
    } on TimeoutException catch (_) {
      final hasInternet = await ConnectivityService.instance.checkConnection();
      if (!hasInternet) {
        ConnectivityService.instance.setOffline();
        ConnectivityService.instance.showNoInternetDialog();
        throw const NoInternetException();
      }
      throw ApiException('Server request timed out. Please try again.');
    }
  }

  Future<Map<String, dynamic>> _get(String path) => _runWithNetworkGuard(() async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(res);
  });

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool auth = true}) =>
      _runWithNetworkGuard(() async {
        final res = await http.post(
          Uri.parse('$baseUrl$path'),
          headers: auth ? _headers : {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        return _decode(res);
      });

  Future<void> updateProfile({String? name}) async {
    await _patch('/auth/me', {
      if (name != null) 'name': name,
    });
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) =>
      _runWithNetworkGuard(() async {
        final res = await http.patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        );
        return _decode(res);
      });

  Future<Map<String, dynamic>> _delete(String path) => _runWithNetworkGuard(() async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _decode(res);
  });

  /// Fetches expenses, people, and categories for a convoy or personal dashboard.
  Future<Map<String, dynamic>> fetchExpensesData({String? convoyCode}) async {
    final path = convoyCode != null ? '/expenses?code=$convoyCode' : '/expenses';
    return _get(path);
  }

  Future<Expense> createExpense({
    required String title,
    required double amount,
    required String categoryName,
    String? categoryId,
    required String paidByName,
    String? personId,
    String? convoyCode,
  }) async {
    final j = await _post('/expenses', {
      'title': title,
      'amount': amount,
      'categoryName': categoryName,
      if (categoryId != null) 'categoryId': categoryId,
      'paidByName': paidByName,
      if (personId != null) 'personId': personId,
      if (convoyCode != null) 'convoyCode': convoyCode,
    });
    return Expense.fromJson(j);
  }

  Future<void> deleteExpense(String id) => _delete('/expenses/$id');

  Future<ExpensePerson> addPerson({
    required String name,
    String? convoyCode,
  }) async {
    final j = await _post('/expenses/people', {
      'name': name,
      if (convoyCode != null) 'convoyCode': convoyCode,
    });
    return ExpensePerson.fromJson(j);
  }

  Future<void> deletePerson(String id) => _delete('/expenses/people/$id');

  Future<ExpenseCategoryItem> addCategory({
    required String name,
    required String icon,
    String? convoyCode,
  }) async {
    final j = await _post('/expenses/categories', {
      'name': name,
      'icon': icon,
      if (convoyCode != null) 'convoyCode': convoyCode,
    });
    return ExpenseCategoryItem.fromJson(j);
  }

  Future<ExpenseCategoryItem> editCategory({
    required String id,
    required String name,
    String? icon,
  }) async {
    final j = await _patch('/expenses/categories/$id', {
      'name': name,
      if (icon != null) 'icon': icon,
    });
    return ExpenseCategoryItem.fromJson(j);
  }

  Future<void> deleteCategory(String id) => _delete('/expenses/categories/$id');

  Future<ExpenseSession> completeExpenseSession({
    required String name,
    String? convoyCode,
  }) async {
    final j = await _post('/expenses/complete-session', {
      'name': name,
      if (convoyCode != null) 'convoyCode': convoyCode,
    });
    return ExpenseSession.fromJson(j);
  }

  Future<List<ExpenseSession>> fetchExpenseHistory({String? convoyCode}) async {
    final path = convoyCode != null ? '/expenses/history?code=$convoyCode' : '/expenses/history';
    final j = await _get(path);
    final list = j['sessions'] as List;
    return list.map((s) => ExpenseSession.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<void> deleteExpenseSession(String id) => _delete('/expenses/history/$id');

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Request failed (${res.statusCode})');
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class NoInternetException implements Exception {
  final String message;
  const NoInternetException([this.message = 'No active internet connection']);
  @override
  String toString() => message;
}
