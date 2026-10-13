"""Adversarial Spark client protocol tests against the real Firestore rules.

All operations under test use unprivileged emulator JWTs. Emulator-only fixtures
backdate invitation windows and creation timestamps to simulate elapsed time.
Run through run_shared_emulator.py (isolated demo project and loopback only).
"""
import copy
import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import secrets
import unittest
import json
import firestore_withdrawal_rules_test as r

STAMP = object()
DAY = datetime(2026, 1, 1, tzinfo=timezone.utc)


def rid():
    return secrets.token_urlsafe(32)


def encode(value):
    if isinstance(value, bytes): return {'bytesValue': base64.b64encode(value).decode('ascii')}
    if isinstance(value, bool): return {'booleanValue': value}
    if isinstance(value, int): return {'integerValue': str(value)}
    if isinstance(value, float): return {'doubleValue': value}
    if isinstance(value, str): return {'stringValue': value}
    if isinstance(value, datetime): return {'timestampValue': value.isoformat().replace('+00:00', 'Z')}
    if isinstance(value, list): return {'arrayValue': {'values': [encode(v) for v in value]}}
    if isinstance(value, dict): return {'mapValue': {'fields': {k: encode(v) for k, v in value.items()}}}
    raise TypeError(value)


def decode(value):
    if 'mapValue' in value: return {k: decode(v) for k, v in value['mapValue'].get('fields', {}).items()}
    if 'arrayValue' in value: return [decode(v) for v in value['arrayValue'].get('values', [])]
    if 'timestampValue' in value: return datetime.fromisoformat(value['timestampValue'].replace('Z', '+00:00'))
    if 'integerValue' in value: return int(value['integerValue'])
    return next(iter(value.values()))


def read(path, uid='owner'):
    status, result = r.get(path, uid)
    if status != 200: raise AssertionError((path, status, result))
    return {k: decode(v) for k, v in result['fields'].items()}


def write(path, data, partial=False, update_time=None):
    fields = {k: encode(v) for k, v in data.items() if v is not STAMP}
    result = {'update': {'name': f'{r.DOCUMENTS}/{path}', 'fields': fields}}
    stamps = [{'fieldPath': k, 'setToServerValue': 'REQUEST_TIME'} for k, v in data.items() if v is STAMP]
    if stamps: result['updateTransforms'] = stamps
    if partial: result['updateMask'] = {'fieldPaths': list(fields)}
    if update_time: result['currentDocument'] = {'updateTime': update_time}
    return result


def change(kind, uid='owner', subject=None, request=None):
    return {'lastKind': kind, 'lastId': request or rid(), 'lastActor': uid,
            'lastSubject': subject or uid, 'updatedAt': STAMP}


def member(uid, cents=0, role='contributor', code=''):
    return {'userId': uid, 'displayName': uid, 'role': role, 'status': 'active',
            'depositCents': cents, 'totalDeposits': cents / 100, 'joinedAt': STAMP, 'invitationId': code}


def record(gid, uid, amount, kind='deposit'):
    return {'goalId': gid, 'contributorId': uid, 'displayName': uid, 'type': kind,
            'amountCents': amount, 'amount': amount / 100, 'date': DAY, 'note': 'Saved', 'createdAt': STAMP}


def creation(gid, amount=10025, uid='owner'):
    g = {'schemaVersion': 2, 'name': 'Trip', 'description': '', 'iconKey': 'travel', 'startDate': DAY,
         'deadline': datetime(2027, 1, 1, tzinfo=timezone.utc), 'targetCents': 3000000, 'targetAmount': 30000.0,
         'ownerId': uid, 'ownerName': uid, 'memberIds': [uid], 'memberNames': {uid: uid},
         'personalDeposits': {uid: amount / 100}, 'memberCount': 1, 'currentCents': amount,
         'depositCents': amount, 'decreaseCents': 0, 'currentAmount': amount / 100,
         'totalDeposits': amount / 100, 'totalDecreases': 0.0, 'createdAt': STAMP,
         'status': 'completed' if amount >= 3000000 else 'active', **change('create', uid)}
    writes = [write(f'sharedGoals/{gid}', g), write(f'sharedGoals/{gid}/members/{uid}', member(uid, amount, 'owner'))]
    if amount: writes.append(write(f'sharedGoals/{gid}/transactions/{g["lastId"]}', record(gid, uid, amount)))
    return writes


def invite(gid, code, uid='owner', expiry=None):
    g = read(f'sharedGoals/{gid}', uid)
    return write(f'sharedInvitations/{code}', {'goalId': gid, 'createdBy': uid, 'name': g['name'],
        'ownerName': g['ownerName'], 'targetAmount': g['targetAmount'], 'status': 'pending', 'recipientId': '',
        'createdAt': STAMP, 'updatedAt': STAMP,
        **({'expiresAt': expiry} if expiry is not None else {})})


def invite_limit(code, uid='owner'):
    path = f'sharedInviteLimits/{uid}'
    status, _ = r.get(path, uid)
    prior = read(path, uid) if status == 200 else None
    reset = prior is None or datetime.now(timezone.utc) >= prior['windowStart'] + timedelta(hours=1)
    return write(path, {'count': 1 if reset else prior['count'] + 1,
        'windowStart': STAMP if reset else prior['windowStart'], 'updatedAt': STAMP, 'lastCode': code})


def invitation_batch(gid, code=None, uid='owner', expiry=None):
    code = code or rid()
    return [invite(gid, code, uid, expiry), invite_limit(code, uid)]


def expire_invitation_window():
    # Privileged fixture is restricted to this isolated, loopback demo emulator.
    assert r.HOST.startswith('http://127.0.0.1:') and r.PROJECT.startswith('demo-')
    payload = {'writes': [write('sharedInviteLimits/owner',
        {'windowStart': datetime.now(timezone.utc) - timedelta(hours=2)}, True)]}
    request = r.Request(r.HOST + f'/v1/{r.DOCUMENTS}:commit',
        data=json.dumps(payload).encode(), method='POST',
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer owner'})
    with r.urlopen(request, timeout=10) as response:
        assert response.status == 200


def backdate_invitation(code):
    # Only the test fixture can change creation time, simulating seven elapsed days.
    assert r.HOST.startswith('http://127.0.0.1:') and r.PROJECT.startswith('demo-')
    payload = {'writes': [write(f'sharedInvitations/{code}',
        {'createdAt': datetime.now(timezone.utc) - timedelta(days=8)}, True)]}
    request = r.Request(r.HOST + f'/v1/{r.DOCUMENTS}:commit', data=json.dumps(payload).encode(),
        method='POST', headers={'Content-Type': 'application/json', 'Authorization': 'Bearer owner'})
    with r.urlopen(request, timeout=10) as response:
        assert response.status == 200


def joining(gid, code, uid='member', previous=0):
    # Precisely the transforms used by Flutter: no private goal read is needed.
    root = write(f'sharedGoals/{gid}', {**change('accept', uid), 'memberNames': {uid: uid},
                 'personalDeposits': {uid: previous / 100}}, partial=True)
    root['updateMask']['fieldPaths'] = ['lastKind', 'lastId', 'lastActor', 'lastSubject',
        f'memberNames.`{uid}`', f'personalDeposits.`{uid}`']
    root['updateTransforms'] += [{'fieldPath': 'memberIds', 'appendMissingElements': {'values': [encode(uid)]}},
                                {'fieldPath': 'memberCount', 'increment': encode(1)}]
    return [root, write(f'sharedGoals/{gid}/members/{uid}', member(uid, previous, code=code)),
            write(f'sharedInvitations/{code}', {'status': 'accepted', 'recipientId': uid, 'updatedAt': STAMP}, True)]


def money(gid, amount=29, uid='owner', withdrawal=False, request=None, snapshot=None):
    path = f'sharedGoals/{gid}'
    g = copy.deepcopy(snapshot) if snapshot is not None else read(path, uid)
    m = read(f'{path}/members/{uid}', uid)
    deposit = not withdrawal
    g.update(change('contribute' if deposit else 'decrease', uid, request=request))
    g['depositCents'] += amount if deposit else 0
    g['decreaseCents'] += amount if withdrawal else 0
    g['currentCents'] = g['depositCents'] - g['decreaseCents']
    for a, b in [('currentAmount', 'currentCents'), ('totalDeposits', 'depositCents'), ('totalDecreases', 'decreaseCents')]:
        g[a] = g[b] / 100
    g['status'] = 'completed' if g['currentCents'] >= g['targetCents'] else 'active'
    writes = []
    if deposit:
        m['depositCents'] += amount; m['totalDeposits'] = m['depositCents'] / 100
        g['personalDeposits'][uid] = m['totalDeposits']
        writes.append(write(f'{path}/members/{uid}', m))
    return [write(path, g), write(f'{path}/transactions/{g["lastId"]}', record(gid, uid, amount, 'deposit' if deposit else 'withdrawal')), *writes]


def leaving(gid, uid='member', owner=False):
    g = read(f'sharedGoals/{gid}')
    g['memberIds'].remove(uid); g['memberCount'] -= 1
    g['memberNames'].pop(uid); g['personalDeposits'].pop(uid)
    g.update(change('remove' if owner else 'leave', 'owner' if owner else uid, subject=uid))
    return [write(f'sharedGoals/{gid}', g), write(f'sharedGoals/{gid}/members/{uid}',
            {'status': 'removed' if owner else 'left', 'departedAt': STAMP}, True)]


class SparkRulesTests(unittest.TestCase):
    def setUp(self):
        self.assertEqual(r.call('DELETE', f'/emulator/v1/{r.DOCUMENTS}', uid=None)[0], 200)
        self.gid = rid(); self.path = f'sharedGoals/{self.gid}'
        self.ok(creation(self.gid))

    def ok(self, writes, uid='owner'):
        status, body = r.commit(writes, uid)
        self.assertEqual(status, 200, body)

    def denied(self, writes, uid='owner'):
        status, body = r.commit(writes, uid)
        self.assertEqual(status, 403, body)

    def new_invite(self):
        code = rid(); self.ok(invitation_batch(self.gid, code)); return code

    def test_goal_cover_preserves_contribution_withdrawal_invitation_and_membership_protocol(self):
        cover = f'{self.path}/cover/AAAAAAAAAAAAAAAAAAAA.jpg'
        before = read(self.path)
        self.ok([write(self.path, {'coverStoragePath': cover, 'coverUpdatedAt': STAMP}, True)])
        after = read(self.path)
        self.assertEqual({k: v for k, v in after.items() if not k.startswith('cover')}, before)
        code = self.new_invite()
        self.ok(joining(self.gid, code), 'member')
        self.ok(money(self.gid, amount=100, uid='member'), 'member')
        self.ok(money(self.gid, amount=50, withdrawal=True))
        self.assertEqual(read(self.path)['coverStoragePath'], cover)
        self.assertEqual(read(self.path)['currentCents'], before['currentCents'] + 50)
        self.ok(leaving(self.gid, owner=True))
        self.assertEqual(read(self.path)['coverStoragePath'], cover)

    def test_shared_contributor_cannot_change_cover_during_financial_update(self):
        cover = f'{self.path}/cover/AAAAAAAAAAAAAAAAAAAA.jpg'
        self.ok([write(self.path, {'coverStoragePath': cover, 'coverUpdatedAt': STAMP}, True)])
        code = self.new_invite()
        self.ok(joining(self.gid, code), 'member')
        changes = money(self.gid, amount=100, uid='member')
        changes[0]['update']['fields']['coverStoragePath'] = encode(f'{self.path}/cover/BBBBBBBBBBBBBBBBBBBB.jpg')
        self.denied(changes, 'member')
        self.assertEqual(read(self.path)['coverStoragePath'], cover)

    def test_compact_firestore_cover_preserves_full_shared_financial_protocol(self):
        cover = f'{self.path}/coverPhotos/AAAAAAAAAAAAAAAAAAAA'
        before = read(self.path)
        self.ok([write(cover, {'bytes': bytes.fromhex('FFD8FFE0FFD9'), 'contentType': 'image/jpeg',
            'width': 960, 'height': 540, 'createdAt': STAMP})])
        self.ok([write(self.path, {'coverStoragePath': cover, 'coverUpdatedAt': STAMP}, True)])
        self.assertEqual({k: v for k, v in read(self.path).items() if not k.startswith('cover')}, before)
        self.ok(joining(self.gid, self.new_invite()), 'member')
        self.ok(money(self.gid, amount=100, uid='member'), 'member')
        self.ok(money(self.gid, amount=50, withdrawal=True))
        self.assertEqual(read(self.path)['currentCents'], before['currentCents'] + 50)
        self.assertEqual(r.get(cover, 'member')[0], 200)
        forged = money(self.gid, amount=100, uid='member')
        forged[0]['update']['fields']['coverStoragePath'] = encode(f'{self.path}/coverPhotos/BBBBBBBBBBBBBBBBBBBB')
        self.denied(forged, 'member')
        self.ok(leaving(self.gid, owner=True))
        self.assertEqual(r.get(cover, 'member')[0], 403)
        self.assertEqual(read(self.path)['coverStoragePath'], cover)

    def test_invitation_limit_is_atomic_private_and_cannot_be_reset_early(self):
        code = rid()
        self.denied([invite(self.gid, code)])
        self.denied([invite_limit(code)])
        self.new_invite()
        self.assertEqual(r.get('sharedInviteLimits/owner', 'stranger')[0], 403)
        for key, value in [('count', 1), ('windowStart', datetime.now(timezone.utc) - timedelta(hours=2))]:
            code = rid(); limit = invite_limit(code)
            limit['update']['fields'][key] = encode(value)
            self.denied([invite(self.gid, code), limit])
        for _ in range(19): self.new_invite()
        code = rid()
        self.denied([invite(self.gid, code), invite_limit(code)])
        self.assertEqual(read('sharedInviteLimits/owner')['count'], 20)
        self.denied([{'delete': f'{r.DOCUMENTS}/sharedInviteLimits/owner'}])
        expire_invitation_window()
        self.new_invite()
        self.assertEqual(read('sharedInviteLimits/owner')['count'], 1)

    def test_invitation_limit_cannot_issue_two_codes_for_one_increment(self):
        code, other = rid(), rid()
        self.denied([invite(self.gid, code), invite(self.gid, other), invite_limit(code)])

    def join(self, uid='member'):
        code = self.new_invite(); self.ok(joining(self.gid, code, uid), uid); return code

    def test_initial_goal_is_atomic_with_member_and_ledger(self):
        for missing in [0, 1, 2]:
            writes = creation(rid()); writes.pop(missing); self.denied(writes)
        self.ok(creation(rid(), amount=0))
        self.ok(creation(rid(), amount=29))
        self.ok(creation(rid(), amount=4000000))

    def test_invalid_creation_balances_and_identity(self):
        for key, value in [('currentCents', -1), ('currentAmount', 999.0), ('ownerId', 'victim'),
                           ('depositCents', 10025.5), ('status', 'archived'), ('extra', True)]:
            writes = creation(rid()); writes[0]['update']['fields'][key] = encode(value); self.denied(writes)
        self.denied(creation(rid()), uid=None)

    def test_member_query_and_private_data_isolation(self):
        for uid in ['stranger', None]: self.assertEqual(r.get(self.path, uid)[0], 403)
        self.join()
        self.assertEqual(r.get(self.path, 'member')[0], 200)
        for path in [self.path+'/members/owner', self.path+'/transactions/unknown']:
            self.assertEqual(r.get(path, 'stranger')[0], 403)
        query = {'structuredQuery': {'from': [{'collectionId': 'sharedGoals'}], 'where': {'fieldFilter': {
            'field': {'fieldPath': 'memberIds'}, 'op': 'ARRAY_CONTAINS', 'value': encode('member')}}}}
        self.assertEqual(r.call('POST', f'/v1/{r.DOCUMENTS}:runQuery', query, 'member')[0], 200)
        query['structuredQuery'].pop('where')
        self.assertEqual(r.call('POST', f'/v1/{r.DOCUMENTS}:runQuery', query, 'member')[0], 403)

    def test_invitation_preview_cannot_read_financial_data_or_list_codes(self):
        code = self.new_invite()
        data = read(f'sharedInvitations/{code}', 'stranger')
        self.assertNotIn('currentAmount', data)
        self.assertEqual(r.get(self.path, 'stranger')[0], 403)
        self.assertEqual(r.get(f'sharedInvitations/{code}', None)[0], 403)
        query = {'structuredQuery': {'from': [{'collectionId': 'sharedInvitations'}]}}
        self.assertEqual(r.call('POST', f'/v1/{r.DOCUMENTS}:runQuery', query, 'stranger')[0], 403)
        query['structuredQuery']['where'] = {'fieldFilter': {'field': {'fieldPath': 'createdBy'}, 'op': 'EQUAL', 'value': encode('owner')}}
        self.assertEqual(r.call('POST', f'/v1/{r.DOCUMENTS}:runQuery', query, 'owner')[0], 200)

    def test_only_owner_creates_valid_short_lived_invitations(self):
        self.join()
        self.denied(invitation_batch(self.gid, uid='member'), 'member')
        self.denied(invitation_batch(self.gid, 'short'))
        self.denied(invitation_batch(self.gid, expiry=datetime.now(timezone.utc)+timedelta(days=8)))
        self.denied(invitation_batch(self.gid, expiry=datetime.now(timezone.utc)-timedelta(days=1)))
        forged = invitation_batch(self.gid); forged[0]['update']['fields']['currentAmount'] = encode(100)
        self.denied(forged)

    def test_device_clock_ahead_cannot_break_server_timed_invitations(self):
        # Reproduces the old client's 2-second clock skew: its +7-day expiry fails.
        self.denied(invitation_batch(self.gid,
            expiry=datetime.now(timezone.utc) + timedelta(days=7, seconds=2)))
        code = self.new_invite()
        stored = read(f'sharedInvitations/{code}')
        self.assertNotIn('expiresAt', stored)
        self.assertIsInstance(stored['createdAt'], datetime)
        self.ok(joining(self.gid, code), 'member')

    def test_server_timed_invitation_expires_and_cannot_be_extended(self):
        code = self.new_invite()
        self.denied([write(f'sharedInvitations/{code}',
            {'createdAt': STAMP, 'updatedAt': STAMP}, True)])
        self.denied([write(f'sharedInvitations/{code}',
            {'expiresAt': datetime.now(timezone.utc) + timedelta(days=20), 'updatedAt': STAMP}, True)])
        backdate_invitation(code)
        self.denied(joining(self.gid, code), 'member')
        self.denied([write(f'sharedInvitations/{code}',
            {'status': 'declined', 'recipientId': 'member', 'updatedAt': STAMP}, True)], 'member')

    def test_legacy_explicit_expiry_can_still_be_redeemed(self):
        code = rid()
        self.ok(invitation_batch(self.gid, code, expiry=datetime.now(timezone.utc) + timedelta(days=6)))
        self.ok(joining(self.gid, code), 'member')

    def test_join_requires_all_three_matching_documents(self):
        code = self.new_invite()
        self.assertEqual(r.get(self.path+'/members/member', 'member')[0], 404)
        for missing in [0, 1, 2]:
            writes = joining(self.gid, code); writes.pop(missing); self.denied(writes, 'member')
        self.ok(joining(self.gid, code), 'member')
        self.assertEqual(read(self.path)['memberCount'], 2)
        self.assertEqual(read(self.path, 'member')['currentCents'], 10025)

    def test_forged_join_cannot_add_other_users_promote_or_inflate_deposits(self):
        code = self.new_invite()
        for key, value in [('role', 'owner'), ('depositCents', 100), ('userId', 'victim')]:
            writes = joining(self.gid, code); writes[1]['update']['fields'][key] = encode(value)
            self.denied(writes, 'member')
        self.denied(joining(self.gid, code, previous=100), 'member')
        writes = joining(self.gid, code)
        writes[0]['updateTransforms'][1]['appendMissingElements']['values'].append(encode('victim'))
        self.denied(writes, 'member')

    def test_revocation_decline_and_single_use(self):
        for state in ['revoked', 'declined']:
            code = self.new_invite()
            update = {'status': state, 'updatedAt': STAMP}
            if state == 'declined': update['recipientId'] = 'member'
            self.ok([write(f'sharedInvitations/{code}', update, True)], 'owner' if state == 'revoked' else 'member')
            self.denied(joining(self.gid, code), 'member')
        code = self.join()
        self.denied(joining(self.gid, code, 'other'), 'other')
        self.denied(joining(self.gid, code), 'member')
        self.assertEqual(read(self.path)['memberCount'], 2)

    def test_two_users_race_to_accept_exactly_one_wins(self):
        code = self.new_invite()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda uid: r.commit(joining(self.gid, code, uid), uid), ['a', 'b']))
        self.assertEqual(sum(status == 200 for status, _ in results), 1, results)
        self.assertEqual(read(self.path)['memberCount'], 2)

    def test_contributions_require_balance_member_and_immutable_ledger(self):
        self.join()
        for missing in [0, 1, 2]:
            writes = money(self.gid, uid='member'); writes.pop(missing); self.denied(writes, 'member')
        self.ok(money(self.gid, uid='member'), 'member')
        self.assertEqual(read(self.path)['currentCents'], 10054)
        self.assertEqual(read(self.path)['personalDeposits']['member'], .29)
        self.assertEqual(read(self.path+'/members/member')['depositCents'], 29)

    def test_money_precision_ranges_and_wrong_attribution(self):
        for amount in [0, -1, 1.5, 100000000001]: self.denied(money(self.gid, amount=amount))
        for key, value in [('contributorId', 'victim'), ('amount', 999), ('note', 'x'*501),
                           ('date', datetime(2100, 1, 1, tzinfo=timezone.utc)), ('date', DAY-timedelta(days=1))]:
            writes = money(self.gid); writes[1]['update']['fields'][key] = encode(value); self.denied(writes)
        self.ok(money(self.gid, amount=1))
        self.assertEqual(read(self.path)['currentAmount'], 100.26)

    def test_wrong_balance_and_summary_forgery_rejected(self):
        for key, value in [('currentCents', 0), ('currentAmount', 0), ('totalDeposits', 1000),
                           ('memberNames', {'owner': 'Impersonator'}), ('ownerId', 'member')]:
            writes = money(self.gid); writes[0]['update']['fields'][key] = encode(value); self.denied(writes)
        writes = money(self.gid)
        writes[2]['update']['fields']['role'] = encode('contributor'); self.denied(writes)

    def test_duplicate_deposit_and_history_mutation_rejected(self):
        request = rid(); self.ok(money(self.gid, request=request))
        self.denied(money(self.gid, request=request))
        ledger = self.path+'/transactions/'+request
        self.denied([write(ledger, {'note': 'changed'}, True)])
        self.assertEqual(r.call('DELETE', f'/v1/{r.DOCUMENTS}/{ledger}')[0], 403)
        self.assertEqual(read(self.path)['currentCents'], 10054)

    def test_only_owner_can_decrease_and_never_overdraw(self):
        self.join()
        self.denied(money(self.gid, withdrawal=True, uid='member'), 'member')
        self.denied(money(self.gid, amount=10026, withdrawal=True))
        writes = money(self.gid, withdrawal=True)
        self.denied([writes[0]]); self.denied([writes[1]])
        self.ok(money(self.gid, amount=9996, withdrawal=True))
        self.assertEqual(read(self.path)['currentAmount'], .29)
        self.ok(money(self.gid, withdrawal=True))
        self.assertEqual(read(self.path)['currentCents'], 0)
        self.assertEqual(read(self.path)['personalDeposits']['owner'], 100.25)

    def test_concurrent_deposits_require_retry_and_preserve_totals(self):
        self.join()
        snapshot = read(self.path)
        a = money(self.gid, amount=1001, snapshot=snapshot)
        b = money(self.gid, amount=2002, uid='member', snapshot=snapshot)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda args: r.commit(*args), [(a, 'owner'), (b, 'member')]))
        self.assertEqual(sum(status == 200 for status, _ in results), 1, results)
        if results[0][0] != 200: self.ok(money(self.gid, amount=1001))
        else: self.ok(money(self.gid, amount=2002, uid='member'), 'member')
        self.assertEqual(read(self.path)['currentCents'], 13028)

    def test_concurrent_decreases_cannot_overdraw(self):
        snapshot = read(self.path)
        writes = [money(self.gid, amount=6000, withdrawal=True, snapshot=snapshot) for _ in range(2)]
        with ThreadPoolExecutor(max_workers=2) as pool: results = list(pool.map(r.commit, writes))
        self.assertEqual(sum(status == 200 for status, _ in results), 1, results)
        self.denied(money(self.gid, amount=6000, withdrawal=True))
        self.assertEqual(read(self.path)['currentCents'], 4025)

    def test_leave_preserves_history_and_rejoin_restores_lifetime_total(self):
        self.join(); self.ok(money(self.gid, uid='member'), 'member')
        self.ok(leaving(self.gid), 'member')
        self.assertEqual(r.get(self.path, 'member')[0], 403)
        self.assertEqual(read(self.path)['currentCents'], 10054)
        self.assertEqual(read(self.path+'/members/member', 'member')['depositCents'], 29)
        self.ok(joining(self.gid, self.new_invite(), previous=29), 'member')
        self.assertEqual(read(self.path)['personalDeposits']['member'], .29)

    def test_removed_member_cannot_rejoin_or_write(self):
        self.join(); stale = money(self.gid, uid='member')
        self.ok(leaving(self.gid, owner=True))
        self.assertEqual(r.get(self.path, 'member')[0], 403)
        self.denied(stale, 'member')
        self.denied(joining(self.gid, self.new_invite()), 'member')

    def test_member_cannot_remove_others_or_owner(self):
        self.join(); self.join('other')
        writes = leaving(self.gid, uid='other', owner=True)
        writes[0]['update']['fields']['lastActor'] = encode('member'); self.denied(writes, 'member')
        self.denied(leaving(self.gid, uid='owner'), 'owner')
        writes = leaving(self.gid)
        self.denied([writes[0]], 'member'); self.denied([writes[1]], 'member')

    def test_only_owner_can_edit_and_start_date_is_immutable(self):
        self.join()
        self.denied([write(self.path, {'name': 'Changed', **change('edit', 'member')}, True)], 'member')
        self.denied([write(self.path, {'startDate': DAY+timedelta(days=1), **change('edit')}, True)])
        self.ok([write(self.path, {'name': 'Changed', 'targetCents': 100, 'targetAmount': 1.0,
                                'status': 'completed', **change('edit')}, True)])
        self.assertEqual(read(self.path)['status'], 'completed')

    def test_archive_blocks_deposits_edit_invites_and_join(self):
        code = self.new_invite()
        self.ok([write(self.path, {'status': 'archived', **change('archive')}, True)])
        self.denied(money(self.gid))
        self.denied(invitation_batch(self.gid))
        self.denied(joining(self.gid, code), 'member')
        self.denied([write(self.path, {'status': 'active', **change('edit')}, True)])
        self.assertEqual(read(self.path)['currentCents'], 10025)

    def test_receipts_private_immutable_and_cannot_authorize_money(self):
        path = 'sharedOperations/owner/requests/'+rid()
        self.ok([write(path, {'fingerprint': 'fake', 'result': {'goalId': self.gid}, 'createdAt': STAMP})])
        self.assertEqual(r.get(path, 'member')[0], 403)
        self.denied([write(path, {'fingerprint': 'changed'}, True)])
        self.assertEqual(r.call('DELETE', f'/v1/{r.DOCUMENTS}/{path}')[0], 403)
        self.denied([write(self.path, {'currentAmount': 999.0}, True)])

    def test_member_limit_is_enforced_on_fiftieth_join(self):
        for index in range(49):
            if index and index % 20 == 0: expire_invitation_window()
            self.join(f'm{index}')
        self.assertEqual(read(self.path)['memberCount'], 50)
        self.denied(joining(self.gid, self.new_invite(), 'overflow'), 'overflow')

