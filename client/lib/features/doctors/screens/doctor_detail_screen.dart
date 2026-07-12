import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import '../../payments/providers/payment_provider.dart';
import '../providers/doctor_detail_provider.dart';
import '../../appointments/providers/booking_provider.dart';

class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen>
    with WidgetsBindingObserver {
  Slot? _selectedSlot;
  final _reasonController = TextEditingController();
  bool _booking = false;
  String? _pendingPidx;
  bool _checkingPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingPidx != null) {
      _checkPendingPayment();
    }
  }

  Future<void> _checkPendingPayment() async {
    final pidx = _pendingPidx;
    if (pidx == null || _checkingPending) return;
    setState(() => _checkingPending = true);
    try {
      final result = await ref.read(paymentControllerProvider).verify(pidx);
      if (result['status'] == 'success') {
        _pendingPidx = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Appointment confirmed.'),
            ),
          );
          Navigator.pop(context);
        }
      } else if (result['status'] == 'failed') {
        _pendingPidx = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment was not completed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment not confirmed yet. Try again in a moment.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingPending = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) return;
    setState(() => _booking = true);
    try {
      final initiateData = await ref
          .read(paymentControllerProvider)
          .initiate(
            doctorId: widget.doctorId,
            start: _selectedSlot!.start,
            end: _selectedSlot!.end,
            reason: _reasonController.text.trim(),
          );
      final pidx = initiateData['pidx'];
      final paymentUrl = initiateData['payment_url'];
      _pendingPidx = pidx;

      final payConfig = KhaltiPayConfig(
        publicKey: '7a2e21b7eb0d4c348ad814d611c0bd22',
        pidx: pidx,
        paymentUrl: paymentUrl,
        environment: Environment.test,
      );

      final khalti = await Khalti.init(
        enableDebugging: true,
        payConfig: payConfig,
        onPaymentResult: (paymentResult, khalti) async {
          khalti.close(context);
          _pendingPidx = null;
          try {
            await ref.read(paymentControllerProvider).verify(pidx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment successful! Appointment confirmed.'),
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment verification failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onMessage:
            (
              khalti, {
              description,
              statusCode,
              event,
              needsPaymentConfirmation,
            }) async {
              if (needsPaymentConfirmation == true) {
                await khalti.verify();
                return;
              }
              khalti.close(context);
              if (!mounted) return;

              if (event == KhaltiEvent.kpgDisposed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Checkout closed. Checking payment status...',
                    ),
                  ),
                );
                _checkPendingPayment();
              } else {
                _pendingPidx = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment failed: ${description ?? 'Unknown error'}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
      );

      if (!mounted) return;
      khalti.open(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorAsync = ref.watch(doctorDetailProvider(widget.doctorId));
    final selectedDate = ref.watch(selectedDateProvider);
    final slotsAsync = ref.watch(availableSlotsProvider(widget.doctorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Profile')),
      body: doctorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (doctor) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: doctor.avatarUrl != null
                        ? NetworkImage(doctor.avatarUrl!)
                        : null,
                    child: doctor.avatarUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${doctor.fullName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialties.isNotEmpty
                              ? doctor.specialties.map((s) => s.name).join(', ')
                              : 'General Physician',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.averageRating.toStringAsFixed(1)} (${doctor.totalReviews} reviews)',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${doctor.yearsExperience} years experience'),
                  Text(
                    'Rs. ${doctor.consultationFee.toStringAsFixed(0)} / visit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 32),

              const Text(
                'Select Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 14,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected =
                        date.year == selectedDate.year &&
                        date.month == selectedDate.month &&
                        date.day == selectedDate.day;
                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedDateProvider.notifier).state = date;
                        setState(() => _selectedSlot = null);
                      },
                      child: Container(
                        width: 56,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                            Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Available Slots',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              slotsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (slots) {
                  if (slots.isEmpty) {
                    return const Text('No slots available on this date');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots.map((slot) {
                      final isSelected = _selectedSlot?.start == slot.start;
                      return ChoiceChip(
                        label: Text(DateFormat('h:mm a').format(slot.start)),
                        selected: isSelected,
                        onSelected: slot.isAvailable
                            ? (_) => setState(() => _selectedSlot = slot)
                            : null,
                        backgroundColor: slot.isAvailable
                            ? null
                            : Colors.grey.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: slot.isAvailable ? null : Colors.grey,
                          decoration: slot.isAvailable
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),

              if (_selectedSlot != null) ...[
                const Text(
                  'Reason for visit (optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Briefly describe your concern',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _booking ? null : _confirmBooking,
                    child: _booking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Book & Pay for ${DateFormat('MMM d, h:mm a').format(_selectedSlot!.start)}',
                          ),
                  ),
                ),
              ],

              if (_pendingPidx != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkingPending ? null : _checkPendingPayment,
                    icon: _checkingPending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Check Payment Status'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
