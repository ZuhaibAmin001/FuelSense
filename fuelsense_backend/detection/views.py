from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
import json, math
from django.db import IntegrityError, transaction
from .models import Station, QueueStatus, UserProfile, FuelTransaction, Employee
from . import otp_service

DETECTION_API_KEY = getattr(settings, 'DETECTION_API_KEY', 'fuelsense2024')

FUEL_PRICES = {
    'PETROL': 272,
    'DIESEL': 293,
    'KEROSENE': 187,
}

def haversine(lat1, lng1, lat2, lng2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def _digits(value):
    return ''.join(ch for ch in str(value or '') if ch.isdigit())


def _normalize_phone(raw):
    """Store every number in the local 03XXXXXXXXX form."""
    digits = _digits(raw)
    if digits.startswith('92'):
        digits = '0' + digits[2:]
    elif digits and not digits.startswith('0'):
        digits = '0' + digits
    return digits


def _phone_variants(phone):
    """Every form a phone number may have been saved under.

    Lets members who registered before numbers were normalised still sign in.
    """
    digits = _digits(phone)
    local = _normalize_phone(digits)
    candidates = [phone, digits, local]
    if len(local) == 11:
        candidates += [local[1:], '92' + local[1:], '+92' + local[1:]]
    seen, ordered = set(), []
    for candidate in candidates:
        if candidate and candidate not in seen:
            seen.add(candidate)
            ordered.append(candidate)
    return ordered


def _login_candidates(identifier):
    """Usernames to try, in order, for a phone number or email address."""
    identifier = identifier.strip()
    if '@' in identifier:
        profile = UserProfile.objects.filter(email__iexact=identifier).select_related('user').first()
        return [profile.user.username] if profile else [identifier]
    variants = _phone_variants(identifier)
    stored = list(User.objects.filter(username__in=variants).values_list('username', flat=True))
    return stored or [identifier]


def _otp_response(record, delivered, failure, message):
    """Shared response for the two `send code` endpoints.

    With OTP_DEV_MODE on the code travels back in the response so the flow can
    be tested without a working mailbox; with it off a delivery failure is a
    hard error instead of a silent one.
    """
    if not delivered and not getattr(settings, 'OTP_DEV_MODE', False):
        return JsonResponse({'error': f'Could not send the email. {failure}'}, status=502)
    payload = {'message': message}
    code = otp_service.dev_code(record)
    if code:
        payload['dev_otp'] = code
        if not delivered:
            payload['warning'] = f'Email delivery failed ({failure}). OTP_DEV_MODE is on, so the code is in this response.'
    return JsonResponse(payload)


def _tokens(user):
    refresh = RefreshToken.for_user(user)
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


def _get_trend(station):
    statuses = QueueStatus.objects.filter(station=station).order_by('-timestamp')[:2]
    if len(statuses) < 2:
        return 'STABLE', 0
    current = statuses[0].vehicle_count
    previous = statuses[1].vehicle_count
    diff = current - previous
    if current > previous * 1.3:
        return 'GROWING', diff
    elif current < previous * 0.7:
        return 'SHRINKING', diff
    else:
        return 'STABLE', diff


def _seconds_ago(timestamp):
    if not timestamp:
        return None
    diff = (timezone.now() - timestamp).total_seconds()
    if diff < 60:
        return f"{int(diff)} seconds ago"
    elif diff < 3600:
        return f"{int(diff // 60)} min ago"
    else:
        return f"{int(diff // 3600)} hr ago"


@api_view(['POST'])
@permission_classes([AllowAny])
def send_signup_otp(request):
    """Email a 6-digit verification code to a new signup."""
    email = (request.data.get('email') or '').strip().lower()
    if '@' not in email or '.' not in email.split('@')[-1]:
        return JsonResponse({'error': 'Enter a valid email address'}, status=400)
    if UserProfile.objects.filter(email__iexact=email).exists():
        return JsonResponse({'error': 'That email is already registered'}, status=400)

    record = otp_service.issue(email, otp_service.PURPOSE_SIGNUP)
    delivered, failure = otp_service.deliver(record)
    return _otp_response(record, delivered, failure, f'Verification code sent to {email}')


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_signup_otp(request):
    """Check a signup code without consuming it - signup consumes it.

    Re-checking at signup keeps the code single-use while still letting the app
    confirm the address before asking for a password.
    """
    email = (request.data.get('email') or '').strip().lower()
    code = (request.data.get('otp') or '').strip()
    record, error = otp_service.check(email, code, otp_service.PURPOSE_SIGNUP)
    if error:
        return JsonResponse({'error': error}, status=400)
    return JsonResponse({'verified': True, 'email': email})


@api_view(['POST'])
@permission_classes([AllowAny])
def request_password_reset(request):
    email = (request.data.get('email') or '').strip().lower()
    if '@' not in email or '.' not in email.split('@')[-1]:
        return JsonResponse({'error': 'Enter a valid email address'}, status=400)
    if not UserProfile.objects.filter(email__iexact=email).exists():
        return JsonResponse({'error': 'No account found with this email'}, status=404)
    last = OTPRecord.objects.filter(email=email, purpose='RESET').order_by('-created_at').first()
    if last and (timezone.now() - last.created_at).total_seconds() < 60:
        wait = 60 - int((timezone.now() - last.created_at).total_seconds())
        return JsonResponse({'error': f'Please wait {wait}s before requesting another OTP'}, status=429)
    OTPRecord.objects.filter(email=email, purpose='RESET', is_used=False).update(is_used=True)
    
    if not UserProfile.objects.filter(email__iexact=email).exists():
        return JsonResponse({'error': 'No account found with this email'}, status=404)

    record = otp_service.issue(email, otp_service.PURPOSE_RESET)
    delivered, failure = otp_service.deliver(record)
    return _otp_response(record, delivered, failure, f'Reset code sent to {email}')


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    email        = (request.data.get('email') or '').strip().lower()
    code         = (request.data.get('otp') or '').strip()
    new_password = request.data.get('new_password') or ''
    if not all([email, code, new_password]):
        return JsonResponse({'error': 'Email, code and new password are required'}, status=400)
    if len(new_password) < 8:
        return JsonResponse({'error': 'Password must be at least 8 characters'}, status=400)

    record, error = otp_service.check(email, code, otp_service.PURPOSE_RESET)
    if error:
        return JsonResponse({'error': error}, status=400)

    profile = UserProfile.objects.filter(email__iexact=email).select_related('user').first()
    if profile is None:
        return JsonResponse({'error': 'No account found with this email'}, status=404)

    user = profile.user
    user.set_password(new_password)
    user.save(update_fields=['password'])
    otp_service.consume(record)
    return JsonResponse({'message': 'Password reset successful'})


@api_view(['POST'])
@permission_classes([AllowAny])
def signup(request):
    """Create an account. Requires the 6-digit code emailed to the address.

    The code is checked here as well as at verify-signup-otp, and is consumed
    only once the account has actually been created, so a failed signup never
    costs the member their code.
    """
    data      = request.data
    full_name = (data.get('full_name') or '').strip()
    phone     = _normalize_phone(data.get('phone'))
    cnic      = _digits(data.get('cnic'))
    password  = data.get('password') or ''
    email     = (data.get('email') or '').strip().lower()
    code      = (data.get('otp') or '').strip()

    if not all([full_name, phone, cnic, password, email, code]):
        return JsonResponse(
            {'error': 'Name, phone, email, CNIC, password and the verification code are all required'},
            status=400,
        )
    if len(phone) != 11:
        return JsonResponse({'error': 'Enter a valid 11-digit phone number'}, status=400)
    if len(cnic) != 13:
        return JsonResponse({'error': 'CNIC must be 13 digits'}, status=400)
    if len(password) < 8:
        return JsonResponse({'error': 'Password must be at least 8 characters'}, status=400)

    record, error = otp_service.check(email, code, otp_service.PURPOSE_SIGNUP)
    if error:
        return JsonResponse({'error': error}, status=400)

    if UserProfile.objects.filter(phone__in=_phone_variants(phone)).exists():
        return JsonResponse({'error': 'That phone number is already registered'}, status=400)
    if UserProfile.objects.filter(cnic=cnic).exists():
        return JsonResponse({'error': 'That CNIC is already registered'}, status=400)
    if UserProfile.objects.filter(email__iexact=email).exists():
        return JsonResponse({'error': 'That email is already registered'}, status=400)

    parts      = full_name.split(' ', 1)
    role       = data.get('role', 'driver')
    station_id = data.get('station_id')
    is_owner   = (role == 'owner' and station_id is not None)

    try:
        with transaction.atomic():
            user = User.objects.create_user(
                username=phone, password=password, email=email,
                first_name=parts[0], last_name=parts[1] if len(parts) > 1 else '',
            )
            # is_phone_verified stays False: the phone number is not verified,
            # the email address is, and that is what the OTP record proves.
            UserProfile.objects.create(
                user=user, phone=phone, cnic=cnic, email=email,
                is_station_owner=is_owner,
                owned_station_id=station_id if is_owner else None,
            )
            otp_service.consume(record)
    except IntegrityError:
        return JsonResponse({'error': 'That phone number, CNIC or email is already registered'}, status=400)

    return JsonResponse({'message': 'Account created', 'user_id': user.id, **_tokens(user)}, status=201)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    """Sign in with a phone number or an email address."""
    identifier = (request.data.get('identifier') or request.data.get('phone') or '').strip()
    password   = request.data.get('password') or ''
    if not identifier or not password:
        return JsonResponse({'error': 'Phone/email and password are required'}, status=400)

    user = None
    for username in _login_candidates(identifier):
        user = authenticate(username=username, password=password)
        if user is not None:
            break
    if user is None:
        return JsonResponse({'error': 'Incorrect phone/email or password'}, status=401)
    if not user.is_active:
        return JsonResponse({'error': 'This account has been disabled'}, status=403)

    profile = UserProfile.objects.filter(user=user).first()
    if profile is None:
        return JsonResponse({'error': 'Account setup is incomplete'}, status=400)

    return JsonResponse({
        'user_id': user.id,
        'full_name': user.get_full_name(),
        'phone': profile.phone,
        'email': profile.email,
        'is_station_owner': profile.is_station_owner,
        'owned_station_id': profile.owned_station_id,
        **_tokens(user),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_profile(request):
    p = request.user.profile
    return JsonResponse({
        'user_id': request.user.id,
        'full_name': request.user.get_full_name(),
        'phone': p.phone,
        'email': p.email,
        'is_station_owner': p.is_station_owner,
        'owned_station_id': p.owned_station_id,
    })


@csrf_exempt
def update_queue(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    if data.get('api_key') != DETECTION_API_KEY:
        return JsonResponse({'error': 'Invalid API key'}, status=403)
    try:
        station = Station.objects.get(id=data['station_id'])
    except Station.DoesNotExist:
        return JsonResponse({'error': f"Station {data['station_id']} not found"}, status=404)
    count = int(data.get('vehicle_count', 0))
    qs    = QueueStatus.objects.create(station=station, vehicle_count=count)
    return JsonResponse({'status': 'ok', 'station': station.name, 'vehicles': count, 'congestion': qs.congestion_level})


@api_view(['GET'])
@permission_classes([AllowAny])
def traffic_status(request):
    stations = Station.objects.filter(is_active=True)
    result = []
    for s in stations:
        latest = QueueStatus.objects.filter(station=s).first()
        count  = latest.vehicle_count if latest else 0
        level  = latest.congestion_level if latest else 'GREEN'
        trend, diff = _get_trend(s)
        statuses = QueueStatus.objects.filter(station=s).order_by('-timestamp')[:2]
        prev_count = statuses[1].vehicle_count if len(statuses) >= 2 else count
        result.append({
            'id': s.id,
            'name': s.name,
            'lat': s.lat,
            'lng': s.lng,
            'address': s.address,
            'vehicles': count,
            'previous_vehicles': prev_count,
            'status': level,
            'trend': trend,
            'trend_diff': diff,
            'wait_minutes': (count * 2) // max(s.total_pumps, 1),
            'total_pumps': s.total_pumps,
            'last_updated': _seconds_ago(latest.timestamp if latest else None),
            'has_fuel': True,
            'fuel_prices': FUEL_PRICES,
        })
    return JsonResponse(result, safe=False)


@api_view(['GET'])
@permission_classes([AllowAny])
def nearby_stations(request):
    lat    = float(request.GET.get('lat', 33.6844))
    lng    = float(request.GET.get('lng', 73.0479))
    radius = float(request.GET.get('radius', 10))
    result = []
    for s in Station.objects.filter(is_active=True):
        dist = haversine(lat, lng, s.lat, s.lng)
        if dist <= radius:
            latest = QueueStatus.objects.filter(station=s).first()
            count  = latest.vehicle_count if latest else 0
            level  = latest.congestion_level if latest else 'GREEN'
            trend, diff = _get_trend(s)
            result.append({
                'id': s.id, 'name': s.name, 'lat': s.lat, 'lng': s.lng,
                'address': s.address, 'vehicles': count, 'status': level,
                'trend': trend, 'trend_diff': diff,
                'wait_minutes': (count * 2) // max(s.total_pumps, 1),
                'distance_km': round(dist, 2), 'total_pumps': s.total_pumps,
                'last_updated': _seconds_ago(latest.timestamp if latest else None),
                'has_fuel': True,
            })
    result.sort(key=lambda x: x['distance_km'])
    return JsonResponse(result, safe=False)


@api_view(['GET'])
@permission_classes([AllowAny])
def station_status(request, station_id):
    try:
        s = Station.objects.get(id=station_id)
    except Station.DoesNotExist:
        return JsonResponse({'error': 'Not found'}, status=404)
    latest = QueueStatus.objects.filter(station=s).first()
    count  = latest.vehicle_count if latest else 0
    level  = latest.congestion_level if latest else 'GREEN'
    trend, diff = _get_trend(s)
    return JsonResponse({
        'id': s.id, 'name': s.name, 'vehicles': count, 'status': level,
        'trend': trend, 'trend_diff': diff,
        'wait_minutes': (count * 2) // max(s.total_pumps, 1),
        'last_updated': _seconds_ago(latest.timestamp if latest else None),
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def station_history(request, station_id):
    try:
        s = Station.objects.get(id=station_id)
    except Station.DoesNotExist:
        return JsonResponse({'error': 'Not found'}, status=404)
    since   = timezone.now() - timedelta(hours=24)
    history = QueueStatus.objects.filter(station=s, timestamp__gte=since).order_by('timestamp')
    return JsonResponse({'station': s.name, 'data': [
        {'time': str(h.timestamp), 'count': h.vehicle_count, 'status': h.congestion_level}
        for h in history
    ]})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_overview(request, station_id):
    try:
        s = Station.objects.get(id=station_id)
    except Station.DoesNotExist:
        return JsonResponse({'error': 'Not found'}, status=404)
    now         = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    today_qs  = QueueStatus.objects.filter(station=s, timestamp__gte=today_start)
    month_qs  = QueueStatus.objects.filter(station=s, timestamp__gte=month_start)
    today_txn = FuelTransaction.objects.filter(station=s, timestamp__gte=today_start)
    month_txn = FuelTransaction.objects.filter(station=s, timestamp__gte=month_start)
    hourly = []
    for hour in range(24):
        h_start = today_start + timedelta(hours=hour)
        h_end   = h_start + timedelta(hours=1)
        h_qs    = QueueStatus.objects.filter(station=s, timestamp__gte=h_start, timestamp__lt=h_end)
        avg     = (sum(q.vehicle_count for q in h_qs) // h_qs.count()) if h_qs.exists() else 0
        hourly.append({'hour': hour, 'avg_vehicles': avg})
    fuel_breakdown = {}
    for t in month_txn:
        fuel_breakdown[t.fuel_type] = fuel_breakdown.get(t.fuel_type, 0) + t.liters
    peak_hours = sorted(hourly, key=lambda x: x['avg_vehicles'], reverse=True)[:3]
    return JsonResponse({
        'station': s.name,
        'today': {
            'avg_vehicles': (sum(q.vehicle_count for q in today_qs) // today_qs.count()) if today_qs.exists() else 0,
            'revenue_pkr': round(sum(t.amount for t in today_txn), 2),
            'liters_dispensed': round(sum(t.liters for t in today_txn), 2),
        },
        'monthly': {
            'total_visits': month_qs.count(),
            'revenue_pkr': round(sum(t.amount for t in month_txn), 2),
            'liters_dispensed': round(sum(t.liters for t in month_txn), 2),
        },
        'hourly_congestion': hourly,
        'fuel_breakdown_liters': fuel_breakdown,
        'peak_hours': peak_hours,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_transactions(request, station_id):
    days  = int(request.GET.get('days', 7))
    since = timezone.now() - timedelta(days=days)
    try:
        s = Station.objects.get(id=station_id)
    except Station.DoesNotExist:
        return JsonResponse({'error': 'Not found'}, status=404)
    txns = FuelTransaction.objects.filter(station=s, timestamp__gte=since)
    return JsonResponse({'transactions': [
        {'id': t.id, 'fuel_type': t.fuel_type, 'liters': t.liters,
         'price_per_liter': t.price_per_liter, 'amount': t.amount,
         'vehicle_reg': t.vehicle_reg, 'timestamp': str(t.timestamp)}
        for t in txns
    ], 'count': txns.count()})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def employees_list(request, station_id):
    try:
        s = Station.objects.get(id=station_id)
    except Station.DoesNotExist:
        return JsonResponse({'error': 'Station not found'}, status=404)

    profile = request.user.profile
    if not profile.is_station_owner or profile.owned_station_id != s.id:
        return JsonResponse({'error': 'Not authorized'}, status=403)

    if request.method == 'GET':
        emps = Employee.objects.filter(station=s)
        return JsonResponse({'employees': [
            {'id': e.id, 'name': e.name, 'phone': e.phone, 'role': e.role,
             'shift': e.shift, 'is_active': e.is_active, 'joined_at': str(e.joined_at)}
            for e in emps
        ]})

    data = request.data
    name = data.get('name', '').strip()
    if not name:
        return JsonResponse({'error': 'Name required'}, status=400)
    emp = Employee.objects.create(
        station=s, name=name,
        phone=data.get('phone', ''),
        role=data.get('role', 'Pump Attendant'),
        shift=data.get('shift', 'MORNING'),
    )
    return JsonResponse({'id': emp.id, 'message': 'Employee added'}, status=201)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def employee_delete(request, station_id, employee_id):
    try:
        s = Station.objects.get(id=station_id)
        emp = Employee.objects.get(id=employee_id, station=s)
    except (Station.DoesNotExist, Employee.DoesNotExist):
        return JsonResponse({'error': 'Not found'}, status=404)

    profile = request.user.profile
    if not profile.is_station_owner or profile.owned_station_id != s.id:
        return JsonResponse({'error': 'Not authorized'}, status=403)

    emp.delete()
    return JsonResponse({'message': 'Deleted'})


@api_view(['GET'])
@permission_classes([AllowAny])
def stations_list_simple(request):
    stations = Station.objects.filter(is_active=True).values('id', 'name', 'address')
    return JsonResponse({'stations': list(stations)}, safe=False)
