from datetime import datetime, timedelta
from doctors.models import DoctorAvailability, DoctorAvailabilityException
from .models import Appointment

def get_available_slots(doctor_id, date):
    """
    Returns a list of (start, end) datetime tuples for a given doctor + date,
    combining weekly recurring availability, exceptions, and existing appointments.
    """
    day_of_week = date.weekday()  # Python: Mon=0..Sun=6
    day_of_week = (day_of_week + 1) % 7  # convert to schema's Sun=0..Sat=6

    # 1. Check for a full-day block exception first
    blocking_exception = DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=True,
        start_time__isnull=True,  # null start/end = whole day blocked
    ).exists()
    if blocking_exception:
        return []

    # 2. Base recurring windows for this weekday
    windows = list(DoctorAvailability.objects.filter(
        doctor_id=doctor_id, day_of_week=day_of_week, is_active=True
    ).values('start_time', 'end_time', 'slot_duration_minutes'))

    # 3. Add extra one-off availability windows for this date
    extra = DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=False,
        start_time__isnull=False, end_time__isnull=False,
    )
    for ex in extra:
        windows.append({'start_time': ex.start_time, 'end_time': ex.end_time, 'slot_duration_minutes': 15})

    # 4. Subtract partial-day block exceptions
    partial_blocks = list(DoctorAvailabilityException.objects.filter(
        doctor_id=doctor_id, date=date, is_unavailable=True,
        start_time__isnull=False, end_time__isnull=False,
    ).values('start_time', 'end_time'))

    # 5. Generate candidate slots from windows
    candidate_slots = []
    for w in windows:
        slot_len = timedelta(minutes=w['slot_duration_minutes'])
        cursor = datetime.combine(date, w['start_time'])
        window_end = datetime.combine(date, w['end_time'])
        while cursor + slot_len <= window_end:
            slot_start, slot_end = cursor, cursor + slot_len
            blocked = any(
                datetime.combine(date, pb['start_time']) < slot_end and
                datetime.combine(date, pb['end_time']) > slot_start
                for pb in partial_blocks
            )
            if not blocked:
                candidate_slots.append((slot_start, slot_end))
            cursor += slot_len

    # 6. Remove slots that overlap existing non-cancelled appointments
    existing = Appointment.objects.filter(
        doctor_id=doctor_id,
        scheduled_start__date=date,
    ).exclude(status__in=['cancelled', 'rejected'])

    booked_ranges = [(a.scheduled_start, a.scheduled_end) for a in existing]

    free_slots = [
        (s, e) for s, e in candidate_slots
        if not any(s < be and e > bs for bs, be in booked_ranges)
    ]

    return free_slots