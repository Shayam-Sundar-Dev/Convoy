import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/convoy.dart';
import 'api_service.dart';

/// Wraps the Socket.IO connection used for everything that needs to be
/// live: location pings going out, and ranked convoy state / pings /
/// straggler alerts / route-lock / proposal notifications coming back in.
class SocketService {
  io.Socket? _socket;

  void connect({
    required String token,
    required String convoyCode,
    required void Function(List<ConvoyMember> members, String? updatedMemberId) onRanked,
    required void Function(ConvoyMessage message) onPing,
    required void Function(double gapToLeadM) onStragglerAlert,
    required void Function(Convoy convoy) onRouteLocked,
    required void Function(RouteProposal proposal) onProposalNew,
    required void Function(RouteProposal proposal) onProposalResolved,
    required void Function() onConvoyEnded,
    required void Function(String senderId, String senderName, String audioBase64, int durationMs) onVoiceReceive,
    required void Function(String userId, String userName, bool isTransmitting) onVoiceStatus,
    required void Function(Map<String, dynamic> data) onExpenseNew,
    required void Function(String expenseId) onExpenseDeleted,
    required void Function(Map<String, dynamic> data) onPersonNew,
    void Function(String personId)? onPersonDeleted,
    void Function()? onPeopleReset,
    required void Function() onCategoryUpdated,
    void Function(Map<String, dynamic> data)? onExpenseSessionCompleted,
    void Function(String sessionId)? onExpenseSessionDeleted,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    final socket = _socket!;
    socket.connect();

    socket.onConnect((_) {
      socket.emit('convoy:enter', {'code': convoyCode});
      onConnected();
    });
    socket.onDisconnect((_) => onDisconnected());
    socket.onConnectError((_) => onDisconnected());
    socket.onReconnect((_) {
      // Re-enter the convoy room; Socket.IO gives us a new underlying
      // connection on reconnect, which starts in no rooms.
      socket.emit('convoy:enter', {'code': convoyCode});
      onConnected();
    });

    socket.on('convoy:ranked', (data) {
      final members = (data['members'] as List)
          .map((m) => ConvoyMember.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      onRanked(members, data['updatedMemberId'] as String?);
    });

    socket.on('ping:new', (data) => onPing(ConvoyMessage.fromJson(Map<String, dynamic>.from(data))));

    socket.on('convoy:straggler-alert', (data) {
      onStragglerAlert((data['gapToLeadM'] as num).toDouble());
    });

    socket.on('route:locked', (data) => onRouteLocked(Convoy.fromJson(Map<String, dynamic>.from(data))));

    socket.on('proposal:new', (data) => onProposalNew(RouteProposal.fromJson(Map<String, dynamic>.from(data))));
    socket.on('proposal:resolved', (data) => onProposalResolved(RouteProposal.fromJson(Map<String, dynamic>.from(data))));

    // Fired by the server when the host explicitly ends the convoy.
    socket.on('convoy:ended', (_) => onConvoyEnded());

    // Walkie-Talkie events
    socket.on('voice:status', (data) {
      onVoiceStatus(
        data['userId'] as String? ?? '',
        data['userName'] as String? ?? 'Driver',
        data['isTransmitting'] as bool? ?? false,
      );
    });

    socket.on('voice:receive', (data) {
      onVoiceReceive(
        data['senderId'] as String? ?? '',
        data['senderName'] as String? ?? 'Driver',
        data['audioBase64'] as String? ?? '',
        data['durationMs'] as int? ?? 0,
      );
    });

    // Expense & Category events
    socket.on('expense:new', (data) {
      onExpenseNew(Map<String, dynamic>.from(data));
    });

    socket.on('expense:deleted', (data) {
      onExpenseDeleted(data['id'] as String? ?? '');
    });

    socket.on('person:new', (data) {
      onPersonNew(Map<String, dynamic>.from(data));
    });

    socket.on('person:deleted', (data) {
      if (onPersonDeleted != null) {
        onPersonDeleted(data['id'] as String? ?? '');
      }
    });

    socket.on('expense:people_reset', (_) {
      if (onPeopleReset != null) {
        onPeopleReset();
      }
    });

    socket.on('category:new', (_) => onCategoryUpdated());
    socket.on('category:updated', (_) => onCategoryUpdated());
    socket.on('category:deleted', (_) => onCategoryUpdated());

    socket.on('expense:session_completed', (data) {
      if (onExpenseSessionCompleted != null) {
        onExpenseSessionCompleted(Map<String, dynamic>.from(data));
      }
    });

    socket.on('expense:session_deleted', (data) {
      if (onExpenseSessionDeleted != null) {
        onExpenseSessionDeleted(data['id'] as String? ?? '');
      }
    });
  }

  /// Report a raw GPS fix. The server projects it onto the locked route and
  /// broadcasts the recalculated lead/gap ranking to the whole convoy.
  void sendLocation(String code, double lat, double lng) {
    _socket?.emit('location:ping', {'code': code, 'lat': lat, 'lng': lng});
  }

  void sendPing(String code, String body, {String kind = 'text'}) {
    _socket?.emit('ping:send', {'code': code, 'body': body, 'kind': kind});
  }

  void updateVehicle(String code, String vehicleName) {
    _socket?.emit('member:update-vehicle', {'code': code, 'vehicleName': vehicleName});
  }

  void sendVoiceStatus(String code, bool isTransmitting) {
    _socket?.emit('voice:status', {'code': code, 'isTransmitting': isTransmitting});
  }

  void sendVoiceTransmit(String code, String audioBase64, int durationMs) {
    _socket?.emit('voice:transmit', {
      'code': code,
      'audioBase64': audioBase64,
      'durationMs': durationMs,
    });
  }

  bool get isConnected => _socket?.connected ?? false;

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
