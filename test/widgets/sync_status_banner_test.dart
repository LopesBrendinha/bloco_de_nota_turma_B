import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/services/remote_data_source.dart';
import 'package:blocodenotasturmab/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    SyncStatus status, {
    VoidCallback? onRetry,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncStatusBanner(status: status, onRetry: onRetry ?? () {}),
        ),
      ),
    );
  }

  testWidgets('sem conexão, informa quantas alterações serão enviadas', (
    tester,
  ) async {
    await pump(
      tester,
      const SyncStatus(
        state: SyncState.failed,
        failure: RemoteErrorKind.offline,
        pendingChanges: 2,
      ),
    );

    expect(
      find.text(
        'Sem conexão. 2 alterações serão enviadas quando a internet voltar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('em caso de falha, permite tentar de novo', (tester) async {
    var retries = 0;
    await pump(
      tester,
      const SyncStatus(
        state: SyncState.failed,
        failure: RemoteErrorKind.permissionDenied,
      ),
      onRetry: () => retries++,
    );

    await tester.tap(find.text('Tentar de novo'));

    expect(retries, 1);
  });

  testWidgets('não mostra o botão quando está tudo salvo', (tester) async {
    await pump(tester, const SyncStatus(state: SyncState.synced, lastSyncAt: 0));

    expect(find.textContaining('Tudo salvo na nuvem'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });
}
