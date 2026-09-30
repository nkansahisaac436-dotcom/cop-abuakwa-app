import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/transfer/data/transfer_repository.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/transfer_request_model.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return SupabaseTransferRepository();
});

final pendingTransferRequestsProvider = FutureProvider<List<TransferRequestModel>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.getPendingTransferRequests();
});

final tenureArchivesProvider = FutureProvider.family<List<TenureArchiveModel>, String>((ref, search) async {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.getArchives(searchQuery: search);
});

final transferNotifierProvider = AsyncNotifierProvider<TransferNotifier, void>(() {
  return TransferNotifier();
});

class TransferNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> requestTransfer() async {
    state = const AsyncValue.loading();
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final repo = ref.read(transferRepositoryProvider);
      await repo.requestTransfer(
        pastorId: user.id,
        tenureId: 't0000000-0000-0000-0000-000000000001',
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> approveTransfer(String requestId, {String? note}) async {
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(transferRepositoryProvider);
    await repo.approveTransfer(
      requestId: requestId,
      decidedByUserId: user?.id ?? 'area-head-user',
      note: note,
    );
    ref.invalidate(pendingTransferRequestsProvider);
    ref.invalidate(tenureArchivesProvider(''));
  }

  Future<void> rejectTransfer(String requestId, String note) async {
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(transferRepositoryProvider);
    await repo.rejectTransfer(
      requestId: requestId,
      decidedByUserId: user?.id ?? 'area-head-user',
      note: note,
    );
    ref.invalidate(pendingTransferRequestsProvider);
  }
}
