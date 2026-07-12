from datetime import datetime, timedelta
from django.utils import timezone
from doctors.models import DoctorAvailability, DoctorAvailabilityException
from .models import Appointment

def get_available_slots(doctor_id, date):
    day_of_week = date.weekday()
    day_of_week = (day_of_week + 1) % 7

    blocking_exception = DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=True,
        start_time__isnull=True,
    ).exists()
    if blocking_exception:
        return []

    windows = list(DoctorAvailability.objects.filter(
        doctor_id=doctor_id, day_of_week=day_of_week, is_active=True
    ).values('start_time', 'end_time', 'slot_duration_minutes'))

    extra = DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=False,
        start_time__isnull=False, end_time__isnull=False,
    )
    for ex in extra:
        windows.append({'start_time': ex.start_time, 'end_time': ex.end_time, 'slot_duration_minutes': 15})

    partial_blocks = list(DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=True,
        start_time__isnull=False, end_time__isnull=False,
    ).values('start_time', 'end_time'))

    candidate_slots = []
    for w in windows:
        slot_len = timedelta(minutes=w['slot_duration_minutes'])
        # make_aware() attaches the current Django TIME_ZONE — matches how
        # DRF parses incoming ISO datetimes, so equality checks work correctly
        cursor = timezone.make_aware(datetime.combine(date, w['start_time']))
        window_end = timezone.make_aware(datetime.combine(date, w['end_time']))
        while cursor + slot_len <= window_end:
            slot_start, slot_end = cursor, cursor + slot_len
            blocked = any(
                timezone.make_aware(datetime.combine(date, pb['start_time'])) < slot_end and
                timezone.make_aware(datetime.combine(date, pb['end_time'])) > slot_start
                for pb in partial_blocks
            )
            if not blocked:
                candidate_slots.append((slot_start, slot_end))
            cursor += slot_len

    existing = Appointment.objects.filter(
        doctor_id=doctor_id,
        scheduled_start__date=date,
    ).exclude(status__in=['cancelled', 'rejected'])

    booked_ranges = [(a.scheduled_start, a.scheduled_end) for a in existing]

    all_slots = []
    for s, e in candidate_slots:
        is_booked = any(s < be and e > bs for bs, be in booked_ranges)
        all_slots.append({'start': s, 'end': e, 'is_available': not is_booked})

    return all_slots