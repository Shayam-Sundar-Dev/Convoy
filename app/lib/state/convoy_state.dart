import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/convoy.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../services/walkie_talkie_service.dart';
import '../services/car_bridge_service.dart';
import '../services/places_service.dart' show PlaceDetails;

/// Central app state: current user/session, the active convoy, its live
/// roster, messages, and pending route proposals. Screens read from this
/// via Provider and call its methods rather than talking to the services
/// directly.
class ConvoyState extends ChangeNotifier {
  final ApiService api = ApiService();
  final SocketService socket = SocketService();
  final LocationService location = LocationService();
  final WalkieTalkieService walkieTalkie = WalkieTalkieService();
  final CarBridgeService carBridge = CarBridgeService();

  String? token;
  String? userId;
  String? userName;
  String? userEmail;

  bool isWalkieTalkieTransmitting = false;
  String? activeTransmitterName;
  Timer? _transmitterResetTimer;

  bool get isRadioMuted => walkieTalkie.isMuted;

  Convoy? convoy;
  List<ConvoyMember> members = [];
  List<ConvoyMessage> messages = [];
  List<RouteProposal> pendingProposals = [];
  double? stragglerGapM;

  /// Returns vehicles in the convoy, grouping all people traveling in the same vehicle.
  List<ConvoyVehicle> get vehicles => groupMembersByVehicle(members.isNotEmpty ? members : (convoy?.members ?? []));

  /// Returns the vehicle the current user belongs to.
  ConvoyVehicle? get myVehicle {
    final vList = vehicles;
    for (final v in vList) {
      if (v.containsUser(userId) || v.passengerNames.any((n) => n.toLowerCase() == userName?.toLowerCase())) {
        return v;
      }
    }
    return vList.firstOrNull;
  }

  ConvoyState() {
    carBridge.onCarPushToTalkDown = () => startPushToTalk();
    carBridge.onCarPushToTalkUp = () => stopPushToTalk();
    carBridge.onCarToggleMute = () => toggleRadioMute();
  }

  void _syncCarBridge() {
    if (convoy == null) {
      carBridge.clearCarState();
      return;
    }
    final v = myVehicle;
    final vList = vehicles;
    final position = v != null ? (vList.indexOf(v) + 1) : 1;
    final isLead = v?.isLead ?? (members.any((m) => m.userId == userId && m.isLead));
    final gap = v?.gapToLeadM ?? 0.0;
    final isStraggler = (stragglerGapM != null && gap >= stragglerGapM!) || (v?.isStale ?? false);

    carBridge.updateCarState(
      convoyName: convoy?.name,
      convoyCode: convoy?.code,
      myVehicleName: v?.name ?? 'My Vehicle',
      isLead: isLead,
      position: position,
      totalVehicles: vList.isNotEmpty ? vList.length : 1,
      gapToLeadM: gap,
      isStraggler: isStraggler,
      isRadioMuted: isRadioMuted,
      isTransmitting: isWalkieTalkieTransmitting,
      activeSpeakerName: activeTransmitterName,
    );
  }

  // Live device GPS location
  double? currentLat;
  double? currentLng;

  // Expenses & Categories & People
  List<Expense> expenses = [];
  List<ExpensePerson> people = [];
  List<ExpenseCategoryItem> categories = [];
  bool isLoadingExpenses = false;
  List<ExpenseSession> historySessions = [];
  bool isLoadingHistory = false;
  ExpenseSession? recentlyCompletedSession;
  Timer? _recentlyCompletedTimer;

  void dismissCompletedSessionBanner() {
    _recentlyCompletedTimer?.cancel();
    recentlyCompletedSession = null;
    notifyListeners();
  }

  void markSessionCompleted(ExpenseSession session) {
    recentlyCompletedSession = session;
    _recentlyCompletedTimer?.cancel();
    _recentlyCompletedTimer = Timer(const Duration(seconds: 5), () {
      recentlyCompletedSession = null;
      notifyListeners();
    });
    notifyListeners();
  }

  double get totalExpenses => expenses.fold(0.0, (sum, e) => sum + e.amount);

  List<String> get allTravelerNames {
    final names = <String>[];
    if (userName != null && userName!.trim().isNotEmpty) {
      names.add(userName!.trim());
    }
    for (final p in people) {
      if (!names.any((n) => n.toLowerCase() == p.name.trim().toLowerCase())) {
        names.add(p.name.trim());
      }
    }
    for (final m in members) {
      if (!names.any((n) => n.toLowerCase() == m.userName.trim().toLowerCase())) {
        names.add(m.userName.trim());
      }
    }
    for (final e in expenses) {
      if (!names.any((n) => n.toLowerCase() == e.paidByName.trim().toLowerCase())) {
        names.add(e.paidByName.trim());
      }
    }
    return names;
  }

  int get peopleCount => allTravelerNames.isNotEmpty ? allTravelerNames.length : 1;
  double get splitPerPerson => peopleCount > 0 ? (totalExpenses / peopleCount) : 0.0;

  Map<String, double> get spentByPerson {
    final map = <String, double>{};
    for (final name in allTravelerNames) {
      map[name] = 0.0;
    }
    for (final e in expenses) {
      final name = e.paidByName.trim();
      final match = allTravelerNames.firstWhere(
        (n) => n.toLowerCase() == name.toLowerCase(),
        orElse: () => name,
      );
      map[match] = (map[match] ?? 0.0) + e.amount;
    }
    return map;
  }

  Map<String, double> get spentByCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.categoryName] = (map[e.categoryName] ?? 0.0) + e.amount;
    }
    return map;
  }

  bool isConnected = true;

  /// Set to true when the server emits convoy:ended (host ended the trip).
  /// MapScreen watches this to show the "trip ended" dialog for clients.
  bool convoyEnded = false;

  // Ticks every few seconds purely so widgets reading member.isStale /
  // lastSeenLabel (which are time-based, not event-based) recompute even
  // when no new data has arrived — otherwise a member could go stale and
  // the UI would never notice, since nothing would trigger a rebuild.
  Timer? _staleTicker;

  bool get isHost => convoy != null && userId != null && convoy!.hostId == userId;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('userId');
    userName = prefs.getString('userName');
    userEmail = prefs.getString('userEmail');
    if (token != null) api.setToken(token);
    notifyListeners();
  }

  Future<void> _persistSession(Map<String, dynamic> authResult) async {
    token = authResult['token'];
    userId = authResult['user']['id'];
    userName = authResult['user']['name'];
    userEmail = authResult['user']['email'] as String?;
    api.setToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token!);
    await prefs.setString('userId', userId!);
    await prefs.setString('userName', userName!);
    if (userEmail != null) await prefs.setString('userEmail', userEmail!);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final result = await api.register(name, email, password);
    await _persistSession(result);
  }

  Future<void> login(String email, String password) async {
    final result = await api.login(email, password);
    await _persistSession(result);
  }

  static const String _googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  Future<void> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: _googleServerClientId.isNotEmpty ? _googleServerClientId : null,
      scopes: ['email', 'profile'],
    );
    final account = await googleSignIn.signIn();
    if (account == null) return; // User cancelled
    final auth = await account.authentication;
    final result = await api.googleAuth(
      idToken: auth.idToken,
      email: account.email,
      name: account.displayName,
      providerId: account.id,
    );
    await _persistSession(result);
  }

  Future<void> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final email = credential.email ?? '${credential.userIdentifier ?? "user"}@privaterelay.appleid.com';
    final nameParts = [credential.givenName, credential.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final result = await api.appleAuth(
      identityToken: credential.identityToken,
      email: email,
      name: nameParts.isNotEmpty ? nameParts : null,
      providerId: credential.userIdentifier,
    );
    await _persistSession(result);
  }

  Future<Convoy> hostConvoy({
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
    convoy = await api.createConvoy(
      name: name,
      startLabel: startLabel,
      startLat: startLat,
      startLng: startLng,
      destLabel: destLabel,
      destLat: destLat,
      destLng: destLng,
      vehicleName: vehicleName,
      passengers: passengers,
      waypoints: waypoints,
    );
    members = convoy!.members;
    notifyListeners();
    return convoy!;
  }

  Future<Convoy> joinConvoy(String code, {required String vehicleName, required int passengers}) async {
    convoy = await api.joinConvoy(code, vehicleName: vehicleName, passengers: passengers);
    members = convoy!.members;
    notifyListeners();
    return convoy!;
  }

  Future<List<RouteOption>> fetchRouteOptions() => api.routeOptions(convoy!.code);

  Future<void> lockRoute(RouteOption chosen, List<Stop> stops) async {
    convoy = await api.lockRoute(convoy!.code, chosen: chosen, stops: stops);
    notifyListeners();
  }

  Future<void> updateActiveRoute({
    String? destLabel,
    double? destLat,
    double? destLng,
    List<PlaceDetails>? waypoints,
  }) async {
    if (convoy == null) return;
    final updated = await api.reroute(
      code: convoy!.code,
      destLabel: destLabel,
      destLat: destLat,
      destLng: destLng,
      waypoints: waypoints,
    );
    convoy = updated;
    notifyListeners();
  }

  /// Connects the socket, starts streaming this device's GPS position, and
  /// loads any pending proposals (host only) plus a cached snapshot of the
  /// convoy so the screen has something to show immediately even before
  /// the first live update arrives.
  Future<void> goLive() async {
    if (convoy == null || token == null) return;

    convoyEnded = false;

    await _loadCachedSnapshot();

    socket.connect(
      token: token!,
      convoyCode: convoy!.code,
      onRanked: (updatedMembers, _) {
        members = updatedMembers;
        _cacheSnapshot();
        _syncCarBridge();
        notifyListeners();
      },
      onPing: (message) {
        messages = [...messages, message];
        notifyListeners();
      },
      onStragglerAlert: (gapM) {
        stragglerGapM = gapM;
        _syncCarBridge();
        notifyListeners();
      },
      onRouteLocked: (updatedConvoy) {
        convoy = updatedConvoy;
        _syncCarBridge();
        notifyListeners();
      },
      onProposalNew: (proposal) {
        pendingProposals = [...pendingProposals, proposal];
        notifyListeners();
      },
      onProposalResolved: (proposal) {
        pendingProposals = pendingProposals.where((p) => p.id != proposal.id).toList();
        notifyListeners();
      },
      onConvoyEnded: () {
        convoyEnded = true;
        stopLive();
        notifyListeners();
      },
      onVoiceStatus: (transmittingUserId, transmittingUserName, isTransmitting) {
        if (transmittingUserId != userId) {
          if (isTransmitting) {
            activeTransmitterName = transmittingUserName;
            _transmitterResetTimer?.cancel();
            _transmitterResetTimer = Timer(const Duration(seconds: 15), () {
              activeTransmitterName = null;
              _syncCarBridge();
              notifyListeners();
            });
          } else {
            _transmitterResetTimer?.cancel();
            activeTransmitterName = null;
          }
          _syncCarBridge();
          notifyListeners();
        }
      },
      onVoiceReceive: (senderId, senderName, audioBase64, durationMs) {
        if (senderId != userId) {
          activeTransmitterName = senderName;
          _transmitterResetTimer?.cancel();
          _transmitterResetTimer = Timer(Duration(milliseconds: durationMs + 1000), () {
            activeTransmitterName = null;
            _syncCarBridge();
            notifyListeners();
          });
          walkieTalkie.playIncomingTransmission(audioBase64);
          _syncCarBridge();
          notifyListeners();
        }
      },
      onExpenseNew: (data) {
        final exp = Expense.fromJson(data['expense'] as Map<String, dynamic>);
        expenses = [exp, ...expenses.where((e) => e.id != exp.id)];
        if (data['person'] != null) {
          final p = ExpensePerson.fromJson(data['person'] as Map<String, dynamic>);
          if (!people.any((item) => item.name.toLowerCase() == p.name.toLowerCase())) {
            people = [...people, p];
          }
        }
        notifyListeners();
      },
      onExpenseDeleted: (id) {
        expenses = expenses.where((e) => e.id != id).toList();
        notifyListeners();
      },
      onPersonNew: (data) {
        final p = ExpensePerson.fromJson(data);
        if (!people.any((item) => item.name.toLowerCase() == p.name.toLowerCase())) {
          people = [...people, p];
          notifyListeners();
        }
      },
      onPersonDeleted: (id) {
        people = people.where((p) => p.id != id).toList();
        notifyListeners();
      },
      onPeopleReset: () {
        people = [];
        notifyListeners();
      },
      onCategoryUpdated: () {
        fetchExpenses();
      },
      onExpenseSessionCompleted: (data) {
        final session = ExpenseSession.fromJson(data);
        historySessions = [session, ...historySessions.where((s) => s.id != session.id)];
        expenses = [];
        people = [];
        markSessionCompleted(session);
      },
      onExpenseSessionDeleted: (id) {
        historySessions = historySessions.where((s) => s.id != id).toList();
        notifyListeners();
      },
      onConnected: () {
        isConnected = true;
        notifyListeners();
      },
      onDisconnected: () {
        isConnected = false;
        notifyListeners();
      },
    );

    walkieTalkie.init();
    fetchExpenses();

    location.getLastKnownPosition().then((pos) {
      if (pos != null && (currentLat == null || currentLng == null)) {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        socket.sendLocation(convoy!.code, pos.latitude, pos.longitude);
        notifyListeners();
      }
    });

    location.getCurrentPosition().then((pos) {
      if (pos != null) {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        socket.sendLocation(convoy!.code, pos.latitude, pos.longitude);
        notifyListeners();
      }
    });

    location.startStreaming((lat, lng) {
      currentLat = lat;
      currentLng = lng;
      socket.sendLocation(convoy!.code, lat, lng);
      notifyListeners();
    });

    if (isHost) {
      try {
        pendingProposals = await api.pendingProposals(convoy!.code);
        notifyListeners();
      } catch (_) {
        // Non-fatal — proposals will still arrive live via the socket.
      }
    }

    _staleTicker?.cancel();
    _staleTicker = Timer.periodic(const Duration(seconds: 5), (_) => notifyListeners());
  }

  void sendPing(String body, {String kind = 'text'}) {
    socket.sendPing(convoy!.code, body, kind: kind);
  }

  Future<void> proposeChange(String summary, {String? destLabel, double? destLat, double? destLng}) =>
      api.proposeChange(convoy!.code, summary: summary, destLabel: destLabel, destLat: destLat, destLng: destLng);

  /// Accepts or declines a pending proposal. If accepted with a new
  /// destination, the server re-locks the route automatically and the
  /// returned convoy (if any) replaces the local one immediately — the
  /// socket's `route:locked` broadcast will also arrive and is a no-op by
  /// then, but applying it here means the host doesn't wait on their own
  /// broadcast round-trip to see the update.
  Future<void> resolveProposal(RouteProposal proposal, {required bool accept}) async {
    final updatedConvoy = await api.resolveProposal(convoy!.code, proposal.id, accept: accept);
    pendingProposals = pendingProposals.where((p) => p.id != proposal.id).toList();
    if (updatedConvoy != null) convoy = updatedConvoy;
    notifyListeners();
  }

  /// Host-only: ends the convoy on the server and disconnects locally.
  Future<void> endConvoy() async {
    if (convoy == null) return;
    await api.endConvoy(convoy!.code);
    stopLive();
    convoy = null;
    convoyEnded = false;
    members = [];
    messages = [];
    pendingProposals = [];
    notifyListeners();
  }

  /// Client-only: leaves the live session locally without deleting the member
  /// record — the user can rejoin with the same code.
  void leaveConvoy() {
    stopLive();
    convoy = null;
    convoyEnded = false;
    members = [];
    messages = [];
    pendingProposals = [];
    notifyListeners();
  }

  Future<void> _cacheSnapshot() async {
    if (convoy == null) return;
    final prefs = await SharedPreferences.getInstance();
    final snapshot = {
      'code': convoy!.code,
      'name': convoy!.name,
      'members': members
          .map((m) => {
                'id': m.id,
                'userName': m.userName,
                'vehicleName': m.vehicleName,
                'isLead': m.isLead,
                'gapToLeadM': m.gapToLeadM,
                'lastPingAt': m.lastPingAt?.toIso8601String(),
              })
          .toList(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('lastConvoySnapshot', jsonEncode(snapshot));
  }

  /// Loads whatever the last live snapshot looked like, so if the socket
  /// takes a moment to connect (or fails entirely) the roster isn't just
  /// blank — it shows the last known state, clearly marked as stale via
  /// each member's own lastPingAt rather than a separate "cached" banner.
  Future<void> _loadCachedSnapshot() async {
    if (members.isNotEmpty) return; // already have live/session data
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lastConvoySnapshot');
    if (raw == null) return;
    try {
      final snapshot = jsonDecode(raw) as Map<String, dynamic>;
      if (snapshot['code'] != convoy?.code) return; // stale cache from a different trip
      members = (snapshot['members'] as List)
          .map((m) => ConvoyMember(
                id: m['id'],
                userId: '',
                userName: m['userName'] ?? '',
                role: 'client',
                vehicleName: m['vehicleName'] ?? '',
                passengers: 1,
                isLead: m['isLead'] ?? false,
                gapToLeadM: (m['gapToLeadM'] as num?)?.toDouble(),
                lastPingAt: m['lastPingAt'] != null ? DateTime.tryParse(m['lastPingAt']) : null,
              ))
          .toList();
      notifyListeners();
    } catch (_) {
      // Corrupt or outdated cache shape — ignore and wait for live data.
    }
  }

  /// Clears the session token and all cached data, returning the app to the
  /// unauthenticated state. Any active convoy session should be exited first.
  Future<void> logout() async {
    stopLive();
    token = null;
    userId = null;
    userName = null;
    userEmail = null;
    convoy = null;
    convoyEnded = false;
    members = [];
    messages = [];
    pendingProposals = [];
    api.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('lastConvoySnapshot');
    notifyListeners();
  }

  /// Updates the display name locally and in the server profile.
  Future<void> updateName(String newName) async {
    await api.updateProfile(name: newName);
    userName = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', newName);
    notifyListeners();
  }

  /// Updates the user's vehicle name and syncs with all members grouped in that vehicle.
  Future<void> updateMyVehicle(String newVehicleName) async {
    final code = convoy?.code;
    if (code == null) return;
    final trimmed = newVehicleName.trim();
    if (trimmed.isEmpty) return;

    socket.updateVehicle(code, trimmed);

    try {
      final updatedMember = await api.updateVehicle(code, vehicleName: trimmed);
      members = members.map((m) => m.id == updatedMember.id ? updatedMember : m).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('updateMyVehicle error: $e');
    }
  }

  void toggleRadioMute() {
    walkieTalkie.isMuted = !walkieTalkie.isMuted;
    _syncCarBridge();
    notifyListeners();
  }

  Future<void> startPushToTalk() async {
    if (convoy == null) return;
    final started = await walkieTalkie.startRecording();
    if (started) {
      isWalkieTalkieTransmitting = true;
      socket.sendVoiceStatus(convoy!.code, true);
      _syncCarBridge();
      notifyListeners();
    }
  }

  Future<void> stopPushToTalk() async {
    if (convoy == null || !isWalkieTalkieTransmitting) {
      await walkieTalkie.cancelRecording();
      return;
    }
    isWalkieTalkieTransmitting = false;
    socket.sendVoiceStatus(convoy!.code, false);
    _syncCarBridge();
    notifyListeners();

    final payload = await walkieTalkie.stopRecording();
    if (payload != null && convoy != null) {
      socket.sendVoiceTransmit(
        convoy!.code,
        payload['audioBase64'] as String,
        payload['durationMs'] as int,
      );
    }
  }

  Future<void> cancelPushToTalk() async {
    if (convoy == null || !isWalkieTalkieTransmitting) return;
    isWalkieTalkieTransmitting = false;
    socket.sendVoiceStatus(convoy!.code, false);
    await walkieTalkie.cancelRecording();
    _syncCarBridge();
    notifyListeners();
  }

  /// Fetches expenses, people, and categories from backend
  Future<void> fetchExpenses({String? convoyCode}) async {
    final code = convoyCode ?? convoy?.code;
    isLoadingExpenses = true;
    notifyListeners();
    try {
      final res = await api.fetchExpensesData(convoyCode: code);
      expenses = (res['expenses'] as List).map((e) => Expense.fromJson(e)).toList();
      people = (res['people'] as List).map((p) => ExpensePerson.fromJson(p)).toList();
      categories = (res['categories'] as List).map((c) => ExpenseCategoryItem.fromJson(c)).toList();
    } catch (e) {
      debugPrint('fetchExpenses error: $e');
    } finally {
      isLoadingExpenses = false;
      notifyListeners();
    }
  }

  Future<Expense> addExpense({
    required String title,
    required double amount,
    required String categoryName,
    String? categoryId,
    required String paidByName,
    String? personId,
  }) async {
    final created = await api.createExpense(
      title: title,
      amount: amount,
      categoryName: categoryName,
      categoryId: categoryId,
      paidByName: paidByName,
      personId: personId,
      convoyCode: convoy?.code,
    );
    expenses = [created, ...expenses.where((e) => e.id != created.id)];
    if (!people.any((p) => p.name.toLowerCase() == paidByName.toLowerCase())) {
      people = [...people, ExpensePerson(id: personId ?? created.id, name: paidByName)];
    }
    notifyListeners();
    return created;
  }

  Future<void> deleteExpense(String id) async {
    await api.deleteExpense(id);
    expenses = expenses.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<ExpensePerson> addPerson(String name) async {
    final person = await api.addPerson(name: name, convoyCode: convoy?.code);
    if (!people.any((p) => p.name.toLowerCase() == person.name.toLowerCase())) {
      people = [...people, person];
      notifyListeners();
    }
    return person;
  }

  Future<void> deletePerson(String id) async {
    await api.deletePerson(id);
    people = people.where((p) => p.id != id).toList();
    notifyListeners();
  }

  Future<ExpenseCategoryItem> addCategory(String name, String icon) async {
    final cat = await api.addCategory(name: name, icon: icon, convoyCode: convoy?.code);
    categories = [...categories, cat];
    notifyListeners();
    return cat;
  }

  Future<ExpenseCategoryItem> editCategory(String id, String name, {String? icon}) async {
    final updated = await api.editCategory(id: id, name: name, icon: icon);
    categories = categories.map((c) => c.id == id ? updated : c).toList();
    expenses = expenses.map((e) => e.categoryId == id ? Expense(
      id: e.id,
      title: e.title,
      amount: e.amount,
      categoryName: updated.name,
      categoryId: e.categoryId,
      paidByName: e.paidByName,
      personId: e.personId,
      convoyId: e.convoyId,
      createdAt: e.createdAt,
    ) : e).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteCategory(String id) async {
    await api.deleteCategory(id);
    categories = categories.where((c) => c.id != id).toList();
    notifyListeners();
  }

  Future<void> fetchExpenseHistory({String? convoyCode}) async {
    final code = convoyCode ?? convoy?.code;
    isLoadingHistory = true;
    notifyListeners();
    try {
      historySessions = await api.fetchExpenseHistory(convoyCode: code);
    } catch (e) {
      debugPrint('fetchExpenseHistory error: $e');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<ExpenseSession> completeExpenseSession(String name) async {
    final session = await api.completeExpenseSession(
      name: name,
      convoyCode: convoy?.code,
    );
    historySessions = [session, ...historySessions.where((s) => s.id != session.id)];
    expenses = [];
    people = [];
    markSessionCompleted(session);
    return session;
  }

  Future<void> deleteHistorySession(String id) async {
    await api.deleteExpenseSession(id);
    historySessions = historySessions.where((s) => s.id != id).toList();
    notifyListeners();
  }

  void stopLive() {
    location.stop();
    socket.dispose();
    walkieTalkie.dispose();
    carBridge.clearCarState();
    _transmitterResetTimer?.cancel();
    activeTransmitterName = null;
    isWalkieTalkieTransmitting = false;
    _staleTicker?.cancel();
    _staleTicker = null;
    _recentlyCompletedTimer?.cancel();
    _recentlyCompletedTimer = null;
    recentlyCompletedSession = null;
  }

  @override
  void dispose() {
    stopLive();
    super.dispose();
  }
}
