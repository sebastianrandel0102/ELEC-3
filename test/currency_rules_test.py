"""Currency compatibility and adversarial rules tests, isolated emulator only."""
from datetime import datetime, timedelta, timezone
import unittest

import firestore_withdrawal_rules_test as r
import shared_spark_rules_test as s


def conversion(code='PHP', amount=10.0, rate=50.0):
    return {'inputAmount': amount, 'inputCurrencyCode': 'USD', 'goalCurrencyCode': code,
            'exchangeRate': rate, 'rateNumerator': '50', 'rateDenominator': '1',
            'rateTimestamp': datetime.now(timezone.utc) - timedelta(minutes=5),
            'rateProvider': 'ExchangeRate-API', 'rateSnapshotId': 'fixture:USD:locked'}


class CurrencyRulesTests(unittest.TestCase):
    def setUp(self):
        self.assertEqual(r.call('DELETE', f'/emulator/v1/{r.DOCUMENTS}', uid=None)[0], 200)
        self.assertEqual(r.commit([s.write(r.GOAL, {'savedAmount': 5000.0,
            'targetAmount': 10000.0, 'title': 'Trip', 'currencyCode': 'PHP', 'archived': False})])[0], 200)

    def cross_withdrawal(self, metadata=None):
        writes = r.withdrawal(500.0, 4500.0)
        writes[1]['update']['fields']['currencyCode'] = s.encode('PHP')
        writes[1]['update']['fields']['conversion'] = s.encode(metadata or conversion())
        return writes

    def test_currency_preference_is_owned_and_other_profile_fields_survive(self):
        profile = 'users/owner'
        self.assertEqual(r.commit([s.write(profile, {'displayName': 'Alex', 'currency': 'PHP'})])[0], 200)
        self.assertEqual(r.commit([s.write(profile, {'preferredCurrencyCode': 'JPY'}, True)])[0], 200)
        self.assertEqual(s.read(profile)['displayName'], 'Alex')
        self.assertEqual(r.commit([s.write(profile, {'preferredCurrencyCode': 'USD'}, True)], uid='stranger')[0], 403)
        for code in ['BTC', 'BGN', 'XXX']:
            self.assertEqual(r.commit([s.write(profile, {'preferredCurrencyCode': code}, True)])[0], 403)

    def test_goal_currency_is_immutable_and_active_new_denominations_allowed(self):
        self.assertEqual(r.commit([s.write(r.GOAL, {'currencyCode': 'USD'}, True)])[0], 403)
        for code in ['USD', 'EUR', 'JPY', 'KWD']:
            self.assertEqual(r.commit([s.write(f'users/owner/goals/{code}', {
                'savedAmount': 0.0, 'targetAmount': 1000.0, 'currencyCode': code})])[0], 200)
        self.assertEqual(r.commit([s.write('users/owner/goals/btc', {
            'savedAmount': 0.0, 'targetAmount': 1000.0, 'currencyCode': 'BTC'})])[0], 403)

    def test_legacy_goals_are_php_and_cannot_be_silently_redenominated(self):
        path = 'users/owner/goals/legacy'
        self.assertEqual(r.commit([s.write(path, {'savedAmount': 100.0, 'targetAmount': 500.0})])[0], 200)
        self.assertEqual(r.commit([s.write(path, {'currencyCode': 'EUR'}, True)])[0], 403)
        self.assertEqual(r.commit([s.write(path, {'currencyCode': 'PHP'}, True)])[0], 200)

    def test_cross_withdrawal_commits_locked_metadata_and_balance_together(self):
        self.assertEqual(r.commit(self.cross_withdrawal())[0], 200)
        record = s.read(f'{r.GOAL}/transactions/withdrawal')
        self.assertEqual(record['amount'], 500)
        self.assertEqual(record['conversion']['inputAmount'], 10)
        self.assertEqual(s.read(r.GOAL)['savedAmount'], 4500)
        self.assertEqual(r.commit([s.write(f'{r.GOAL}/transactions/withdrawal', {'conversion': conversion(rate=60)}, True)])[0], 403)

    def test_cross_withdrawal_rejects_wrong_amount_currency_stale_rate_and_forged_schema(self):
        for key, value in [('exchangeRate', 60.0), ('goalCurrencyCode', 'EUR'), ('inputCurrencyCode', 'BTC'),
                           ('inputAmount', -1), ('rateProvider', 'fake'),
                           ('rateTimestamp', datetime.now(timezone.utc) - timedelta(days=7))]:
            metadata = conversion(); metadata[key] = value
            self.assertEqual(r.commit(self.cross_withdrawal(metadata))[0], 403, key)
        metadata = conversion(); metadata['secret'] = 'no'
        self.assertEqual(r.commit(self.cross_withdrawal(metadata))[0], 403)
        self.assertEqual(s.read(r.GOAL)['savedAmount'], 5000)

    def test_currency_deposit_requires_atomic_pair_and_metadata_is_immutable(self):
        record = {'amount': 500.0, 'note': 'saved', 'type': 'deposit', 'currencyCode': 'PHP',
                  'conversion': conversion(), 'date': s.STAMP}
        writes = [s.write(r.GOAL, {'savedAmount': 5500.0, 'lastDepositId': 'deposit', 'updatedAt': s.STAMP}, True),
                  s.write(f'{r.GOAL}/transactions/deposit', record)]
        self.assertEqual(r.commit([writes[0]])[0], 403)
        self.assertEqual(r.commit([writes[1]])[0], 403)
        status, result = r.commit(writes)
        self.assertEqual(status, 200, result)
        self.assertEqual(s.read(r.GOAL)['savedAmount'], 5500)
        self.assertEqual(r.commit([s.write(f'{r.GOAL}/transactions/deposit', {'amount': 600}, True)])[0], 403)

    def test_shared_cross_entries_preserve_centavo_invariants_and_owner_decrease(self):
        gid = s.rid()
        self.assertEqual(r.commit(s.creation(gid))[0], 200)
        writes = s.money(gid, amount=50000)
        writes[1]['update']['fields']['conversion'] = s.encode(conversion())
        status, result = r.commit(writes)
        self.assertEqual(status, 200, result)
        self.assertEqual(s.read(f'sharedGoals/{gid}')['currentCents'], 60025)
        writes = s.money(gid, amount=50000, withdrawal=True)
        writes[1]['update']['fields']['conversion'] = s.encode(conversion())
        self.assertEqual(r.commit(writes)[0], 200)
        self.assertEqual(s.read(f'sharedGoals/{gid}')['currentCents'], 10025)
        self.assertEqual(s.read(f'sharedGoals/{gid}')['personalDeposits']['owner'], 600.25)

    def test_shared_bad_conversion_cannot_commit_a_balance_or_ledger_change(self):
        gid = s.rid(); self.assertEqual(r.commit(s.creation(gid))[0], 200)
        writes = s.money(gid, amount=50000)
        writes[1]['update']['fields']['conversion'] = s.encode(conversion(rate=60))
        self.assertEqual(r.commit(writes)[0], 403)
        self.assertEqual(s.read(f'sharedGoals/{gid}')['currentCents'], 10025)
        self.assertEqual(r.commit([s.write(f'sharedGoals/{gid}', {'currencyCode': 'USD'}, True)])[0], 403)

    def test_clients_cannot_write_global_rates_or_another_users_goals(self):
        self.assertEqual(r.commit([s.write('exchangeRates/latest', {'base': 'USD', 'rate': 1})])[0], 403)
        self.assertEqual(r.commit([s.write(r.GOAL, {'savedAmount': 5001}, True)], uid='stranger')[0], 403)
