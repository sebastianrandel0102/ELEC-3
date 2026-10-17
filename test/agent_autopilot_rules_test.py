"""Autopilot record/ownership regression against an isolated demo Firestore.

Run: py -3 test/agent_autopilot_rules_test.py --java <Java 21+ executable>
No production credentials, deployments or real user records are used.
"""
import json
import unittest

import firestore_withdrawal_rules_test as emulator

emulator.PORT = 8086
emulator.HOST = f"http://127.0.0.1:{emulator.PORT}"


def encode(values):
    result = {}
    for key, value in values.items():
        if value is None:
            result[key] = {"nullValue": None}
        elif isinstance(value, bool):
            result[key] = {"booleanValue": value}
        elif isinstance(value, int):
            result[key] = {"integerValue": str(value)}
        elif isinstance(value, float):
            result[key] = {"doubleValue": value}
        else:
            result[key] = {"stringValue": value}
    return result


def create(path, data, uid="owner", timestamps=()):
    return emulator.commit([{
        "update": {"name": f"{emulator.DOCUMENTS}/{path}", "fields": encode(data)},
        "currentDocument": {"exists": False},
        "updateTransforms": [{"fieldPath": name, "setToServerValue": "REQUEST_TIME"}
                             for name in timestamps],
    }], uid=uid)


class AutopilotRulesTests(unittest.TestCase):
    def setUp(self):
        status, result = emulator.call("DELETE", f"/emulator/v1/{emulator.DOCUMENTS}", uid=None)
        self.assertEqual(status, 200, result)

    def goal(self, amount=0.0):
        status, result = create("users/owner/goals/agent_goal_step_1", {
            "title": "Laptop", "targetAmount": 30000.0, "savedAmount": amount,
            "currencyCode": "PHP", "note": "", "archived": False,
            "agentOperation": json.dumps({"type": "createGoal", "name": "Laptop"}),
        }, timestamps=("createdAt", "updatedAt"))
        self.assertEqual(status, 200, result)

    def reminder(self, **changes):
        return {
            "uid": "owner", "type": "personalGoal", "targetId": "agent_goal_step_1",
            "enabled": True, "hour": 19, "minute": 0, "frequency": "weekly",
            "instant": None, "weekday": 5, "offsetMinutes": 15, "daysBefore": 0,
            "showTitle": False, "version": 1, **changes,
        }

    def test_empty_agent_goal_creation_and_stable_id_precondition(self):
        self.goal()
        path = "users/owner/goals/agent_goal_step_1"
        status, _ = create(path, {"title": "Overwrite", "savedAmount": 100.0})
        self.assertEqual(status, 409)
        status, record = emulator.get(path)
        self.assertEqual(status, 200)
        self.assertEqual(record["fields"]["savedAmount"]["doubleValue"], 0)

    def test_agent_metadata_cannot_cross_account_goal_or_task_ownership(self):
        self.goal()
        for collection in ("goals", "tasks"):
            path = f"users/owner/{collection}/agent_foreign_step_1"
            status, _ = create(path, {"title": "Forged", "savedAmount": 0.0,
                                     "authorizationKind": "autopilotPolicy"}, uid="other")
            self.assertEqual(status, 403)
        self.assertEqual(emulator.get("users/owner/goals/agent_goal_step_1", uid="other")[0], 403)

    def test_personal_reminder_requires_owned_existing_target(self):
        self.goal()
        status, result = create("users/owner/reminders/personalGoal_agent_goal_step_1",
                                self.reminder(), timestamps=("updatedAt",))
        self.assertEqual(status, 200, result)
        status, _ = create("users/owner/reminders/personalGoal_missing",
                           self.reminder(targetId="missing"), timestamps=("updatedAt",))
        self.assertEqual(status, 403)

    def test_forged_policy_fields_do_not_bypass_reminder_schema(self):
        self.goal()
        status, _ = create("users/owner/reminders/personalGoal_agent_goal_step_1",
                           self.reminder(approved=True, authorizationKind="autopilotPolicy"),
                           timestamps=("updatedAt",))
        self.assertEqual(status, 403)

    def test_policy_metadata_cannot_authorize_unrecorded_withdrawal(self):
        self.goal(500.0)
        status, _ = emulator.commit([{
            "update": {"name": f"{emulator.DOCUMENTS}/users/owner/goals/agent_goal_step_1",
                       "fields": encode({"savedAmount": 0.0, "authorizationKind": "autopilotPolicy"})},
            "updateMask": {"fieldPaths": ["savedAmount", "authorizationKind"]},
        }])
        self.assertEqual(status, 403)

    def test_unauthenticated_creation_is_denied(self):
        for collection in ("goals", "tasks"):
            self.assertEqual(create(f"users/owner/{collection}/agent_noauth_step_1",
                                    {"title": "Forged", "savedAmount": 0.0}, uid=None)[0], 403)

    def test_task_undo_keeps_owner_boundary(self):
        path = "users/owner/tasks/agent_task_step_1"
        status, result = create(path, {"title": "Homework", "completed": False,
                                     "dateKey": "2027-01-02", "time": "", "priority": "Normal"})
        self.assertEqual(status, 200, result)
        deletion = [{"delete": f"{emulator.DOCUMENTS}/{path}"}]
        self.assertEqual(emulator.commit(deletion, uid="other")[0], 403)
        self.assertEqual(emulator.commit(deletion)[0], 200)


if __name__ == "__main__":
    emulator.WithdrawalRulesTests = AutopilotRulesTests
    raise SystemExit(emulator.main())
