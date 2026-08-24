#!/usr/bin/env python3
import json
import os
import re
import smtplib
import ssl
import threading
import time
from collections import defaultdict, deque
from email.message import EmailMessage
from email.utils import parseaddr
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = int(os.environ.get("CONTACT_PORT", "8787"))
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "465"))
SMTP_USER = os.environ["SMTP_USER"]
SMTP_PASSWORD = os.environ["SMTP_PASSWORD"]
CONTACT_TO = [x.strip() for x in os.environ["CONTACT_TO"].split(",") if x.strip()]
CONTACT_BCC = [x.strip() for x in os.environ.get("CONTACT_BCC", "").split(",") if x.strip()]
ALLOWED_ORIGINS = {x.strip() for x in os.environ.get("ALLOWED_ORIGINS", "https://marygunn.com,https://www.marygunn.com").split(",") if x.strip()}
MAX_BODY = 20_000
MAX_MESSAGE = 4_000
RATE_LIMIT = 5
RATE_WINDOW = 3600
requests_by_ip = defaultdict(deque)
rate_lock = threading.Lock()


def valid_email(value):
    if not isinstance(value, str) or len(value) > 254 or "\r" in value or "\n" in value:
        return False
    _, address = parseaddr(value)
    return address == value and re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", value) is not None


def rate_allowed(ip):
    now = time.time()
    with rate_lock:
        q = requests_by_ip[ip]
        while q and q[0] < now - RATE_WINDOW:
            q.popleft()
        if len(q) >= RATE_LIMIT:
            return False
        q.append(now)
        return True


def send_message(sender, message, context):
    subject_context = re.sub(r"[^A-Za-z0-9 &'()-]", "", context or "Contact Mary").strip()[:80] or "Contact Mary"
    mail = EmailMessage()
    mail["From"] = f"Mary Gunn Website <{SMTP_USER}>"
    mail["To"] = ", ".join(CONTACT_TO)
    if CONTACT_BCC:
        mail["Bcc"] = ", ".join(CONTACT_BCC)
    mail["Reply-To"] = sender
    mail["Subject"] = f"Website message: {subject_context}"
    mail.set_content(
        "A visitor sent this message through marygunn.com.\n\n"
        f"Reply to: {sender}\n"
        f"Topic: {subject_context}\n\n"
        f"{message}\n"
    )
    tls = ssl.create_default_context()
    if SMTP_PORT == 465:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=tls, timeout=15) as smtp:
            smtp.login(SMTP_USER, SMTP_PASSWORD)
            smtp.send_message(mail)
    else:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls(context=tls)
            smtp.ehlo()
            smtp.login(SMTP_USER, SMTP_PASSWORD)
            smtp.send_message(mail)


class Handler(BaseHTTPRequestHandler):
    server_version = "MaryContact/1.0"

    def log_message(self, fmt, *args):
        # Never log submitted email addresses or message bodies.
        print(f"{self.client_address[0]} - {fmt % args}")

    def reply(self, status, payload):
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True})
        else:
            self.reply(404, {"ok": False})

    def do_POST(self):
        if self.path != "/contact":
            return self.reply(404, {"ok": False})
        origin = self.headers.get("Origin", "")
        if origin not in ALLOWED_ORIGINS:
            return self.reply(403, {"ok": False, "error": "Request origin rejected."})
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.reply(400, {"ok": False, "error": "Invalid request."})
        if length < 2 or length > MAX_BODY:
            return self.reply(413, {"ok": False, "error": "Message is too large."})
        try:
            data = json.loads(self.rfile.read(length))
        except Exception:
            return self.reply(400, {"ok": False, "error": "Invalid request."})
        sender = str(data.get("email", "")).strip().lower()
        message = str(data.get("message", "")).strip()
        context = str(data.get("context", "Contact Mary")).strip()
        if data.get("website"):
            return self.reply(200, {"ok": True})
        if not valid_email(sender):
            return self.reply(422, {"ok": False, "error": "Enter a valid email address."})
        if len(message) < 3 or len(message) > MAX_MESSAGE:
            return self.reply(422, {"ok": False, "error": "Enter a message between 3 and 4,000 characters."})
        ip = self.headers.get("X-Real-IP", self.client_address[0]).split(",", 1)[0].strip()
        if not rate_allowed(ip):
            return self.reply(429, {"ok": False, "error": "Too many messages. Try again later."})
        try:
            send_message(sender, message, context)
        except Exception as exc:
            print(f"SMTP delivery failed: {type(exc).__name__}")
            return self.reply(502, {"ok": False, "error": "The message could not be sent. Try again shortly."})
        self.reply(200, {"ok": True})


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
