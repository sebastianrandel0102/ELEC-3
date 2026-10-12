"""Run unprivileged Spark transactions and rules against an isolated demo emulator.
Never reads deployment credentials or connects to the configured Firebase project.
Usage: py -3 test/run_shared_emulator.py --java "C:/Program Files/Android/Android Studio/jbr/bin/java.exe"
"""
import argparse
import sys
import firestore_withdrawal_rules_test as regression

# A separate port allows the personal regression runner to operate independently.
regression.PORT = 8087
regression.HOST = f"http://127.0.0.1:{regression.PORT}"

from shared_spark_rules_test import SparkRulesTests
from currency_rules_test import CurrencyRulesTests

PersonalRulesTests = regression.WithdrawalRulesTests

class AllEmulatorTests(PersonalRulesTests, SparkRulesTests, CurrencyRulesTests):
    def setUp(self):
        if self._testMethodName in CurrencyRulesTests.__dict__:
            CurrencyRulesTests.setUp(self)
        elif self._testMethodName in SparkRulesTests.__dict__:
            SparkRulesTests.setUp(self)
        else:
            PersonalRulesTests.setUp(self)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="java")
    parser.add_argument("--port", type=int, default=8087)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Use a port between 1024 and 65535.")
    regression.PORT = args.port
    regression.HOST = f"http://127.0.0.1:{args.port}"
    sys.argv = [sys.argv[0], "--java", args.java]
    regression.WithdrawalRulesTests = AllEmulatorTests
    sys.exit(regression.main())
