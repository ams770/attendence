// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تسجيل الحضور';

  @override
  String get selfCheckInProgress =>
      'جاري التحقق من نماذج الذكاء الاصطناعي وموارد النظام...';

  @override
  String get selfCheckPassed => 'تم التحقق من جميع النماذج بنجاح.';

  @override
  String get selfCheckFailedTitle => 'فشل فحص بدء التشغيل';

  @override
  String get selfCheckFailedDescription =>
      'لا يمكن بدء تشغيل التطبيق بسبب تعذر تهيئة نموذج أو أكثر من نماذج الذكاء الاصطناعي.';

  @override
  String get failedModelsHeader => 'النماذج المتعثرة';

  @override
  String get verifiedModelsHeader => 'النماذج المؤكدة';

  @override
  String get modelNameLabel => 'النموذج';

  @override
  String get expectedPathLabel => 'المسار';

  @override
  String get reasonLabel => 'السبب';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get statusPassed => 'ناجح';

  @override
  String get statusFailed => 'فاشل';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get homeStatusReady => 'النظام جاهز لتسجيل الحضور.';

  @override
  String get homeDevCameraAction => 'شاشة فحص الكاميرا والإطارات';

  @override
  String get devCameraTitle => 'فحص الكاميرا ومعالجة الإطارات';

  @override
  String get devCameraPermissionRequired =>
      'إذن الكاميرا مطلوب لعرض البث ومعالجة الإطارات.';

  @override
  String get devCameraGrantPermission => 'منح الإذن';

  @override
  String get devCameraOpenSettings => 'فتح الإعدادات';

  @override
  String get devCameraFpsLabel => 'إطار/ثانية';

  @override
  String get devCameraLatencyLabel => 'زمن المعالجة';

  @override
  String get devCameraTierLabel => 'فئة الجهاز';

  @override
  String get devCameraDroppedFrames => 'المتجاهل';

  @override
  String get devCameraProcessedFrames => 'المعالج';

  @override
  String get devCameraThumbnailTitle => 'عينة البكسل العمودية غير المعكوسة';

  @override
  String get devCameraTierOverrideLabel => 'تجاوز فئة الجهاز يدويًا';

  @override
  String get devCameraRerunBenchmark => 'إعادة تشغيل قياس الأداء';

  @override
  String get devCameraBenchmarking => 'جاري قياس الأداء...';

  @override
  String get devCameraTierAuto => 'تلقائي (مبني على قياس الأداء)';

  @override
  String get devCameraTierLow => 'فئة منخفضة';

  @override
  String get devCameraTierMid => 'فئة متوسطة';

  @override
  String get devCameraTierHigh => 'فئة مرتفعة';

  @override
  String get homeDevDetectionAction => 'شاشة فحص كشف الوجه والمحاذاة';

  @override
  String get devDetectionTitle => 'فحص كشف الوجه والمحاذاة';

  @override
  String get devDetectionTrackingId => 'معرف التتبع';

  @override
  String get devDetectionEulerAngles =>
      'الوضعية (الانعراج / الانحدار / التمايل)';

  @override
  String get devDetectionEyeOpen => 'فتح العينين (يسار / يمين)';

  @override
  String get devDetectionSmiling => 'الابتسام';

  @override
  String get devDetectionQualityIssues => 'حالة الجودة';

  @override
  String get devDetectionQualityPass => 'تم استيفاء معايير الجودة';

  @override
  String get devDetectionAlignedThumbnail => 'صورة الوجه المحاذاة 112×112';

  @override
  String get devDetectionFaceStats => 'الحدة / الإضاءة / التوهج';

  @override
  String get qualityIssueNoFace => 'لم يتم رصد أي وجه';

  @override
  String get qualityIssueMultipleFaces => 'يُسمح بشخص واحد فقط';

  @override
  String get qualityIssueTooSmall => 'اقترب أكثر من الكاميرا';

  @override
  String get qualityIssueNotInsideGuide => 'ضع الوجه داخل الشكل البيضاوي';

  @override
  String get qualityIssuePoseOutOfRange => 'انظر مباشرة إلى الكاميرا';

  @override
  String get qualityIssueLandmarksMissing => 'تأكد من وضوح ملامح الوجه بالكامل';

  @override
  String get qualityIssueTooBlurry => 'ثبّت الحركة';

  @override
  String get qualityIssueTooDark => 'انتقل إلى مكان أكثر إضاءة';

  @override
  String get qualityIssueTooBright => 'قلل شدة الإضاءة الموجهة';

  @override
  String get qualityIssueGlare => 'تجنب التوهج وانعكاس الضوء على الوجه';

  @override
  String get homeDevPassiveAction => 'شاشة فحص الحيوية السلبية';

  @override
  String get devPassiveTitle => 'فحص الحيوية السلبية (MiniFASNet)';

  @override
  String get devPassiveModelV2Label => 'MiniFASNetV2';

  @override
  String get devPassiveModelV1SeLabel => 'MiniFASNetV1SE';

  @override
  String get devPassiveMeanScore => 'متوسط الدرجة';

  @override
  String get devPassiveVerdict => 'القرار التراكمي';

  @override
  String get devPassiveVerdictPending => 'قيد الجمع';

  @override
  String get devPassiveVerdictPassed => 'ناجح (حقيقي)';

  @override
  String get devPassiveVerdictFailed => 'فاشل (تزييف)';

  @override
  String get devPassiveSamplesCount => 'العينات';

  @override
  String get devPassivePassingRatio => 'نسبة النجاح';

  @override
  String get devPassiveExportCsv => 'تصدير CSV';

  @override
  String get devPassiveResetSession => 'إعادة تعيين الجلسة';

  @override
  String get devPassiveStartSession => 'بدء الجلسة';

  @override
  String get devPassiveStopSession => 'إيقاف الجلسة';

  @override
  String get devPassiveModelsToRun => 'النماذج المشغلة';

  @override
  String get devPassiveModelOptionBoth => 'كلا النموذجين (V2 و V1SE)';

  @override
  String get devPassiveModelOptionV2Only => 'نموذج V2 فقط (فئة منخفضة)';

  @override
  String get devPassiveModelOptionV1SeOnly => 'نموذج V1SE فقط';

  @override
  String get devPassiveCsvExportEmpty => 'لا توجد عينات مسجلة للتصدير.';

  @override
  String get devPassiveCsvExportSuccess => 'تم تصدير ملف CSV بنجاح.';

  @override
  String get homeDevChallengesAction => 'شاشة فحص التحديات النشطة';

  @override
  String get challengesDevTitle => 'التحديات النشطة والتحليل الزمني';

  @override
  String get challengeLookStraight => 'انظر مباشرة إلى الكاميرا';

  @override
  String get challengeBlink => 'ارمش بعينيك';

  @override
  String get challengeTurnLeft => 'أدر رأسك إلى اليسار';

  @override
  String get challengeTurnRight => 'أدر رأسك إلى اليمين';

  @override
  String get challengeSmile => 'ابتسم';

  @override
  String get challengeStatusPending => 'قيد الانتظار';

  @override
  String get challengeStatusPassed => 'ناجح';

  @override
  String get challengeStatusFailed => 'فاشل';

  @override
  String get challengeReasonTimeout => 'انتهت مهلة التحدي';

  @override
  String get challengeReasonTrackingLost => 'فُقد الوجه';

  @override
  String get challengeReasonTrackingChanged => 'تغير الوجه';

  @override
  String get challengeReasonWrongDirection => 'تم الالتفاف في الاتجاه الخاطئ';

  @override
  String get newChallengesAction => 'تحديات عشوائية جديدة';

  @override
  String get resetChallengeAction => 'إعادة تعيين';

  @override
  String get temporalMicroMotion => 'الحركة الدقيقة';

  @override
  String get temporalLoopDetection => 'كشف التكرار';

  @override
  String get temporalPlanarRigidity => 'الصلابة وثلاثية الأبعاد';

  @override
  String get temporalConfidence => 'الثقة الزمنية';

  @override
  String get flashChallengeAction => 'اختبار تحدي الوميض';

  @override
  String get flashStatus => 'انعكاس الوميض';

  @override
  String get flashVerdictPassed => 'نجح اختبار الوميض';

  @override
  String get flashVerdictFailed => 'فشل اختبار الوميض';

  @override
  String get flashVerdictInconclusive => 'غير حاسم';

  @override
  String get flashVerdictSkipped => 'تم التجاوز (الإضاءة غير مناسبة)';

  @override
  String get startVerification => 'بدء التحقق من الحضور';

  @override
  String get verificationTitle => 'التحقق من الوجه';

  @override
  String get statePositioning => 'ضع وجهك داخل الشكل البيضاوي';

  @override
  String get stateNeutral => 'انظر مباشرة إلى الكاميرا';

  @override
  String get stateFinalizing => 'جارٍ التحقق من الحيوية... يرجى التثبيت';

  @override
  String get stateSucceeded => 'تم التحقق بنجاح';

  @override
  String get stateFailed => 'فشل التحقق';

  @override
  String get stateLocked => 'التحقق مقفل';

  @override
  String lockoutCountdown(int seconds) {
    return 'تم القفل بسبب تكرار المحاولات الفاشلة. أعد المحاولة بعد $seconds ثانية.';
  }

  @override
  String totalTimeRemaining(int seconds) {
    return 'متبقي $seconds ث';
  }

  @override
  String get reasonTimeout => 'انتهت مهلة الجلسة';

  @override
  String get reasonFaceLost => 'فُقد تتبع الوجه';

  @override
  String get reasonTrackingChanged => 'تم اكتشاف وجه مختلف';

  @override
  String get reasonChallengeFailed => 'فشل التحدي التفاعلي';

  @override
  String get reasonPassiveFailed => 'فشل فحص الحيوية التلقائي';

  @override
  String get reasonPassiveHardFloorViolation =>
      'مخالفة أمنية: تم رصد اشتباه تبديل الصورة';

  @override
  String get reasonTemporalFailed => 'فشل فحص الحركة الطبيعية';

  @override
  String get reasonFlashFailed => 'فشل اختبار انعكاس وميض الشاشة';

  @override
  String get reasonCancelled => 'تم إلغاء الجلسة';

  @override
  String get reasonTooManyAttempts =>
      'تجاوزت عدد المحاولات الفاشلة المسموح بها';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionDone => 'تم';

  @override
  String get resultTitle => 'نتيجة التحقق';

  @override
  String get resultPassedTitle => 'تم تأكيد الحيوية بنجاح';

  @override
  String get resultFailedTitle => 'فشل التحقق من الحيوية';

  @override
  String resultDuration(int duration) {
    return 'المدة: $duration مللي ثانية';
  }

  @override
  String resultPassiveScore(String score) {
    return 'متوسط درجة الحيوية التلقائية: $score';
  }

  @override
  String resultTemporalScore(String score) {
    return 'ثقة الحركة الزمنية: $score';
  }

  @override
  String resultChallengesCompleted(int count) {
    return 'التحديات المكتملة: $count';
  }

  @override
  String resultCropsCount(int count) {
    return 'الصور الملتقطة المحاذاة: $count';
  }

  @override
  String get employeesTitle => 'الموظفون';

  @override
  String get enrollEmployee => 'تسجيل موظف';

  @override
  String get reEnrollEmployee => 'إعادة تسجيل الوجه';

  @override
  String get employeeName => 'اسم الموظف';

  @override
  String get employeeCode => 'كود الموظف';

  @override
  String get employeeNameHint => 'مثال: محمد أحمد';

  @override
  String get employeeCodeHint => 'مثال: EMP-101';

  @override
  String get employeeCodeExists => 'كود الموظف موجود مسبقاً';

  @override
  String get employeeNameRequired => 'اسم الموظف مطلوب';

  @override
  String get employeeCodeRequired => 'كود الموظف مطلوب';

  @override
  String get noEmployeesFound => 'لا يوجد موظفون مسجلون حالياً.';

  @override
  String get searchEmployees => 'البحث بالاسم أو الكود';

  @override
  String get deleteEmployeeTitle => 'حذف الموظف';

  @override
  String deleteEmployeeConfirm(String name) {
    return 'هل أنت متأكد من حذف $name؟ سيتم حذف جميع البيانات الحيوية المرتبطة به نهائياً.';
  }

  @override
  String get deleteAction => 'حذف';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get saveAction => 'حفظ';

  @override
  String get editEmployee => 'تعديل بيانات الموظف';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusInactive => 'غير نشط';

  @override
  String get needsReEnrollmentBadge => 'يتطلب إعادة التسجيل';

  @override
  String get enrollmentTitle => 'تسجيل بصمة الوجه';

  @override
  String get enrollmentFormHeader => 'بيانات الموظف';

  @override
  String get enrollmentStartCapture => 'بدء التقاط بصمة الوجه';

  @override
  String enrollmentSampleCount(int current, int total) {
    return 'عينة $current من $total';
  }

  @override
  String get poseFront => 'انظر مباشرة إلى الكاميرا';

  @override
  String get poseSlightLeft => 'أدر رأسك قليلاً إلى اليسار';

  @override
  String get poseSlightRight => 'أدر رأسك قليلاً إلى اليمين';

  @override
  String get poseSlightUp => 'أمل رأسك قليلاً إلى الأعلى';

  @override
  String get poseSlightDown => 'أمل رأسك قليلاً إلى الأسفل';

  @override
  String get enrollmentProcessing => 'جاري معالجة وتشفير القوالب الحيوية...';

  @override
  String get duplicateWarningTitle => 'تحذير: تطابق وجه مسجل';

  @override
  String duplicateWarningMessage(String name, String code, String score) {
    return 'هذا الوجه يتطابق بشكل وثيق مع الموظف $name ($code) بنسبة تشابه $score. هل ترغب في المتابعة على أي حال؟';
  }

  @override
  String get confirmEnrollmentAction => 'المتابعة على أي حال';

  @override
  String get enrollmentSuccess => 'تم تسجيل الموظف بنجاح';

  @override
  String get identificationTitle => 'التعرف على الموظف';

  @override
  String get identifiedEmployee => 'الموظف المطابق';

  @override
  String matchScore(String percent, String score) {
    return 'التطابق: $percent% (الدرجة: $score)';
  }

  @override
  String get noMatchFound => 'لم يتم التعرف على الوجه';

  @override
  String get noMatchDescription =>
      'لا يوجد موظف مسجل يتطابق مع هذا الوجه فوق الحد المطلوب.';

  @override
  String get ambiguousMatch => 'تعرف غير مؤكد';

  @override
  String ambiguousDescription(String name1, String name2) {
    return 'درجة التشابه كانت متقاربة جداً بين $name1 و $name2. يرجى إعادة المحاولة.';
  }

  @override
  String get noEnrolledEmployees => 'لا يوجد موظفون مسجلون';

  @override
  String get noEnrolledDescription =>
      'يرجى تسجيل الموظفين قبل بدء تسجيل الحضور.';

  @override
  String get homeEmployeesAction => 'إدارة الموظفين والتسجيل';
}
