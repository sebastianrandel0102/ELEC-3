# Inactive callable prototype

This directory preserves the earlier Cloud Functions implementation for reference.
The app now uses Spark-compatible transactions in `lib/shared_savings_store.dart`,
enforced by the root `firestore.rules`.

This prototype has a different schema. Do not deploy it against the active Spark
implementation. `firebase.json` has no Functions entry and Flutter has no callable
dependency. Run `py -3 test/run_shared_emulator.py` for active Spark tests. This
directory's Node tests cover only the inactive prototype.

See [Save Together documentation](../docs/save-together.md).
