library default_connector;
// The real `firebase_data_connect` package may not be available in this
// workspace (generated code expects it). Provide a minimal, local stub
// implementation to satisfy the analyzer and unblock `flutter analyze`.
// This stub is intentionally tiny and non-functional. If you rely on the
// real Data Connect runtime, replace this file with the real generated
// connector or add the `firebase_data_connect` package to pubspec.yaml.
// no 'dart:convert' needed in the stub

// --- BEGIN STUBS for firebase_data_connect ---
enum CallerSDKType { generated, manual }

class ConnectorConfig {
  final String region;
  final String name;
  final String project;
  const ConnectorConfig(this.region, this.name, this.project);
}

/// Minimal stub of the FirebaseDataConnect API surface used by generated
/// connectors. This does NOT implement network calls. It's only present to
/// satisfy imports and the analyzer in environments where the real package
/// is not available.
class FirebaseDataConnect {
  FirebaseDataConnect._();

  static FirebaseDataConnect instanceFor({
    required ConnectorConfig connectorConfig,
    required CallerSDKType sdkType,
  }) {
    return FirebaseDataConnect._();
  }

  void useDataConnectEmulator(String host, int port) {
    // no-op stub
  }
}

// --- END STUBS ---

class DefaultConnector {
  static ConnectorConfig connectorConfig = const ConnectorConfig(
    'us-central1',
    'default',
    'studentsuite',
  );

  DefaultConnector({required this.dataConnect});

  static DefaultConnector get instance {
    return DefaultConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
