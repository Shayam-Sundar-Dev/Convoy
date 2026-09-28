import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class WalkieTalkieService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  DateTime? _recordStartTime;
  bool isMuted = false;

  bool get isRecording => _isRecording;

  Future<void> init() async {
    // Set audio to speakerphone by default so it can be heard while driving
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistanceNavigationGuidance,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('WalkieTalkie AudioContext setup: $e');
    }
  }

  /// Start recording voice when PTT button is held down.
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/convoy_ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 48000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: filePath,
      );

      _isRecording = true;
      _recordStartTime = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('WalkieTalkie startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording voice and return base64 encoded audio bytes + duration.
  Future<Map<String, dynamic>?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      final duration = _recordStartTime != null
          ? DateTime.now().difference(_recordStartTime!).inMilliseconds
          : 0;

      // Ignore ultra-short accidental taps (< 300ms)
      if (duration < 300 || path == null) {
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
        return null;
      }

      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      await file.delete().catchError((_) => file);

      return {
        'audioBase64': base64Encode(bytes),
        'durationMs': duration,
      };
    } catch (e) {
      debugPrint('WalkieTalkie stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without transmitting
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      _isRecording = false;
    }
  }

  /// Play incoming voice transmission from another convoy member
  Future<void> playIncomingTransmission(String audioBase64) async {
    if (isMuted) return;

    try {
      final bytes = base64Decode(audioBase64);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('WalkieTalkie playback error: $e');
    }
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
