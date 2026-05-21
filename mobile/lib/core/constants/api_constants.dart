class ApiConstants {
  // Émulateur Android : 10.0.2.2:8000 — appareil physique : IP locale ex. 192.168.1.X:8000
static const baseUrl = 'http://localhost:8000/api';
  static const requestOtp  = '/auth/request-otp/';
  static const verifyOtp   = '/auth/verify-otp/';
  static const setPin      = '/auth/set-pin/';
  static const login       = '/auth/login/';
  static const resetPin        = '/auth/reset-pin/request/';
  static const resetPinConfirm = '/auth/reset-pin/confirm/';

  static const register    = '/members/register/';
  static const me          = '/members/me/';
  static const membersList = '/members/';
  static const pending     = '/members/pending/';
  static String validate(int id) => '/members/$id/validate/';

  static const card              = '/payments/card/';
  static const myPayments        = '/payments/me/';
  static const submitPayment     = '/payments/submit/';
  static const submittedPayments = '/payments/submitted/';
  static String reviewPayment(int id) => '/payments/$id/review/';

  static const stats  = '/dashboard/stats/';
  static const export = '/dashboard/export/';

  // Posts & Événements
  static const posts       = '/posts/';
  static const postsCreate = '/posts/create/';
  static String postDetail(int id)  => '/posts/$id/';
  static String postPublish(int id) => '/posts/$id/publish/';

  static const events       = '/events/';
  static const eventsCreate = '/events/create/';
  static String eventDetail(int id)       => '/events/$id/';
  static String eventJoin(int id)         => '/events/$id/join/';
  static String eventLeave(int id)        => '/events/$id/leave/';
  static String eventParticipants(int id) => '/events/$id/participants/';
  static String eventAttendance(int id)   => '/events/$id/attendance/';

  // Annuaire avancé (BF-10 à BF-13)
  static String memberDetail(int id) => '/members/$id/';
  static String membersSearch(String q, String? situation, int page) {
    final buf = StringBuffer('/members/?page=$page');
    if (q.isNotEmpty) buf.write('&search=${Uri.encodeComponent(q)}');
    if (situation != null && situation.isNotEmpty) buf.write('&situation=$situation');
    return buf.toString();
  }
}
