import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ScreenUtil başlatıcı — F_AISUBCRIBE standardı.
///
/// db_explorer_app responsive davranışı:
/// - Tüm UI `.sp`, `.w`, `.h`, `.r` extension'larını kullanabilsin diye
///   ScreenUtil initialize edilmeli.
/// - Design size: iPhone 14 Pro referansı (390x844).
///
/// Bootstrap sırasında `AppBootstrap.minimalInitialize()` içinden
/// çağrılır; çağrılmadan önce `.sp` çağrıldığında fallback size döner
/// (bkz. `AppTextStyles._getResponsiveSize`).
Future<void> initScreenUtil() async {
  await ScreenUtil.ensureScreenSize();
}
