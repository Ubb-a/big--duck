import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_motion_widgets.dart';
import '../widgets/vault_surface.dart';

class _CountryCodeOption {
  final String code;
  final String nameEn;
  final String nameAr;

  const _CountryCodeOption(this.code, this.nameEn, this.nameAr);
}

const List<_CountryCodeOption> _countryCodes = [
  _CountryCodeOption('+20', 'Egypt', 'مصر'),
  _CountryCodeOption('+966', 'Saudi Arabia', 'السعودية'),
  _CountryCodeOption('+971', 'UAE', 'الإمارات'),
  _CountryCodeOption('+965', 'Kuwait', 'الكويت'),
  _CountryCodeOption('+974', 'Qatar', 'قطر'),
  _CountryCodeOption('+973', 'Bahrain', 'البحرين'),
  _CountryCodeOption('+968', 'Oman', 'عُمان'),
  _CountryCodeOption('+962', 'Jordan', 'الأردن'),
  _CountryCodeOption('+212', 'Morocco', 'المغرب'),
  _CountryCodeOption('+1', 'United States', 'أمريكا'),
  _CountryCodeOption('+44', 'United Kingdom', 'بريطانيا'),
  _CountryCodeOption('+49', 'Germany', 'ألمانيا'),
];

class AuthScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;

  const AuthScreen({
    super.key,
    required this.palette,
    required this.controller,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late final TextEditingController _apiIdCtrl;
  late final TextEditingController _apiHashCtrl;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late final AnimationController _splashCtrl;
  late final AnimationController _floatCtrl;
  bool _floatRunning = false;

  String _dialCode = '+20';
  bool _obscurePassword = true;
  Timer? _resendTimer;
  int _resendSeconds = 45;
  int _shakeCounter = 0;
  String? _lastErrorSeen;

  @override
  void initState() {
    super.initState();
    _apiIdCtrl = TextEditingController(text: widget.controller.apiId);
    _apiHashCtrl = TextEditingController(text: widget.controller.apiHash);
    _lastErrorSeen = widget.controller.authError;

    _splashCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.slow,
    )..forward();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    if (widget.controller.authStatus.kind == AuthStatusKind.awaitingCode) {
      _startResendTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allow = vaultMotion.allowLoops(context);
    if (allow && !_floatRunning) {
      _floatRunning = true;
      _floatCtrl.repeat(reverse: true);
    } else if (!allow && _floatRunning) {
      _floatRunning = false;
      _floatCtrl.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_apiIdCtrl.text.isEmpty && widget.controller.apiId.isNotEmpty) {
      _apiIdCtrl.text = widget.controller.apiId;
    }
    if (_apiHashCtrl.text.isEmpty && widget.controller.apiHash.isNotEmpty) {
      _apiHashCtrl.text = widget.controller.apiHash;
    }
    if (widget.controller.authStatus.kind == AuthStatusKind.awaitingCode &&
        _resendTimer == null) {
      _startResendTimer();
    } else if (widget.controller.authStatus.kind !=
            AuthStatusKind.awaitingCode &&
        _resendTimer != null) {
      _resendTimer?.cancel();
      _resendTimer = null;
    }
    final err = widget.controller.authError;
    if (err != null && err != _lastErrorSeen) {
      _shakeCounter++;
      VaultHaptics.error();
    }
    _lastErrorSeen = err;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _splashCtrl.dispose();
    _floatCtrl.dispose();
    _apiIdCtrl.dispose();
    _apiHashCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 45;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        setState(() => _resendSeconds = 0);
        timer.cancel();
        _resendTimer = null;
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _handleAction() {
    VaultHaptics.medium();
    final status = widget.controller.authStatus;
    switch (status.kind) {
      case AuthStatusKind.disconnected:
        widget.controller.setApiId(_apiIdCtrl.text);
        widget.controller.setApiHash(_apiHashCtrl.text);
        widget.controller.connect();
      case AuthStatusKind.awaitingPhone:
        final raw = _phoneCtrl.text.trim();
        if (raw.isEmpty) {
          setState(() => _shakeCounter++);
          VaultHaptics.error();
          return;
        }
        final fullPhone = raw.startsWith('+') ? raw : '$_dialCode$raw';
        widget.controller.submitPhone(fullPhone);
      case AuthStatusKind.awaitingCode:
        final code = _codeCtrl.text.trim();
        if (code.length < 5) {
          setState(() => _shakeCounter++);
          VaultHaptics.error();
          return;
        }
        widget.controller.submitCode(code);
      case AuthStatusKind.awaitingPassword:
        if (_passwordCtrl.text.isEmpty) {
          setState(() => _shakeCounter++);
          VaultHaptics.error();
          return;
        }
        widget.controller.submitPassword(_passwordCtrl.text);
      case AuthStatusKind.connecting:
      case AuthStatusKind.authorized:
        break;
    }
  }

  void _showCountryPicker() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    showVaultBottomSheet<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultSheetShell(
          palette: p,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final opt in _countryCodes)
                  VaultTap(
                    onTap: () {
                      VaultHaptics.selection();
                      setState(() => _dialCode = opt.code);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: _dialCode == opt.code
                            ? p.champagneSoft
                            : p.glassFill,
                        borderRadius: BorderRadius.circular(VaultRadii.tile),
                        border: Border.all(
                          color: _dialCode == opt.code
                              ? p.champagne
                              : p.glassBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            s.ar ? opt.nameAr : opt.nameEn,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 14,
                              weight: FontWeight.w500,
                              applyArabicScale: false,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            opt.code,
                            textDirection: TextDirection.ltr,
                            style: VaultText.mono(
                              p,
                              size: 12,
                              weight: FontWeight.w600,
                              color: _dialCode == opt.code
                                  ? p.champagne
                                  : p.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApiHelpDialog() {
    final p = widget.palette;
    final s = widget.controller.strings;
    showVaultDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.ar ? TextDirection.rtl : TextDirection.ltr,
        child: VaultDialogShell(
          palette: p,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.apiCredsHelper,
                style: VaultText.heading(p, s.ar, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                s.ar
                    ? 'سجّل الدخول برقمك في my.telegram.org ثم اختر API development tools لنسخ API ID و API Hash.'
                    : 'Sign in with your phone at my.telegram.org and open API development tools to copy your API ID and API Hash.',
                style: VaultText.body(p, s.ar, size: 13.5, color: p.secondary),
              ),
              const SizedBox(height: 18),
              VaultPillButton(
                palette: p,
                isArabic: s.ar,
                height: 44,
                label: 'my.telegram.org',
                variant: VaultPillVariant.outlined,
                onPressed: () {
                  Clipboard.setData(
                      const ClipboardData(text: 'https://my.telegram.org'));
                  Navigator.pop(ctx);
                  widget.controller.showToast(
                    s.ar ? 'تم نسخ الرابط' : 'Copied URL',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final status = ctrl.authStatus;
    final isConnecting = status.kind == AuthStatusKind.connecting;
    final reduced = vaultMotion.isReduced(context);

    final (stepNum, stepTitle, stepSubtitle, cta) = switch (status.kind) {
      AuthStatusKind.connecting => (
          1,
          s.authStepConnectTitle,
          s.authStepConnectSub,
          s.connectingCta,
        ),
      AuthStatusKind.awaitingPhone => (
          2,
          s.authStepPhoneTitle,
          s.authStepPhoneSub,
          s.sendCodeCta,
        ),
      AuthStatusKind.awaitingCode => (
          3,
          s.authStepCodeTitle,
          s.authStepCodeSub(status.phone),
          s.verifyCodeCta,
        ),
      AuthStatusKind.awaitingPassword => (
          4,
          s.authStepPassTitle,
          s.authStepPassSub(status.hint),
          s.unlockVault,
        ),
      _ => (
          1,
          s.authConnectTitle,
          s.authStepMountSub,
          s.continueCta,
        ),
    };

    return Scaffold(
      backgroundColor: p.canvas,
      body: VaultCanvasBackdrop(
        palette: p,
        child: SafeArea(
          child: Column(
            children: [
              // Compact top corner language switch with sliding pill highlight
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: VaultTap(
                    onTap: () {
                      VaultHaptics.light();
                      ctrl.setArabic(!ctrl.isArabic);
                    },
                    child: VaultSurface(
                      palette: p,
                      borderRadius: VaultRadii.pill,
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LangBadge(
                            palette: p,
                            label: 'AR',
                            active: ctrl.isArabic,
                          ),
                          _LangBadge(
                            palette: p,
                            label: 'EN',
                            active: !ctrl.isArabic,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: AnimatedBuilder(
                        animation: _splashCtrl,
                        builder: (context, child) {
                          final t = vaultMotion.emphasized
                              .transform(_splashCtrl.value);
                          final dy = reduced ? 0.0 : (1.0 - t) * 24.0;
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                VaultSurface(
                                  palette: p,
                                  borderRadius: VaultRadii.card,
                                  elevated: true,
                                  borderColor: p.glassTopLeftBorder,
                                  padding: const EdgeInsets.fromLTRB(
                                      22, 50, 22, 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // 4-segment thin progress tape (400ms directional fill + 180ms green completed transition)
                                      Row(
                                        children: List.generate(4, (idx) {
                                          final isDone = idx < stepNum - 1;
                                          final isActive = idx == stepNum - 1;
                                          return Expanded(
                                            child: Container(
                                              height: 3.5,
                                              margin:
                                                  EdgeInsetsDirectional.only(
                                                      end: idx == 3 ? 0 : 6),
                                              decoration: BoxDecoration(
                                                color: p.glassBorder,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        VaultRadii.pill),
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional
                                                    .centerStart,
                                                child: FractionallySizedBox(
                                                  widthFactor:
                                                      (isDone || isActive)
                                                          ? 1.0
                                                          : 0.0,
                                                  heightFactor: 1.0,
                                                  child: AnimatedContainer(
                                                    duration: vaultMotion
                                                        .duration(
                                                            context,
                                                            isDone
                                                                ? vaultMotion
                                                                    .fast
                                                                : vaultMotion
                                                                    .slow),
                                                    curve: vaultMotion.standard,
                                                    decoration: BoxDecoration(
                                                      color: isDone
                                                          ? p.signalGreen
                                                          : (isActive
                                                              ? p.champagne
                                                              : Colors
                                                                  .transparent),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              VaultRadii.pill),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 18),

                                      // Animated step content transition (leading slide out 180ms exit, trailing slide in 250ms standard)
                                      AnimatedSize(
                                        duration: vaultMotion.duration(
                                            context, vaultMotion.base),
                                        curve: vaultMotion.standard,
                                        alignment: Alignment.topCenter,
                                        child: AnimatedSwitcher(
                                          duration: vaultMotion.duration(
                                              context, vaultMotion.base),
                                          reverseDuration: vaultMotion.duration(
                                              context, vaultMotion.fast),
                                          switchInCurve: vaultMotion.standard,
                                          switchOutCurve: vaultMotion.exit,
                                          transitionBuilder:
                                              (child, animation) {
                                            if (reduced) {
                                              return FadeTransition(
                                                  opacity: animation,
                                                  child: child);
                                            }
                                            final rtl =
                                                Directionality.of(context) ==
                                                    TextDirection.rtl;
                                            final dirSign = rtl ? -1.0 : 1.0;
                                            final slide = Tween<Offset>(
                                              begin:
                                                  Offset(0.08 * dirSign, 0),
                                              end: Offset.zero,
                                            ).animate(animation);
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                  position: slide,
                                                  child: child),
                                            );
                                          },
                                          child: Column(
                                            key: ValueKey('step_${status.kind}'),
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                stepTitle,
                                                textAlign: TextAlign.center,
                                                style: VaultText.display(
                                                  p,
                                                  s.ar,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                stepSubtitle,
                                                textAlign: TextAlign.center,
                                                style: VaultText.body(
                                                  p,
                                                  s.ar,
                                                  size: 13.5,
                                                  color: p.secondary,
                                                ),
                                              ),
                                              const SizedBox(height: 22),

                                              if (status.kind ==
                                                      AuthStatusKind
                                                          .disconnected ||
                                                  status.kind ==
                                                      AuthStatusKind
                                                          .connecting) ...[
                                                _GlassInputBox(
                                                  palette: p,
                                                  isArabic: s.ar,
                                                  label: s.apiIdLabel,
                                                  hint: s.apiIdHint,
                                                  controller: _apiIdCtrl,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  enabled: !isConnecting,
                                                  ltrDigits: true,
                                                ),
                                                const SizedBox(height: 12),
                                                _GlassInputBox(
                                                  palette: p,
                                                  isArabic: s.ar,
                                                  label: s.apiHashLabel,
                                                  hint: s.apiHashHint,
                                                  controller: _apiHashCtrl,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onSubmitted: (_) =>
                                                      _handleAction(),
                                                  enabled: !isConnecting,
                                                  ltrDigits: true,
                                                ),
                                                const SizedBox(height: 10),
                                                GestureDetector(
                                                  onTap: _showApiHelpDialog,
                                                  child: Text(
                                                    s.apiCredsHelper,
                                                    textAlign: TextAlign.center,
                                                    style: VaultText.body(
                                                      p,
                                                      s.ar,
                                                      size: 12.5,
                                                      weight: FontWeight.w500,
                                                      color: p.champagne,
                                                      applyArabicScale: false,
                                                    ),
                                                  ),
                                                ),
                                              ] else if (status.kind ==
                                                  AuthStatusKind
                                                      .awaitingPhone) ...[
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    VaultTap(
                                                      onTap: _showCountryPicker,
                                                      child: VaultSurface(
                                                        palette: p,
                                                        borderRadius:
                                                            VaultRadii.tile,
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 14,
                                                            vertical: 14),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              _dialCode,
                                                              textDirection:
                                                                  TextDirection
                                                                      .ltr,
                                                              style:
                                                                  VaultText.mono(
                                                                p,
                                                                size: 13,
                                                                weight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: p.ink,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Icon(
                                                              Icons
                                                                  .keyboard_arrow_down_rounded,
                                                              size: 17,
                                                              color:
                                                                  p.secondary,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: _GlassInputBox(
                                                        palette: p,
                                                        isArabic: s.ar,
                                                        label: s.phoneLabel,
                                                        hint: s.phoneHint,
                                                        controller: _phoneCtrl,
                                                        keyboardType:
                                                            TextInputType.phone,
                                                        textInputAction:
                                                            TextInputAction
                                                                .done,
                                                        onSubmitted: (_) =>
                                                            _handleAction(),
                                                        ltrDigits: true,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else if (status.kind ==
                                                  AuthStatusKind
                                                      .awaitingCode) ...[
                                                VaultHorizontalShake(
                                                  triggerCount: _shakeCounter,
                                                  amplitude: 6,
                                                  cycles: 3,
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  child: _OtpDigitCellsField(
                                                    palette: p,
                                                    controller: _codeCtrl,
                                                    hasError:
                                                        ctrl.authError != null,
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                    onSubmitted: (_) =>
                                                        _handleAction(),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Center(
                                                  child: GestureDetector(
                                                    onTap: _resendSeconds == 0
                                                        ? () {
                                                            _startResendTimer();
                                                            ctrl.showToast(s.ar
                                                                ? 'تم طلب إعادة إرسال الرمز'
                                                                : 'Requested new login code');
                                                          }
                                                        : null,
                                                    child: Text(
                                                      _resendSeconds == 0
                                                          ? s.resendReadyLabel
                                                          : s.resendCountdownLabel(
                                                              _resendSeconds),
                                                      style: VaultText.monoText(
                                                        p,
                                                        _resendSeconds == 0
                                                            ? s.resendReadyLabel
                                                            : s.resendCountdownLabel(
                                                                _resendSeconds),
                                                        size: 11.5,
                                                        color: _resendSeconds ==
                                                                0
                                                            ? p.champagne
                                                            : p.secondary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ] else if (status.kind ==
                                                  AuthStatusKind
                                                      .awaitingPassword) ...[
                                                _GlassInputBox(
                                                  palette: p,
                                                  isArabic: s.ar,
                                                  label: s.passwordLabel,
                                                  hint: s.passwordHint,
                                                  controller: _passwordCtrl,
                                                  obscureText: _obscurePassword,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onSubmitted: (_) =>
                                                      _handleAction(),
                                                  suffix: IconButton(
                                                    onPressed: () => setState(
                                                        () => _obscurePassword =
                                                            !_obscurePassword),
                                                    icon: Icon(
                                                      _obscurePassword
                                                          ? Icons
                                                              .visibility_off_outlined
                                                          : Icons
                                                              .visibility_outlined,
                                                      size: 18,
                                                      color: p.secondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),

                                      if (ctrl.authError != null) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: p.coralSoft,
                                            borderRadius: BorderRadius.circular(
                                                VaultRadii.tile),
                                            border: Border.all(
                                              color: p.coral
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            ctrl.authError!,
                                            textAlign: TextAlign.center,
                                            style: VaultText.body(
                                              p,
                                              s.ar,
                                              size: 12.5,
                                              weight: FontWeight.w500,
                                              color: p.coral,
                                              applyArabicScale: false,
                                            ),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 22),
                                      VaultPillButton(
                                        palette: p,
                                        isArabic: s.ar,
                                        label: cta,
                                        loading: isConnecting,
                                        onPressed: isConnecting
                                            ? null
                                            : _handleAction,
                                      ),

                                      if (status.kind ==
                                              AuthStatusKind.awaitingPhone ||
                                          status.kind ==
                                              AuthStatusKind.awaitingCode ||
                                          status.kind ==
                                              AuthStatusKind
                                                  .awaitingPassword) ...[
                                        const SizedBox(height: 12),
                                        Center(
                                          child: TextButton(
                                            onPressed: () {
                                              VaultHaptics.selection();
                                              ctrl.resetAuthStep();
                                            },
                                            child: Text(
                                              s.changePhoneOrKeys,
                                              style: VaultText.body(
                                                p,
                                                s.ar,
                                                size: 13,
                                                weight: FontWeight.w500,
                                                color: p.secondary,
                                                applyArabicScale: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Floating duck icon: splash fade/glow expand + idle +/-4px 5s float loop
                                Positioned(
                                  top: -34,
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge(
                                        [_splashCtrl, _floatCtrl]),
                                    builder: (context, child) {
                                      final sp = vaultMotion.emphasized
                                          .transform(_splashCtrl.value);
                                      final dy = _floatRunning
                                          ? (-4.0 + 8.0 * _floatCtrl.value)
                                          : 0.0;
                                      final glowAlpha =
                                          0.25 * sp + (_floatCtrl.value * 0.1);
                                      return Transform.translate(
                                        offset: Offset(0, dy),
                                        child: Transform.scale(
                                          scale: reduced ? 1.0 : (0.9 + 0.1 * sp),
                                          child: Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: p.champagne.withValues(
                                                      alpha: glowAlpha.clamp(
                                                          0.0, 0.35)),
                                                  blurRadius: 40 * sp,
                                                  spreadRadius: 2 * sp,
                                                ),
                                              ],
                                              border: Border.all(
                                                color: p.glassTopLeftBorder,
                                                width: 1,
                                              ),
                                            ),
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(17),
                                      child: Image.asset(
                                        'assets/icon.png',
                                        width: 68,
                                        height: 68,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded,
                                    size: 13, color: p.muted),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    s.authFooterEncrypted,
                                    textAlign: TextAlign.center,
                                    style: VaultText.body(
                                      p,
                                      s.ar,
                                      size: 12,
                                      color: p.muted,
                                      applyArabicScale: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangBadge extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final bool active;

  const _LangBadge({
    required this.palette,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return AnimatedContainer(
      duration: vaultMotion.duration(context, vaultMotion.fast),
      curve: vaultMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? p.glassElevatedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(VaultRadii.pill),
        border: active
            ? Border.all(color: p.champagne.withValues(alpha: 0.35))
            : null,
      ),
      child: Text(
        label,
        style: VaultText.mono(
          p,
          size: 11,
          weight: FontWeight.w600,
          color: active ? p.champagne : p.secondary,
        ),
      ),
    );
  }
}

class _GlassInputBox extends StatelessWidget {
  final AppPalette palette;
  final bool isArabic;
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final bool ltrDigits;
  final Widget? suffix;

  const _GlassInputBox({
    required this.palette,
    required this.isArabic,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.ltrDigits = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            label,
            style: VaultText.monoText(p, label, size: 11, color: p.secondary),
          ),
        ),
        VaultGlassInputContainer(
          palette: p,
          borderRadius: VaultRadii.tile,
          builder: (context, focusNode) => TextField(
            focusNode: focusNode,
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            obscureText: obscureText,
            enabled: enabled,
            textDirection: ltrDigits ? TextDirection.ltr : null,
            style: ltrDigits
                ? VaultText.mono(p, size: 13.5, color: p.ink)
                : VaultText.body(p, isArabic,
                    size: 14, applyArabicScale: false),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: VaultText.monoText(
                p,
                hint,
                size: 12,
                color: p.muted,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpDigitCellsField extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _OtpDigitCellsField({
    required this.palette,
    required this.controller,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final digits = controller.text.trim();
    final reduced = vaultMotion.isReduced(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: List.generate(6, (idx) {
                final char = idx < digits.length ? digits[idx] : '';
                final active = idx == digits.length.clamp(0, 5);
                return Expanded(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('otp_${idx}_${char.isNotEmpty}'),
                    tween: Tween<double>(
                      begin: char.isNotEmpty && !reduced ? 1.08 : 1.0,
                      end: 1.0,
                    ),
                    duration: vaultMotion.duration(context, vaultMotion.fast),
                    curve: vaultMotion.standard,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: AnimatedContainer(
                      duration:
                          vaultMotion.duration(context, vaultMotion.fast),
                      curve: vaultMotion.standard,
                      height: 52,
                      margin: EdgeInsets.only(right: idx == 5 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: hasError
                            ? p.coralSoft
                            : (char.isNotEmpty ? p.champagneSoft : p.glassFill),
                        borderRadius: BorderRadius.circular(VaultRadii.tile),
                        border: Border.all(
                          color: hasError
                              ? p.coral
                              : (active ? p.champagne : p.glassBorder),
                          width: (active || hasError) ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: VaultText.mono(
                          p,
                          size: 18,
                          weight: FontWeight.w600,
                          color: hasError ? p.coral : p.ink,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              showCursor: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
