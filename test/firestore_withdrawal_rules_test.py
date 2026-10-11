"""Isolated Firestore emulator checks; never connects to the real Firebase project.

Run: py -3 test/firestore_withdrawal_rules_test.py --java <Java 21+ executable>
The verified official emulator JAR is cached under ignored build/emulator/.
"""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import time
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen, urlretrieve

PROJECT = "demo-savetrack-withdrawal"
PORT = 8085
HOST = f"http://127.0.0.1:{PORT}"
DATABASE = f"projects/{PROJECT}/databases/(default)"
DOCUMENTS = f"{DATABASE}/documents"
GOAL = "users/owner/goals/emergency"
ROOT = Path(__file__).resolve().parents[1]


def token(uid):
    # Unsigned test tokens are accepted only by the emulator.
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")
    return encode({"alg": "none", "typ": "JWT"}) + "." + encode({
        "sub": uid, "user_id": uid, "aud": PROJECT,
        "iss": f"https://securetoken.google.com/{PROJECT}",
        "iat": int(time.time()), "exp": int(time.time()) + 3600,
        "firebase": {"sign_in_provider": "anonymous"},
    }) + "."


def call(method, path, body=None, uid="owner"):
    headers = {"Content-Type": "application/json"}
    if uid is not None:
        headers["Authorization"] = f"Bearer {token(uid)}"
    request = Request(HOST + path, data=None if body is None else json.dumps(body).encode(),
                      headers=headers, method=method)
    try:
        with urlopen(request, timeout=40) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except HTTPError as error:
        return error.code, json.loads(error.read())


def fields(data):
    result = {}
    for key, value in data.items():
        if isinstance(value, str):
            result[key] = {"stringValue": value}
        elif isinstance(value, bool):
            result[key] = {"booleanValue": value}
        else:
            result[key] = {"doubleValue": value}
    return result


def get(path=GOAL, uid="owner", transaction=None):
    if transaction is not None:
        # The emulator does not decode byte-valued GET query parameters.
        # batchGet accepts the transaction token through protobuf JSON instead.
        status, result = call("POST", f"/v1/{DOCUMENTS}:batchGet", {
            "documents": [f"{DOCUMENTS}/{path}"], "transaction": transaction,
        }, uid=uid)
        if status != 200:
            return status, result
        entry = result[0] if isinstance(result, list) else result
        return (200, entry["found"]) if "found" in entry else (404, entry)
    return call("GET", f"/v1/{DOCUMENTS}/{path}", uid=uid)


def commit(writes, uid="owner", transaction=None):
    body = {"writes": writes}
    if transaction is not None:
        body["transaction"] = transaction
    return call("POST", f"/v1/{DOCUMENTS}:commit", body, uid=uid)


def withdrawal(amount, new_balance, request_id="withdrawal", update_time=None):
    balance_write = {
        "update": {"name": f"{DOCUMENTS}/{GOAL}", "fields": fields({
            "savedAmount": new_balance, "lastWithdrawalId": request_id,
        })},
        "updateMask": {"fieldPaths": ["savedAmount", "lastWithdrawalId"]},
        "updateTransforms": [{"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"}],
        "currentDocument": {"exists": True} if update_time is None else {"updateTime": update_time},
    }
    history_write = {
        "update": {"name": f"{DOCUMENTS}/{GOAL}/transactions/{request_id}", "fields": fields({
            "amount": amount, "note": "Emergency expense", "type": "withdrawal",
        })},
        "updateTransforms": [{"fieldPath": "date", "setToServerValue": "REQUEST_TIME"}],
        "currentDocument": {"exists": False},
    }
    return [balance_write, history_write]


class WithdrawalRulesTests(unittest.TestCase):
    def setUp(self):
        status, result = call("DELETE", f"/emulator/v1/{DOCUMENTS}", uid=None)
        self.assertEqual(status, 200, result)
        status, result = call("PATCH", f"/v1/{DOCUMENTS}/{GOAL}", {"fields": fields({
            "savedAmount": 5000.0, "targetAmount": 10000.0, "title": "Emergency fund", "archived": False,
        })})
        self.assertEqual(status, 200, result)

    def assert_balance(self, expected):
        status, result = get()
        self.assertEqual(status, 200, result)
        self.assertAlmostEqual(result["fields"]["savedAmount"]["doubleValue"], expected)

    def assert_denied(self, writes, uid="owner"):
        status, result = commit(writes, uid=uid)
        self.assertEqual(status, 403, result)
        self.assert_balance(5000)
        self.assertEqual(get(f"{GOAL}/transactions/withdrawal")[0], 404)

    def test_atomic_server_transaction_and_positive_withdrawal_record(self):
        status, result = call("POST", f"/v1/{DOCUMENTS}:beginTransaction", {})
        self.assertEqual(status, 200, result)
        transaction = result["transaction"]
        self.assertEqual(get(transaction=transaction)[0], 200)
        self.assertEqual(get(f"{GOAL}/transactions/withdrawal", transaction=transaction)[0], 404)
        status, result = commit(withdrawal(1500, 3500), transaction=transaction)
        self.assertEqual(status, 200, result)
        self.assert_balance(3500)
        status, record = get(f"{GOAL}/transactions/withdrawal")
        self.assertEqual(status, 200, record)
        self.assertEqual(record["fields"]["type"]["stringValue"], "withdrawal")
        self.assertEqual(record["fields"]["amount"]["doubleValue"], 1500)
        self.assertIn("timestampValue", record["fields"]["date"])

    def test_cannot_overdraw_or_create_negative_balance(self):
        self.assert_denied(withdrawal(6000, -1000))

    def test_zero_and_negative_amounts_rejected(self):
        self.assert_denied(withdrawal(0, 5000))
        self.assert_denied(withdrawal(-500, 5500))

    def test_full_withdrawal_and_decimal_precision(self):
        status, result = commit(withdrawal(4999.71, 0.29))
        self.assertEqual(status, 200, result)
        status, result = commit(withdrawal(0.29, 0.0, request_id="final"))
        self.assertEqual(status, 200, result)
        self.assert_balance(0)

    def test_record_and_balance_must_be_written_together(self):
        writes = withdrawal(1500, 3500)
        self.assert_denied([writes[0]])
        self.assert_denied([writes[1]])

    def test_wrong_balance_rejected_atomically(self):
        self.assert_denied(withdrawal(1500, 4000))

    def test_other_user_and_unauthenticated_cannot_withdraw_or_read(self):
        for uid in ["someone-else", None]:
            self.assert_denied(withdrawal(1500, 3500), uid=uid)
            self.assertEqual(get(uid=uid)[0], 403)

    def test_duplicate_request_cannot_decrease_twice(self):
        self.assertEqual(commit(withdrawal(1500, 3500))[0], 200)
        status, result = commit(withdrawal(1500, 2000))
        self.assertNotEqual(status, 200, result)
        self.assert_balance(3500)

    def test_concurrent_writes_use_latest_balance_and_cannot_overdraw(self):
        status, current = get()
        self.assertEqual(status, 200, current)
        update_time = current["updateTime"]
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda id: commit(withdrawal(3000, 2000, id, update_time)), ["first", "second"]))
        self.assertEqual(sum(status == 200 for status, _ in results), 1, results)
        self.assert_balance(2000)
        status, result = commit(withdrawal(3000, -1000, "retry"))
        self.assertEqual(status, 403, result)

    def test_deposits_goal_edit_and_goal_deletion_still_work(self):
        writes = [
            {"update": {"name": f"{DOCUMENTS}/{GOAL}", "fields": {}},
             "updateMask": {"fieldPaths": []}, "updateTransforms": [
                 {"fieldPath": "savedAmount", "increment": {"doubleValue": 1000.0}},
                 {"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"},
             ]},
            {"update": {"name": f"{DOCUMENTS}/{GOAL}/transactions/deposit", "fields": fields({
                "amount": 1000.0, "note": "Deposit", "type": "deposit",
            })}, "updateTransforms": [{"fieldPath": "date", "setToServerValue": "REQUEST_TIME"}]},
        ]
        self.assertEqual(commit(writes)[0], 200)
        self.assert_balance(6000)
        self.assertEqual(commit(withdrawal(1500, 4500))[0], 200)
        status, result = call("PATCH", f"/v1/{DOCUMENTS}/{GOAL}?updateMask.fieldPaths=title", {"fields": fields({"title": "Edited fund"})})
        self.assertEqual(status, 200, result)
        self.assert_balance(4500)
        for path in [f"{GOAL}/transactions/deposit", f"{GOAL}/transactions/withdrawal", GOAL]:
            self.assertEqual(call("DELETE", f"/v1/{DOCUMENTS}/{path}")[0], 200)
        self.assertEqual(get()[0], 404)

    def test_legacy_deposit_creation_still_allowed(self):
        status, result = call("PATCH", f"/v1/{DOCUMENTS}/{GOAL}/transactions/legacy", {"fields": fields({"amount": 1000.0, "note": "Legacy deposit"})})
        self.assertEqual(status, 200, result)

    def test_withdrawals_cannot_be_edited_or_changed_to_deposits(self):
        self.assertEqual(commit(withdrawal(1500, 3500))[0], 200)
        status, result = call("PATCH", f"/v1/{DOCUMENTS}/{GOAL}/transactions/withdrawal?updateMask.fieldPaths=type", {"fields": fields({"type": "deposit"})})
        self.assertEqual(status, 403, result)
        self.assert_balance(3500)

    def test_missing_goal_rejects_withdrawal(self):
        self.assertEqual(call("DELETE", f"/v1/{DOCUMENTS}/{GOAL}")[0], 200)
        self.assertNotEqual(commit(withdrawal(1500, 3500))[0], 200)
        self.assertEqual(get(f"{GOAL}/transactions/withdrawal")[0], 404)

    def test_history_keeps_date_sorting_and_legacy_deposits(self):
        legacy = fields({"amount": 1000.0, "note": "Legacy contribution"})
        legacy["date"] = {"timestampValue": "2020-01-01T00:00:00Z"}
        self.assertEqual(call("PATCH", f"/v1/{DOCUMENTS}/{GOAL}/transactions/legacy", {"fields": legacy})[0], 200)
        self.assertEqual(commit(withdrawal(1500, 3500))[0], 200)
        status, result = call("POST", f"/v1/{DOCUMENTS}/{GOAL}:runQuery", {
            "structuredQuery": {"from": [{"collectionId": "transactions"}],
                                "orderBy": [{"field": {"fieldPath": "date"}, "direction": "DESCENDING"}]},
        })
        self.assertEqual(status, 200, result)
        records = [entry["document"] for entry in result if "document" in entry]
        self.assertEqual([record["name"].split("/")[-1] for record in records], ["withdrawal", "legacy"])
        self.assertNotIn("type", records[1]["fields"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="java")
    args = parser.parse_args()
    with socket.socket() as check:
        if check.connect_ex(("127.0.0.1", PORT)) == 0:
            raise SystemExit(f"Port {PORT} is in use; refusing to touch an existing emulator.")
    directory = ROOT / "build" / "emulator"
    directory.mkdir(parents=True, exist_ok=True)
    jar = directory / "cloud-firestore-emulator-v1.22.0.jar"
    checksum = "9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c"
    if not jar.exists():
        print("Downloading official Firestore emulator 1.22.0...", flush=True)
        urlretrieve("https://storage.googleapis.com/firebase-preview-drop/emulator/cloud-firestore-emulator-v1.22.0.jar", jar)
    if hashlib.file_digest(jar.open("rb"), "sha256").hexdigest() != checksum:
        raise SystemExit("Emulator checksum mismatch; refusing to execute.")
    with (directory / "firestore.log").open("w") as log:
        process = subprocess.Popen([
            args.java, "-jar", str(jar), "--host", "127.0.0.1", "--port", str(PORT),
            "--project_id", PROJECT, "--rules", str(ROOT / "firestore.rules"),
        ], stdout=log, stderr=log, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError((directory / "firestore.log").read_text())
                with socket.socket() as probe:
                    if probe.connect_ex(("127.0.0.1", PORT)) == 0:
                        break
                time.sleep(0.25)
            else:
                raise RuntimeError("Firestore emulator did not start within 60 seconds.")
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(WithdrawalRulesTests)
            result = unittest.TextTestRunner(verbosity=2).run(suite)
            return 0 if result.wasSuccessful() else 1
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
