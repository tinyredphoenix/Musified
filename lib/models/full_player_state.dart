import 'package:audio_service/audio_service.dart';
import 'package:musified/models/position_data.dart';

class FullPlayerState {
  FullPlayerState({
    required this.playbackState,
    required this.queue,
    required this.position,
  });
  final PlaybackState playbackState;
  final List<MediaItem> queue;
  final PositionData position;
}
