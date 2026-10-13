"""Email OTP generation, delivery and verification.

Both signup and password reset verify the user's email address with a
6-digit one-time code. Codes live in ``OTPRecord`` and are single use:
signup consumes the code only after every other validation has passed,
password reset consumes it as soon as the new password is stored.
"""

from django.conf import settings
from django.core.mail import send_mail

from .models import OTPRecord

PURPOSE_SIGNUP = "SIGNUP"
PURPOSE_RESET = "RESET"

_SUBJECTS = {
    PURPOSE_SIGNUP: "FuelSense - verify your email",
    PURPOSE_RESET: "FuelSense - reset your password",
}

_BODIES = {
    PURPOSE_SIGNUP: (
        "Welcome to FuelSense.\n\n"
        "Your email verification code is:\n\n"
        "    {otp}\n\n"
        "The code expires in {minutes} minutes.\n"
        "If you did not try to create a FuelSense account you can ignore this email."
    ),
    PURPOSE_RESET: (
        "You asked to reset your FuelSense password.\n\n"
        "Your reset code is:\n\n"
        "    {otp}\n\n"
        "The code expires in {minutes} minutes.\n"
        "If you did not request a password reset you can ignore this email."
    ),
}

# Returned to the app instead of raising, so the UI can say something useful.
INVALID_CODE = "Invalid or expired code. Please request a new one."
MISSING_FIELDS = "Email and code are required."


def _otp_minutes() -> int:
    return max(1, getattr(settings, "OTP_EXPIRY_SECONDS", 300) // 60)


def issue(email: str, purpose: str) -> OTPRecord:
    """Create a fresh code for ``email``, invalidating any previous unused one."""
    OTPRecord.objects.filter(
        email__iexact=email, purpose=purpose, is_used=False
    ).update(is_used=True)
    return OTPRecord.objects.create(
        email=email,
        otp=OTPRecord.generate_otp(),
        purpose=purpose,
    )


def deliver(record: OTPRecord) -> tuple[bool, str | None]:
    """Email the code to the address on ``record``.

    Returns ``(delivered, error)``. The backend is chosen in settings: real
    SMTP once Gmail credentials are configured, otherwise the console backend
    so local development never crashes over a missing mailbox.
    """
    subject = _SUBJECTS.get(record.purpose, "FuelSense verification code")
    body = _BODIES.get(record.purpose, "Your FuelSense code is: {otp}").format(
        otp=record.otp, minutes=_otp_minutes()
    )
    try:
        send_mail(
            subject=subject,
            message=body,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[record.email],
            fail_silently=False,
        )
    except Exception as exc:  # bad credentials, no network, host refused, ...
        return False, str(exc)
    return True, None


def check(email: str, code: str, purpose: str) -> tuple[OTPRecord | None, str | None]:
    """Look up a usable code. Returns ``(record, None)`` or ``(None, error)``."""
    if not email or not code:
        return None, MISSING_FIELDS
    record = (
        OTPRecord.objects.filter(
            email__iexact=email, otp=code, purpose=purpose, is_used=False
        )
        .order_by("-created_at")
        .first()
    )
    if record is None or not record.is_valid():
        return None, INVALID_CODE
    return record, None


def consume(record: OTPRecord) -> None:
    """Mark a verified code as used so it cannot be replayed."""
    record.is_used = True
    record.save(update_fields=["is_used"])


def dev_code(record: OTPRecord) -> str | None:
    """The raw code to hand back to the client while testing.

    Only returns something when ``OTP_DEV_MODE`` is on, which must be off in
    production.
    """
    if getattr(settings, "OTP_DEV_MODE", False):
        return record.otp
    return None
