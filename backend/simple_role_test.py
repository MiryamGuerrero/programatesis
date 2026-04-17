#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test simple para verificar roles."""

import os
import sys
from datetime import datetime, timedelta, timezone
import jwt as pyjwt
import httpx
from dotenv import load_dotenv

load_dotenv()
jwt_secret = os.getenv("SUPABASE_JWT_SECRET")

print("[TEST] Sincronizacion de Roles en Supabase")
print("-" * 60)

users = [
    ("admin@reumanutri.app", "2ce2820e-323c-4015-be3e-4d94837e4fc6", "admin"),
    ("medico@reumanutri.app", "ada48961-d81c-4dda-8056-3e25b6e51766", "medico"),
    ("nutricionista@reumanutri.app", "b4ca5ef7-58b4-4d3b-844d-39e321a7d73d", "nutricionista"),
    ("tutor@reumanutri.app", "ddc6eaf0-d517-4990-b9ff-9465775ff0ed", "tutor"),
]

passed = 0

for email, user_id, expected_role in users:
    payload = {
        "sub": user_id,
        "email": email,
        "aud": "authenticated",
        "iat": datetime.now(timezone.utc).timestamp(),
        "exp": (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp(),
        "app_metadata": {"provider": "email", "role": expected_role},
        "user_metadata": {},
    }
    
    token = pyjwt.encode(payload, jwt_secret, algorithm="HS256")
    
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(
                "http://localhost:8000/api/v1/auth-context",
                headers={"Authorization": f"Bearer {token}"},
            )
        
        if response.status_code == 200:
            actual_role = response.json().get("role")
            if actual_role == expected_role:
                print("[OK] " + email + " -> " + actual_role)
                passed += 1
            else:
                print("[FAIL] " + email + " got " + str(actual_role) + " expected " + expected_role)
        else:
            print("[FAIL] " + email + " status " + str(response.status_code))
    except Exception as e:
        print("[ERROR] " + email + ": " + str(e))

print("-" * 60)
print("[RESULT] " + str(passed) + " / " + str(len(users)) + " tests passed")

if passed == len(users):
    print("\n[SUCCESS] Todos los roles funcionan correctamente!")
    sys.exit(0)
else:
    print("\n[FAILED] Algunos tests fallaron")
    sys.exit(1)
