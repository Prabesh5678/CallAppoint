import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/artifact_provider.dart';
import '../../appointments/widgets/create_artifact_dialog.dart';
import '../../appointments/widgets/schedule_followup_dialog.dart';

class CallControls extends ConsumerWidget {
  final String appointmentId;
  final bool micEnabled;
  final bool camEnabled;
  final bool showStatsOverlay;
  final bool showArtifacts;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;
  final VoidCallback onToggleStats;
  final VoidCallback onToggleArtifacts;
  final VoidCallback onHangUp;

  const CallControls({
    super.key,
    required this.appointmentId,
    required this.micEnabled,
    required this.camEnabled,
    required this.showStatsOverlay,
    required this.showArtifacts,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onToggleStats,
    required this.onToggleArtifacts,
    required this.onHangUp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(currentUserProfileProvider).valueOrNull?['role'];
    final isDoctor = userRole == 'doctor';

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.black26,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ControlButton(
                icon: showStatsOverlay ? Icons.analytics : Icons.analytics_outlined,
                color: showStatsOverlay ? Colors.blueAccent : Colors.white12,
                onPressed: onToggleStats,
              ),
              _ControlButton(
                icon: micEnabled ? Icons.mic : Icons.mic_off,
                color: micEnabled ? Colors.white12 : Colors.redAccent,
                onPressed: onToggleMic,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FloatingActionButton(
                  heroTag: 'hangup_btn',
                  elevation: 0,
                  mini: false,
                  backgroundColor: Colors.red,
                  onPressed: onHangUp,
                  child: const Icon(Icons.call_end, size: 28),
                ),
              ),
              _ControlButton(
                icon: camEnabled ? Icons.videocam : Icons.videocam_off,
                color: camEnabled ? Colors.white12 : Colors.redAccent,
                onPressed: onToggleCam,
              ),
              _ControlButton(
                icon: Icons.list_alt,
                color: showArtifacts ? Colors.blueAccent : Colors.white12,
                onPressed: onToggleArtifacts,
              ),
              if (isDoctor)
                _ControlButton(
                  icon: Icons.note_add,
                  color: Colors.greenAccent.withOpacity(0.2),
                  onPressed: () async {
                    final success = await showDialog<bool>(
                      context: context,
                      builder: (context) => CreateArtifactDialog(
                        appointmentId: appointmentId,
                      ),
                    );
                    if (success == true) {
                      ref.invalidate(appointmentArtifactsProvider(appointmentId));
                    }
                  },
                ),
              if (isDoctor)
                _ControlButton(
                  icon: Icons.event_repeat,
                  color: Colors.purpleAccent.withOpacity(0.2),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ScheduleFollowupDialog(
                        parentAppointmentId: appointmentId,
                        doctorId: ref.read(currentUserProfileProvider).value!['id'],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: RawMaterialButton(
        onPressed: onPressed,
        elevation: 0,
        fillColor: color,
        shape: const CircleBorder(),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
