import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(),
);

final submittedPaymentsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(paymentRepositoryProvider).getSubmittedPayments();
});

final myPaymentsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(paymentRepositoryProvider).getMyPayments();
});

class PaymentNotifier extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repo;

  PaymentNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> submitPayment({
    required int year,
    required double amount,
    required String paymentMode,
    required XFile receiptImage,
    String? transactionRef,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.submitPayment(
        year:           year,
        amount:         amount,
        paymentMode:    paymentMode,
        receiptImage:   receiptImage,
        transactionRef: transactionRef,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reviewPayment(int id, String action, {String? rejectionReason}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reviewPayment(id, action, rejectionReason: rejectionReason);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final paymentNotifierProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<void>>((ref) {
  return PaymentNotifier(ref.watch(paymentRepositoryProvider));
});
