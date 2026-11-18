class AppStrings {
  final bool ar;
  const AppStrings(this.ar);

  String get appTitle => 'BIG DUCK';
  String get signalVaultSubtitle => 'SIGNAL VAULT';
  String get vaultSealLabel => ar ? 'خزنة مشفرة بصفر معرفة' : 'Zero-knowledge vault';
  String get previewUi => ar ? 'معاينة الواجهة' : 'Preview UI';

  // Floating Bottom Nav Tabs (Files · Transfers · Preview/Recent · Settings)
  String get tabFiles => ar ? 'الخزنة' : 'Files';
  String get tabTransfers => ar ? 'التحويلات' : 'Transfers';
  String get tabRecent => ar ? 'الأخيرة' : 'Preview';
  String get tabSettings => ar ? 'الإعدادات' : 'Settings';

  // Files screen
  String get filesTitle => ar ? 'الخزنة' : 'Vault';
  String get recentTitle => ar ? 'الأخيرة' : 'Recent';
  String get upload => ar ? 'رفع' : 'Upload';
  String get uploadFileAction => ar ? 'رفع ملف' : 'Upload file';
  String get searchHint =>
      ar ? 'ابحث في جميع المجلدات...' : 'Search all vault folders...';
  String get myFiles => ar ? 'ملفاتي' : 'My files';
  String get folderWord => ar ? 'مجلد' : 'Folder';
  String foldersAndFiles(int folders, int files) =>
      ar ? '$folders مجلد · $files ملف' : '$folders folders · $files files';
  String get folderEmpty => ar ? 'الخزنة فارغة' : 'Your vault is empty';
  String get noMatching => ar ? 'لا توجد نتائج' : 'No matching items';
  String get emptyDesc => ar
      ? 'تُقسَّم ملفاتك وتُشفَّر على جهازك قبل مغادرة أي بيانات.'
      : 'Files are split and encrypted on your device before anything leaves.';
  String nothingMatched(String q) =>
      ar ? 'لا توجد ملفات مطابقة لـ "$q"' : 'No items match "$q"';
  String get ownedByMeChip => ar ? 'مملوكة لي' : 'Owned by me';
  String get adminChip => ar ? 'مشرف' : 'Admin';

  // Filters & Sort
  String get filterTitle => ar ? 'تصفية' : 'Filter';
  String get filterAll => ar ? 'الكل' : 'All';
  String get filterFolders => ar ? 'مجلدات' : 'Folders';
  String get filterImages => ar ? 'صور' : 'Images';
  String get filterPdf => 'PDF';
  String get filterVideo => ar ? 'فيديو' : 'Video';
  String get filterOther => ar ? 'أخرى' : 'Other';

  String get sortByTitle => ar ? 'ترتيب حسب' : 'Sort by';
  String get sortDate => ar ? 'التاريخ' : 'Date';
  String get sortName => ar ? 'الاسم' : 'Name';
  String get sortSize => ar ? 'الحجم' : 'Size';

  // Multi-select
  String selectedCount(int count) => ar ? '$count محددة' : '$count selected';
  String get selectAll => ar ? 'تحديد الكل' : 'Select all';
  String get clearSelection => ar ? 'إلغاء' : 'Cancel';
  String get moveAction => ar ? 'نقل' : 'Move';
  String get renameAction => ar ? 'تسمية' : 'Rename';
  String get downloadAction => ar ? 'تنزيل' : 'Download';
  String get deleteAction => ar ? 'حذف' : 'Delete';
  String get undoAction => ar ? 'تراجع' : 'Undo';
  String get restoredToast => ar ? 'تم الاسترجاع' : 'Restored items';

  // Move modal
  String get moveToTitle => ar ? 'نقل إلى مجلد' : 'Move to folder';
  String get moveHereCta => ar ? 'انقل هنا' : 'Move here';
  String get rootFolderLabel =>
      ar ? 'الخزنة الرئيسية' : 'Vault root';

  // Delete confirmation dialog
  String get deleteConfirmTitle => ar ? 'تأكيد الحذف' : 'Confirm deletion';
  String deleteConfirmDesc(int count) => ar
      ? 'سيتم حذف $count عنصر من فهرس الخزنة نهائياً.'
      : 'Delete $count selected item(s) permanently from your vault index?';

  // Upload sheet & inspectors
  String get encryptAndUpload => ar ? 'رفع إلى الخزنة' : 'Upload to Vault';
  String get uploadDesc => ar
      ? 'تُشفَّر الملفات بـ Argon2id + AES-256-GCM قبل مغادرتها جهازك.'
      : 'Encrypted with Argon2id + AES-256-GCM on your device before upload.';
  String get chooseFilesLabel => ar ? 'اختر الملفات' : 'Choose files';
  String get uploadDocs => ar ? 'مستندات وملفات' : 'Documents & archives';
  String get uploadDocsSub =>
      ar ? 'PDF أو مضغوط أو أي نوع ملف' : 'PDFs, archives, or any file';
  String get uploadMedia => ar ? 'صور وفيديو' : 'Photos & video';
  String get uploadMediaSub =>
      ar ? 'من مكتبة الصور بالكامل' : 'Select from your library';
  String get destinationFolderLabel =>
      ar ? 'المجلد الوجهة' : 'Destination folder';
  String get encryptBeforeUpload =>
      ar ? 'تشفير قبل الرفع' : 'Encrypt before upload';
  String get newFolder => ar ? 'مجلد جديد' : 'New folder';
  String get folderNameHint => ar ? 'اسم المجلد' : 'Folder name';
  String get cancel => ar ? 'إلغاء' : 'Cancel';
  String get create => ar ? 'إنشاء' : 'Create';
  String get save => ar ? 'حفظ' : 'Save';

  String get openFolder => ar ? 'فتح المجلد' : 'Open folder';
  String get renameFolder => ar ? 'إعادة تسمية المجلد' : 'Rename folder';
  String get moveFolder => ar ? 'نقل المجلد' : 'Move folder';
  String get deleteFolder => ar ? 'حذف المجلد' : 'Delete folder';

  String get previewFileAction => ar ? 'معاينة' : 'Preview';
  String get previewPdf => ar ? 'معاينة PDF' : 'Preview PDF';
  String get previewImage => ar ? 'معاينة الصورة' : 'Preview image';
  String get previewVideo => ar ? 'تشغيل الفيديو' : 'Play video';
  String get previewAudio => ar ? 'تشغيل الصوت' : 'Play audio';
  String get downloadAndDecrypt =>
      ar ? 'تنزيل وفك التشفير' : 'Download & decrypt';
  String get renameFile => ar ? 'إعادة تسمية الملف' : 'Rename file';
  String get moveFile => ar ? 'نقل الملف' : 'Move file';
  String get deleteFile => ar ? 'حذف الملف' : 'Delete file';

  // Preview Darkroom
  String get decryptingMono => ar ? 'جاري فك التشفير...' : 'Decrypting...';
  String get infoLabel => ar ? 'التفاصيل' : 'Info';
  String get shareLabel => ar ? 'مشاركة' : 'Share';
  String get chunkCountLabel => ar ? 'عدد الأجزاء' : 'Chunks';
  String get encryptionStatusLabel => ar ? 'حالة التشفير' : 'Encryption';
  String get aesVerifiedLabel => 'AES-256-GCM';
  String get uploadDateLabel => ar ? 'تاريخ الرفع' : 'Upload date';

  // Transfers
  String get transfersTitle => ar ? 'التحويلات' : 'Transfers';
  String get transfersSub => ar
      ? 'طابور التشفير والنقل المباشر عبر تيليجرام'
      : 'Encrypted MTProto transfer queue';
  String get segmentActive => ar ? 'نشط' : 'Active';
  String get segmentCompleted => ar ? 'مكتمل' : 'Completed';
  String get segmentFailed => ar ? 'فشل' : 'Failed';
  String get noTransfers => ar ? 'لا توجد تحويلات' : 'Queue is clear';
  String get noTransfersDesc => ar
      ? 'ستظهر هنا الملفات قيد التشفير أو الرفع أو التنزيل بهدوء.'
      : 'Active uploads, paused items, and completed decryptions appear here.';
  String chunkProgressLabel(int current, int total) =>
      ar ? 'جزء $current من $total' : 'chunk $current of $total';
  String floodWaitMessage(int seconds) => ar
      ? 'طلب تيليجرام الانتظار $secondsث'
      : 'Telegram asked us to wait ${seconds}s';
  String get retryAction => ar ? 'إعادة المحاولة' : 'Retry';
  String get pauseAction => ar ? 'إيقاف مؤقت' : 'Pause';
  String get resumeAction => ar ? 'استكمال' : 'Resume';
  String get uploadLabel => ar ? 'رفع' : 'Upload';
  String get downloadLabel => ar ? 'تنزيل' : 'Download';

  // Settings sections (mono small caps headlines)
  String get settingsTitle => ar ? 'الإعدادات' : 'Settings';
  String get settingsSub =>
      ar ? 'تفضيلات الخزنة والأمان' : 'Vault security, storage, and appearance';
  String get sectionAccountSecurity =>
      ar ? 'الحساب والأمان' : 'Account & Security';
  String get sectionStorageDest =>
      ar ? 'وجهة التخزين' : 'Storage Destination';
  String get sectionEncryption => ar ? 'التشفير' : 'Encryption';
  String get sectionBackup => ar ? 'النسخ الاحتياطي' : 'Backup';
  String get sectionAppearanceLang =>
      ar ? 'المظهر واللغة' : 'Appearance & Language';
  String get sectionAbout => ar ? 'حول التطبيق' : 'About';

  String get appearanceTitle => ar ? 'المظهر' : 'Theme';
  String get languageLabel => ar ? 'اللغة' : 'Language';
  String get themeLight => ar ? 'فاتح' : 'Light';
  String get themeDark => ar ? 'داكن' : 'Dark';
  String get themeSystem => ar ? 'تلقائي' : 'Auto';

  String get autoLockTitle => ar ? 'مهلة القفل التلقائي' : 'Auto-lock timeout';
  String autoLockOptionLabel(int minutes) => switch (minutes) {
        0 => ar ? 'فوري' : 'Now',
        1 => ar ? '1 د' : '1m',
        5 => ar ? '5 د' : '5m',
        _ => ar ? '15 د' : '15m',
      };

  String get cacheTitle => ar ? 'الكاش المحلي للتنزيلات' : 'Local download cache';
  String get clearCache => ar ? 'مسح الكاش' : 'Clear cache';
  String get refresh => ar ? 'تحديث' : 'Refresh';
  String get storageDestination => ar ? 'وجهة التخزين' : 'Storage destination';
  String get savedMessagesDefault =>
      ar ? 'الرسائل المحفوظة' : 'Saved Messages';
  String get uploadChunkSize => ar ? 'حجم الجزء' : 'Chunk size';
  String get encryptionTitle => ar ? 'كلمة مرور الخزنة' : 'Vault password';
  String get encryptionAlgoRow => 'Argon2id + AES-256-GCM';
  String get encryptionSub => ar
      ? 'تُشفَّر كل الأجزاء على جهازك قبل إرسالها إلى تيليجرام.'
      : 'Zero-knowledge client encryption before chunks leave your device.';
  String get encPassHint =>
      ar ? 'أدخل كلمة مرور الخزنة' : 'Enter vault encryption password';
  String get applyPassword => ar ? 'حفظ المفتاح' : 'Apply key';
  String get clear => ar ? 'إيقاف' : 'Disable';
  String get backupRestoreTitle =>
      ar ? 'الفهرس المشفّر' : 'Encrypted index';
  String get backupPassHint =>
      ar ? 'كلمة مرور النسخة الاحتياطية' : 'Backup password';
  String get msgIdHint =>
      ar ? 'رقم الرسالة (اختياري)' : 'Message ID (optional)';
  String get backupIndex => ar ? 'نسخ الفهرس المشفر' : 'Back up encrypted index';
  String get restoreIndex => ar ? 'استعادة الفهرس' : 'Restore index';
  String get lastBackupLabel => ar ? 'آخر نسخة' : 'Last backup';
  String get neverLabel => ar ? 'لم يتم بعد' : 'Never';
  String get exitPreview => ar ? 'الخروج من المعاينة' : 'Exit preview';

  // Biometric lock & Security
  String get biometricLockTitle =>
      ar ? 'القفل بالبصمة / Face ID' : 'Biometric / Face ID lock';
  String get biometricLockSub => ar
      ? 'تأمين الوصول للخزنة عند فتح التطبيق'
      : 'Require device biometrics to open the vault';
  String get biometricUnavailable => ar
      ? 'المصادقة الحيوية غير مفعلة على الجهاز.'
      : 'Biometrics are not enrolled on this device.';
  String get vaultLockedHeadline => ar ? 'افتح خزنتك' : 'Unlock your vault';
  String get vaultLockedSub => ar
      ? 'أكّد هويتك لفك تشفير الفهرس المحلي'
      : 'Verify biometrics to unlock local keys';
  String get usePasscodeCta => ar ? 'استخدم رمز المرور' : 'Use passcode';
  String get tryAgainText => ar ? 'حاول مرة أخرى' : 'Try again';
  String get unlockVault => ar ? 'افتح خزنتك' : 'Unlock vault';

  // Search & share
  String searchResultsLabel(int count) =>
      ar ? 'نتائج البحث ($count)' : 'Search results ($count)';
  String get shareSaveTitle => ar ? 'احفظ في الخزنة' : 'Save to Vault';
  String get shareSaveSub => ar
      ? 'سيتم تشفير الملفات المحددة ورفعها لوجهتك المختارة.'
      : 'Selected files will be encrypted and queued for your vault.';
  String get shareSaveCta => ar ? 'حفظ' : 'Save';

  // Auth screen
  String get authConnectTitle => ar ? 'ربط تيليجرام' : 'Connect Telegram';
  String get authStepMountSub => ar
      ? 'أدخل بيانات المطور لتأسيس جلسة MTProto آمنة.'
      : 'Enter Telegram API credentials to establish an encrypted session.';
  String get authStepConnectTitle =>
      ar ? 'جاري إنشاء الجلسة...' : 'Establishing session...';
  String get authStepConnectSub => ar
      ? 'اتصال مشفّر مباشرة بخوادم تيليجرام.'
      : 'Connecting directly over MTProto.';
  String get authStepPhoneTitle => ar ? 'رقم الهاتف' : 'Phone number';
  String get authStepPhoneSub => ar
      ? 'اختر رمز الدولة وأدخل رقمك المرتبط بتيليجرام.'
      : 'Select country code and enter your Telegram phone number.';
  String get authStepCodeTitle => ar ? 'رمز التحقق' : 'Verification code';
  String authStepCodeSub(String? phone) => phone != null && phone.isNotEmpty
      ? (ar ? 'أدخل الرمز المرسل إلى $phone' : 'Enter the code sent to $phone')
      : (ar
          ? 'أدخل الرمز المرسل داخل تطبيق تيليجرام.'
          : 'Enter the login code sent to your Telegram session.');
  String get authStepPassTitle =>
      ar ? 'التحقق بخطوتين (2FA)' : '2FA password';
  String authStepPassSub(String? hint) => hint != null && hint.isNotEmpty
      ? (ar ? 'التلميح: $hint' : 'Hint: $hint')
      : (ar
          ? 'أدخل كلمة مرور التحقق بخطوتين الخاصة بحسابك.'
          : 'Enter your Telegram cloud password.');
  String get authFooterEncrypted => ar
      ? 'التشفير يتم على جهازك قبل ما أي شيء يغادره'
      : 'Encrypted on your device before anything leaves it';
  String get apiIdLabel => 'API ID';
  String get apiIdHint => '12345678';
  String get apiHashLabel => 'API HASH';
  String get apiHashHint =>
      ar ? 'مفتاح من 32 خانة' : '32-character hex string';
  String get apiCredsHelper => ar
      ? 'احصل عليها من my.telegram.org'
      : 'Get them from my.telegram.org';
  String get phoneLabel => ar ? 'رقم الهاتف' : 'Phone';
  String get phoneHint => '100 000 0000';
  String get codeLabel => ar ? 'رمز التحقق' : 'Code';
  String get resendReadyLabel => ar ? 'إعادة إرسال الرمز' : 'Resend code';
  String resendCountdownLabel(int sec) {
    final s = sec.toString().padLeft(2, '0');
    return ar ? 'إعادة الإرسال 00:$s' : 'Resend in 00:$s';
  }

  String get passwordLabel => ar ? 'كلمة المرور' : 'Password';
  String get passwordHint =>
      ar ? 'كلمة مرور الحساب' : '2FA password';
  String get continueCta => ar ? 'التالي' : 'Continue';
  String get connectingCta => ar ? 'جاري الربط...' : 'Connecting...';
  String get sendCodeCta => ar ? 'التالي' : 'Send code';
  String get verifyCodeCta => ar ? 'التالي' : 'Verify code';
  String get changePhoneOrKeys =>
      ar ? 'تغيير الرقم أو بيانات API' : 'Change phone or API credentials';
  String get nativeCoreReady => ar ? 'نواة Rust نشطة' : 'Rust core active';

  // Status & Logout
  String get statusSynced => ar ? 'متصل ومزامن' : 'Synced';
  String get statusConnecting => ar ? 'جاري الاتصال...' : 'Connecting...';
  String get statusOfflineTap =>
      ar ? 'غير متصل · اضغط للربط' : 'Offline · tap to connect';
  String get logOut => ar ? 'تسجيل الخروج' : 'Log out';
  String get logOutConfirmTitle =>
      ar ? 'تسجيل الخروج من تيليجرام؟' : 'Log out of Telegram?';
  String get logOutConfirmDesc => ar
      ? 'سيتم إنهاء الجلسة المحفوظة على هذا الجهاز وإغلاق الخزنة.'
      : 'Your saved Telegram session on this device will be disconnected.';
  String get keyActiveBadge => ar ? 'مفعّل' : 'Active';
  String get keyUnsetBadge => ar ? 'معطّل' : 'Off';
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
      : 'Native Rust core is unavailable in this build. Use Preview UI.';
  String get previewUiActivated =>
      ar ? 'تم تفعيل وضع المعاينة' : 'Preview UI activated';
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
      : 'Queued $count file(s) for upload';
  String downloadingToast(String name) =>
      ar ? 'جاري تنزيل "$name"...' : 'Downloading "$name"...';
  String demoDownloadToast(String name) => ar
      ? 'وضع المعاينة: تم محاكاة تنزيل "$name"'
      : 'Demo mode: "$name" download simulated';
  String get loadedGroupsToast =>
      ar ? 'تم تحديث الوجهات' : 'Loaded Telegram destinations';
  String storageChangedToast(bool toSavedMessages) => toSavedMessages
      ? (ar ? 'الوجهة: الرسائل المحفوظة' : 'Destination: Saved Messages')
      : (ar ? 'الوجهة: المجموعة المحددة' : 'Destination updated');
  String storageSetToChatToast(String name) =>
      ar ? 'الوجهة: $name' : 'Destination: "$name"';
  String vaultCreatedToast(String name) => ar
      ? 'تم إنشاء "$name" وتعيينها وجهة للخزنة'
      : 'Created "$name" as vault destination';

  // Filtered Storage Destination & Vault Creation
  String get storageDestSub => ar
      ? 'يظهر فقط ما تملكه أو تملك فيه صلاحية النشر كمشرف'
      : 'Only groups and channels you own or administer are listed';
  String get changeDestination => ar ? 'تغيير' : 'Change';
  String get searchVaultChatsHint =>
      ar ? 'ابحث في المجموعات والقنوات...' : 'Search owned chats...';
  String get filterOwnedByMe => ar ? 'مملوكة لي' : 'Owned by me';
  String get filterAdminAccess => ar ? 'مشرف' : 'Admin';
  String get roleOwnerBadge => ar ? 'المالك' : 'Owner';
  String get roleAdminBadge => ar ? 'مشرف' : 'Admin';
  String get privateBadge => ar ? 'خاص' : 'Private';
  String get groupKindLabel => ar ? 'مجموعة' : 'Group';
  String get channelKindLabel => ar ? 'قناة' : 'Channel';
  String membersCountLabel(int n) => ar ? '$n عضو' : '$n members';
  String get newPrivateVaultBtn =>
      ar ? 'إنشاء مجموعة خزنة خاصة' : 'Create private vault group';
  String get newVaultNameHint => ar
      ? 'اسم مجموعة الخزنة (مثلاً: خزنة الملفات)'
      : 'Vault name (e.g. Private Vault)';
  String get privateGroupOption => ar ? 'مجموعة خاصة' : 'Private group';
  String get privateChannelOption => ar ? 'قناة خاصة' : 'Private channel';
  String get createAndSelectVault =>
      ar ? 'إنشاء وتعيين' : 'Create & select';
  String get creatingVaultLabel => ar ? 'جاري الإنشاء...' : 'Creating...';
  String get noOwnedChatsFound => ar
      ? 'لا توجد وجهات مطابقة. أنشئ مجموعة خزنة خاصة بالأسفل.'
      : 'No matching chats. Create a private vault group below.';
  String chunkSizeSetToast(int mib) => ar
      ? 'تم ضبط حجم الجزء على $mib MiB'
      : 'Chunk size set to $mib MiB';
  String encryptionUpdatedToast(bool active) => active
      ? (ar ? 'تم تفعيل تشفير AES-256-GCM' : 'AES-256-GCM encryption enabled')
      : (ar ? 'تم إيقاف كلمة مرور الخزنة' : 'Vault encryption key cleared');
  String get demoBackupToast => ar
      ? 'تم حفظ نسخة الفهرس المشفّرة'
      : 'Encrypted index backup saved';
  String get demoRestoreToast => ar
      ? 'وضع المعاينة: تمت محاكاة الاستعادة'
      : 'Demo mode: index restore simulated';
  String get signedOutToast =>
      ar ? 'تم تسجيل الخروج من تيليجرام' : 'Logged out of Telegram';
  String get aboutFooterText => ar
      ? 'خزنة مشفرة بصفر معرفة فوق Telegram MTProto'
      : 'Zero-knowledge encrypted vault over Telegram MTProto';
}
