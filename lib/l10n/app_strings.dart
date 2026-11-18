class AppStrings {
  final bool ar;
  const AppStrings(this.ar);

  String get appTitle => 'BIG DUCK';
  String get vaultSealLabel => ar ? 'خزنة مشفرة' : 'Encrypted vault';
  String get previewUi => ar ? 'معاينة الواجهة' : 'Preview UI';

  // Tabs
  String get tabFiles => ar ? 'الملفات' : 'Files';
  String get tabRecent => ar ? 'الأخيرة' : 'Recent';
  String get tabTransfers => ar ? 'التحويلات' : 'Transfers';
  String get tabSettings => ar ? 'الإعدادات' : 'Settings';

  // Files screen
  String get recentTitle => ar ? 'الأخيرة' : 'Recent';
  String get upload => ar ? 'رفع' : 'Upload';
  String get searchHint =>
      ar ? 'ابحث في الخزنة المشفرة' : 'Search encrypted vault';
  String get myFiles => ar ? 'ملفاتي' : 'My files';
  String get folderWord => ar ? 'مجلد' : 'Folder';
  String foldersAndFiles(int folders, int files) =>
      ar ? '$folders مجلد، $files ملف' : '$folders folders, $files files';
  String get folderEmpty => ar ? 'المجلد فارغ' : 'This folder is empty';
  String get noMatching => ar ? 'لا توجد نتائج' : 'No matching items';
  String get emptyDesc => ar
      ? 'اضغط على رفع لتشفير وحفظ المستندات والصور أو الفيديو.'
      : 'Use Upload to encrypt and store documents, photos, or video.';
  String nothingMatched(String q) =>
      ar ? 'لا توجد نتائج مطابقة لـ "$q"' : 'No items match "$q"';

  // Filters & Sort
  String get filterAll => ar ? 'الكل' : 'All';
  String get filterFolders => ar ? 'مجلدات' : 'Folders';
  String get filterImages => ar ? 'صور' : 'Images';
  String get filterPdf => 'PDF';
  String get filterVideo => ar ? 'فيديو' : 'Video';
  String get filterOther => ar ? 'أخرى' : 'Other';

  String get sortByTitle => ar ? 'الترتيب حسب' : 'Sort by';
  String get sortDate => ar ? 'التاريخ' : 'Date';
  String get sortName => ar ? 'الاسم' : 'Name';
  String get sortSize => ar ? 'الحجم' : 'Size';

  // Multi-select
  String selectedCount(int count) =>
      ar ? 'تم تحديد $count' : '$count selected';
  String get selectAll => ar ? 'تحديد الكل' : 'Select all';
  String get clearSelection => ar ? 'إلغاء' : 'Cancel';
  String get moveAction => ar ? 'نقل' : 'Move';
  String get renameAction => ar ? 'تسمية' : 'Rename';
  String get downloadAction => ar ? 'تنزيل' : 'Download';
  String get deleteAction => ar ? 'حذف' : 'Delete';

  // Move modal
  String get moveToTitle => ar ? 'نقل إلى مجلد' : 'Move to folder';
  String get rootFolderLabel =>
      ar ? 'ملفاتي (الرئيسية)' : 'My files (root)';

  // Inspectors & Upload
  String get encryptAndUpload => ar ? 'تشفير ورفع' : 'Encrypt and upload';
  String get uploadDesc => ar
      ? 'تُقسَّم الملفات وتُشفَّر محلياً بـ AES-256-GCM قبل الرفع.'
      : 'Files are split and AES-256-GCM encrypted on this device before upload.';
  String get uploadDocs => ar ? 'رفع مستندات' : 'Upload documents';
  String get uploadDocsSub => ar
      ? 'ملفات PDF أو أرشيف أو أي ملف'
      : 'PDFs, archives, or any file';
  String get uploadMedia => ar ? 'رفع صور وفيديو' : 'Upload photos and video';
  String get uploadMediaSub =>
      ar ? 'اختر من معرض الصور' : 'Select from your camera roll';
  String get newFolder => ar ? 'مجلد جديد' : 'New folder';
  String get folderNameHint => ar ? 'اسم المجلد' : 'Folder name';
  String get cancel => ar ? 'إلغاء' : 'Cancel';
  String get create => ar ? 'إنشاء' : 'Create folder';
  String get save => ar ? 'حفظ التغييرات' : 'Save changes';

  String get openFolder => ar ? 'فتح المجلد' : 'Open folder';
  String get renameFolder => ar ? 'إعادة تسمية المجلد' : 'Rename folder';
  String get moveFolder => ar ? 'نقل المجلد' : 'Move folder';
  String get deleteFolder => ar ? 'حذف المجلد' : 'Delete folder';

  String get previewPdf => ar ? 'معاينة PDF' : 'Preview PDF';
  String get previewImage => ar ? 'معاينة الصورة' : 'Preview image';
  String get downloadAndDecrypt =>
      ar ? 'تنزيل وفك التشفير' : 'Download and decrypt';
  String get renameFile => ar ? 'إعادة تسمية الملف' : 'Rename file';
  String get moveFile => ar ? 'نقل الملف' : 'Move file';
  String get deleteFile => ar ? 'حذف الملف' : 'Delete file';

  // Transfers
  String get transfersTitle => ar ? 'التحويلات' : 'Transfers';
  String get transfersSub => ar
      ? 'الرفع والتنزيل المشفر عبر تليجرام'
      : 'Encrypted uploads and downloads over Telegram';
  String get noTransfers => ar ? 'لا توجد تحويلات نشطة' : 'No active transfers';
  String get noTransfersDesc => ar
      ? 'ستظهر هنا الملفات التي ترفعها أو تنزلها مع نسبة التقدم.'
      : 'Uploaded and downloaded files appear here with live progress.';

  // Settings
  String get settingsTitle => ar ? 'الإعدادات' : 'Settings';
  String get settingsSub =>
      ar ? 'المظهر والتشفير وإدارة الخزنة' : 'Vault controls and preferences';
  String get appearanceTitle => ar ? 'المظهر واللغة' : 'Appearance and language';
  String get themeSystem => ar ? 'تلقائي' : 'System';
  String get themeLight => ar ? 'فاتح' : 'Light';
  String get themeDark => ar ? 'داكن' : 'Dark';
  String get storageStatsTitle =>
      ar ? 'إحصائيات المساحة' : 'Vault storage';
  String get cacheTitle => ar ? 'الكاش المحلي للتنزيلات' : 'Local download cache';
  String get clearCache => ar ? 'مسح الكاش' : 'Clear cache';
  String get refresh => ar ? 'تحديث' : 'Refresh';
  String get storageDestination =>
      ar ? 'وجهة التخزين' : 'Storage destination';
  String get loadGroups => ar ? 'تحميل المجموعات' : 'Load groups';
  String get savedMessagesDefault =>
      ar ? 'الرسائل المحفوظة (افتراضي)' : 'Saved Messages (default)';
  String get uploadChunkSize => ar ? 'حجم جزء الرفع' : 'Upload chunk size';
  String get encryptionTitle =>
      ar ? 'تشفير AES-256-GCM' : 'AES-256-GCM encryption';
  String get encryptionSub => ar
      ? 'تُشفّر الملفات بـ Argon2id + AES-256-GCM قبل مغادرة جهازك.'
      : 'Files are encrypted with Argon2id + AES-256-GCM before leaving this device.';
  String get encPassHint =>
      ar ? 'كلمة مرور تشفير الخزنة' : 'Vault encryption password';
  String get applyPassword => ar ? 'تطبيق كلمة المرور' : 'Apply password';
  String get clear => ar ? 'مسح' : 'Clear';
  String get backupRestoreTitle =>
      ar ? 'النسخ الاحتياطي واستعادة الفهرس' : 'Index backup and restore';
  String get backupPassHint =>
      ar ? 'كلمة مرور النسخة الاحتياطية' : 'Backup password';
  String get msgIdHint =>
      ar ? 'رقم الرسالة (اختياري للاستعادة)' : 'Message ID (optional for restore)';
  String get backupIndex => ar ? 'نسخ الفهرس' : 'Backup index';
  String get restoreIndex => ar ? 'استعادة الفهرس' : 'Restore index';
  String get exitPreview => ar
      ? 'الخروج من وضع المعاينة (العودة لتسجيل الدخول)'
      : 'Exit preview mode';

  // Biometric lock & Security
  String get securityTitle => ar ? 'الأمان وقفل الخزنة' : 'Vault lock & security';
  String get biometricLockTitle =>
      ar ? 'القفل بالبصمة أو الوجه' : 'Biometric / Face ID lock';
  String get biometricLockSub => ar
      ? 'اطلب المصادقة عند فتح التطبيق أو العودة من الخلفية.'
      : 'Require biometric unlock when opening or returning to the vault.';
  String get biometricUnavailable => ar
      ? 'المصادقة الحيوية غير مهيأة على هذا الجهاز.'
      : 'Biometric authentication is not set up on this device.';
  String get vaultLockedTitle => ar ? 'الخزنة مقفلة' : 'Vault locked';
  String get vaultLockedSub => ar
      ? 'أكّد هويتك للوصول إلى ملفاتك المشفّرة.'
      : 'Verify your identity to access encrypted files.';
  String get unlockVault => ar ? 'فتح بالبصمة' : 'Unlock vault';

  // Global search, media preview & transfer controls
  String searchResultsLabel(int count) =>
      ar ? 'نتائج البحث الشامل ($count)' : 'Vault search results ($count)';
  String get pauseAction => ar ? 'إيقاف مؤقت' : 'Pause';
  String get resumeAction => ar ? 'استكمال' : 'Resume';
  String get previewVideo => ar ? 'تشغيل الفيديو' : 'Play video';
  String get previewAudio => ar ? 'تشغيل الصوت' : 'Play audio';

  // Auth screen
  String get authStepMountTitle =>
      ar ? 'اربط خزنة تيليجرام' : 'Mount your Telegram vault';
  String get authStepMountSub => ar
      ? 'تُقسَّم الملفات وتُشفَّر محلياً بـ AES-256-GCM قبل رفعها.'
      : 'Files are split and AES-256-GCM encrypted locally before upload.';
  String get authStepConnectTitle =>
      ar ? 'جاري الاتصال بتيليجرام' : 'Connecting to Telegram';
  String get authStepConnectSub => ar
      ? 'تأسيس جلسة MTProto مشفرة.'
      : 'Establishing encrypted MTProto session.';
  String get authStepPhoneTitle =>
      ar ? 'أكّد رقم هاتفك' : 'Verify your phone number';
  String get authStepPhoneSub => ar
      ? 'سيرسل تيليجرام رمز دخول لمرة واحدة إلى جلستك النشطة.'
      : 'Telegram will send a one-time login code to your active session.';
  String get authStepCodeTitle =>
      ar ? 'أدخل رمز التحقق' : 'Enter the login code';
  String authStepCodeSub(String? phone) => phone != null && phone.isNotEmpty
      ? (ar ? 'تم إرسال الرمز إلى $phone' : 'Code sent to $phone')
      : (ar
          ? 'تحقق من رسالة تيليجرام للحصول على الرمز المكون من 5 أرقام.'
          : 'Check your active Telegram session for the 5-digit code.');
  String get authStepPassTitle =>
      ar ? 'التحقق بخطوتين (2FA)' : 'Unlock with 2FA password';
  String authStepPassSub(String? hint) => hint != null && hint.isNotEmpty
      ? (ar ? 'تلميح كلمة المرور: $hint' : 'Password hint: $hint')
      : (ar
          ? 'التحقق بخطوتين مفعّل على حساب تيليجرام هذا.'
          : 'Two-step verification is enabled on this Telegram account.');
  String get apiIdLabel => 'API ID';
  String get apiIdHint =>
      ar ? 'الرقم التعريفي من my.telegram.org' : 'Numeric ID from my.telegram.org';
  String get apiHashLabel => 'API hash';
  String get apiHashHint =>
      ar ? 'مفتاح من 32 حرفاً' : '32-character hex string';
  String get apiCredsHelper => ar
      ? 'احصل على API ID و API Hash من my.telegram.org'
      : 'Get your API ID & hash at my.telegram.org';
  String get phoneLabel => ar ? 'الهاتف' : 'Phone';
  String get phoneHint => '+20 100 000 0000';
  String get codeLabel => ar ? 'الرمز' : 'Code';
  String get codeHint =>
      ar ? 'رمز من 5 أرقام' : '5-digit login code';
  String get passwordLabel => ar ? 'كلمة المرور' : 'Password';
  String get passwordHint =>
      ar ? 'كلمة مرور التحقق بخطوتين' : '2FA vault password';
  String get continueCta => ar ? 'متابعة' : 'Continue';
  String get connectingCta => ar ? 'جاري الاتصال...' : 'Connecting...';
  String get sendCodeCta => ar ? 'إرسال الرمز' : 'Send code';
  String get verifyCodeCta => ar ? 'تحقق من الرمز' : 'Verify code';
  String get changePhoneOrKeys =>
      ar ? 'تغيير الرقم أو مفاتيح API' : 'Change phone or API keys';
  String get nativeCoreReady => ar ? 'محرك Rust نشط' : 'Rust core ready';

  // Account, Connection & Redesign Headers
  String get statusSynced => ar ? 'متصل' : 'Synced';
  String get statusConnecting => ar ? 'جاري الاتصال...' : 'Connecting...';
  String get statusOfflineTap =>
      ar ? 'غير متصل، اضغط للاتصال' : 'Offline, tap to reconnect';
  String get accountSectionTitle =>
      ar ? 'الحساب والأمان' : 'Account and security';
  String get displayAndStorageTitle =>
      ar ? 'العرض والتخزين' : 'Display and storage';
  String get signOut => ar ? 'تسجيل الخروج' : 'Sign out';
  String get signOutSub => ar
      ? 'فصل جلسة تيليجرام المحفوظة من هذا الجهاز'
      : 'Disconnect saved Telegram session on this device';
  String get keyActiveBadge => ar ? 'المفتاح مفعّل' : 'Key active';
  String get keyUnsetBadge => ar ? 'بدون تشفير' : 'Unencrypted';
  String get uploadLabel => ar ? 'رفع' : 'Upload';
  String get downloadLabel => ar ? 'تنزيل' : 'Download';
  String activeCountLabel(int n) => ar ? '$n نشط' : '$n active';
  String pausedCountLabel(int n) => ar ? '$n متوقف' : '$n paused';
  String completedCountLabel(int n) => ar ? '$n مكتمل' : '$n done';
  String itemsCountLabel(int n) => ar ? '$n عنصر' : '$n items';
  String get totalVaultLabel => ar ? 'إجمالي الخزنة' : 'Total vault';

  // Localized Toasts & Validation
  String get invalidApiCreds => ar
      ? 'أدخل رقم API ID و API Hash صحيحين.'
      : 'Enter a valid numeric API ID and API Hash.';
  String get nativeLibUnavailable => ar
      ? 'مكتبة Rust غير متوفرة في هذا البناء. استخدم معاينة الواجهة.'
      : 'Native Rust core library is not loaded on this build. Use Preview UI to explore.';
  String get previewUiActivated =>
      ar ? 'تم تفعيل وضع المعاينة' : 'Preview UI active (demo mode)';
  String createdFolderToast(String name) =>
      ar ? 'تم إنشاء المجلد "$name"' : 'Created folder "$name"';
  String renamedToToast(String name) =>
      ar ? 'تم التعديل إلى "$name"' : 'Renamed to "$name"';
  String get cannotMoveIntoSelf => ar
      ? 'لا يمكن نقل مجلد داخل نفسه'
      : 'Cannot move a folder inside itself';
  String get movedToast => ar ? 'تم النقل' : 'Moved item';
  String movedManyToast(int count) =>
      ar ? 'تم نقل $count عنصر' : 'Moved $count item(s)';
  String get deletedToast => ar ? 'تم الحذف' : 'Deleted';
  String deletedManyToast(int count) =>
      ar ? 'تم حذف $count عنصر' : 'Deleted $count item(s)';
  String queuedUploadToast(int count) => ar
      ? 'تمت إضافة $count ملف للتشفير والرفع'
      : 'Queued $count file(s) for encrypted upload';
  String downloadingToast(String name) =>
      ar ? 'جاري تنزيل "$name"...' : 'Downloading "$name"...';
  String demoDownloadToast(String name) => ar
      ? 'وضع المعاينة: تم محاكاة تنزيل "$name"'
      : 'Demo mode: "$name" download simulated';
  String get loadedGroupsToast =>
      ar ? 'تم تحميل مجموعات تيليجرام' : 'Loaded Telegram groups';
  String storageChangedToast(bool toSavedMessages) => toSavedMessages
      ? (ar ? 'الوجهة: الرسائل المحفوظة' : 'Storage set to Saved Messages')
      : (ar ? 'الوجهة: المجموعة المحددة' : 'Storage set to Group');
  String storageSetToChatToast(String name) =>
      ar ? 'تم تعيين الوجهة: $name' : 'Storage set to "$name"';
  String vaultCreatedToast(String name) => ar
      ? 'تم إنشاء "$name" وتعيينها كوجهة للتخزين'
      : 'Created "$name" and set as storage destination';

  // Filtered Storage Destination & Vault Creation
  String get storageDestSub => ar
      ? 'يعرض فقط الجروبات والقنوات الخاصة بك أو التي تملك صلاحية النشر فيها'
      : 'Only groups and channels you own or can post to are listed';
  String get changeDestination => ar ? 'تغيير' : 'Change';
  String get searchVaultChatsHint =>
      ar ? 'ابحث عن جروب أو قناة...' : 'Search owned groups or channels';
  String get filterOwnedByMe => ar ? 'أنشأتها بنفسي' : 'Owned by me';
  String get filterAdminAccess => ar ? 'صلاحية مشرف' : 'Admin access';
  String get roleOwnerBadge => ar ? 'المالك' : 'Owner';
  String get roleAdminBadge => ar ? 'مشرف' : 'Admin';
  String get privateBadge => ar ? 'خاص' : 'Private';
  String get groupKindLabel => ar ? 'جروب' : 'Group';
  String get channelKindLabel => ar ? 'قناة' : 'Channel';
  String membersCountLabel(int n) => ar ? '$n عضو' : '$n members';
  String get newPrivateVaultBtn =>
      ar ? 'إنشاء خزنة خاصة جديدة' : 'New private vault';
  String get newVaultNameHint => ar
      ? 'اسم جروب أو قناة الخزنة (مثلاً: خزنة الملفات)'
      : 'Vault name (e.g. BIG DUCK Vault)';
  String get privateGroupOption => ar ? 'جروب خاص' : 'Private group';
  String get privateChannelOption => ar ? 'قناة خاصة' : 'Private channel';
  String get createAndSelectVault =>
      ar ? 'إنشاء وتعيين كوجهة' : 'Create and select';
  String get creatingVaultLabel => ar ? 'جاري الإنشاء...' : 'Creating...';
  String get noOwnedChatsFound => ar
      ? 'لا توجد جروبات مطابقة. يمكنك إنشاء خزنة خاصة جديدة بضغطة واحدة أعلاه.'
      : 'No matching groups found. Create a dedicated private vault above.';
  String chunkSizeSetToast(int mib) => ar
      ? 'تم ضبط حجم الجزء على $mib ميجابايت'
      : 'Chunk size set to $mib MiB';
  String encryptionUpdatedToast(bool active) => active
      ? (ar ? 'تم تفعيل تشفير AES-256-GCM' : 'AES-256-GCM encryption enabled')
      : (ar ? 'تم مسح كلمة مرور التشفير' : 'Encryption password cleared');
  String get demoBackupToast => ar
      ? 'وضع المعاينة: تم محاكاة النسخ الاحتياطي'
      : 'Demo mode: index backup simulated';
  String get demoRestoreToast => ar
      ? 'وضع المعاينة: تم محاكاة الاستعادة'
      : 'Demo mode: index restore simulated';
  String get signedOutToast =>
      ar ? 'تم تسجيل الخروج من تيليجرام' : 'Signed out of Telegram';
}
