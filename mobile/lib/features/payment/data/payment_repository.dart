import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class PaymentRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  Future<void> submitPayment({
    required int year,
    required double amount,
    required String paymentMode,
    required XFile receiptImage,
    String? transactionRef,
  }) async {
    try {
      final formData = FormData.fromMap({
        'year':         year.toString(),
        'amount':       amount.toStringAsFixed(2),
        'payment_mode': paymentMode,
        if (transactionRef != null && transactionRef.isNotEmpty)
          'transaction_ref': transactionRef,
        'receipt_image': await MultipartFile.fromFile(
          receiptImage.path,
          filename: 'receipt.jpg',
        ),
      });
      await _dio.post(ApiConstants.submitPayment, data: formData);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<dynamic>> getSubmittedPayments() async {
    try {
      final res = await _dio.get(ApiConstants.submittedPayments);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> reviewPayment(int id, String action, {String? rejectionReason}) async {
    try {
      final data = <String, dynamic>{'action': action};
      if (action == 'reject' && rejectionReason != null && rejectionReason.isNotEmpty) {
        data['rejection_reason'] = rejectionReason;
      }
      await _dio.patch(ApiConstants.reviewPayment(id), data: data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<dynamic>> getMyPayments() async {
    try {
      final res = await _dio.get(ApiConstants.myPayments);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
