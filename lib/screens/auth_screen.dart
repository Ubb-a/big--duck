import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/core_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_surface.dart';

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

class _AuthScreenState extends State<AuthScreen> {
  late final TextEditingController _apiIdCtrl;
  late final TextEditingController _apiHashCtrl;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiIdCtrl = TextEditingController(text: widget.controller.apiId);
    _apiHashCtrl = TextEditingController(text: widget.controller.apiHash);
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
  }

  @override
  void dispose() {
    _apiIdCtrl.dispose();
    _apiHashCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleAction() {
    HapticFeedback.mediumImpact();
    final status = widget.controller.authStatus;
    switch (status.kind) {
      case AuthStatusKind.disconnected:
        widget.controller.setApiId(_apiIdCtrl.text);
        widget.controller.setApiHash(_apiHashCtrl.text);
        widget.controller.connect();
      case AuthStatusKind.awaitingPhone:
        if (_phoneCtrl.text.trim().isNotEmpty) {
          widget.controller.submitPhone(_phoneCtrl.text.trim());
        }
      case AuthStatusKind.awaitingCode:
        if (_codeCtrl.text.trim().isNotEmpty) {
          widget.controller.submitCode(_codeCtrl.text.trim());
        }
      case AuthStatusKind.awaitingPassword:
        if (_passwordCtrl.text.isNotEmpty) {
          widget.controller.submitPassword(_passwordCtrl.text);
        }
      case AuthStatusKind.connecting:
      case AuthStatusKind.authorized:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final status = ctrl.authStatus;
    final isConnecting = status.kind == AuthStatusKind.connecting;

    final (stepNum, title, subtitle, cta) = switch (status.kind) {
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
          s.authStepMountTitle,
          s.authStepMountSub,
          s.continueCta,
        ),
    };

    return Scaffold(
      backgroundColor: p.ground,
      body: SafeArea(
        child: Column(
          children: [
            // Archival Masthead
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(bottom: BorderSide(color: p.rule, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(VaultRadii.sm),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.appTitle,
                            style: VaultText.heading(p, s.ar, size: 15),
                          ),
                          VaultStatusDot(
                            palette: p,
                            isArabic: s.ar,
                            dotColor: ctrl.hasNativeCore ? p.cobalt : p.signal,
                            label: ctrl.hasNativeCore
                                ? s.nativeCoreReady
                                : s.vaultSealLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ctrl.setArabic(!ctrl.isArabic);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Text(
                            ctrl.isArabic ? 'EN' : 'ع',
                            style: VaultText.body(
                              p,
                              ctrl.isArabic,
                              size: 13,
                              weight: FontWeight.w700,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      VaultTap(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ctrl.enterDemoMode();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: Text(
                            s.previewUi,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 13,
                              weight: FontWeight.w600,
                              color: p.cobalt,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 4-step sequence meter
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.signal,
                            borderRadius: BorderRadius.circular(VaultRadii.xs),
                          ),
                          child: Text(
                            '$stepNum / 4',
                            style: VaultText.tabular(
                              p,
                              s.ar,
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: p.signalInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: List.generate(4, (idx) {
                              final filled = idx < stepNum;
                              return Expanded(
                                child: Container(
                                  height: 3,
                                  margin: EdgeInsetsDirectional.only(
                                      end: idx == 3 ? 0 : 4),
                                  decoration: BoxDecoration(
                                    color: filled ? p.signal : p.rule,
                                    borderRadius:
                                        BorderRadius.circular(VaultRadii.pill),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: VaultText.display(p, s.ar, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: VaultText.body(
                        p,
                        s.ar,
                        size: 14.5,
                        color: p.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (status.kind == AuthStatusKind.disconnected ||
                        status.kind == AuthStatusKind.connecting) ...[
                      VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.md,
                        child: Column(
                          children: [
                            _VaultFieldRow(
                              palette: p,
                              isArabic: s.ar,
                              label: s.apiIdLabel,
                              hint: s.apiIdHint,
                              controller: _apiIdCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              enabled: !isConnecting,
                            ),
                            Divider(height: 1, thickness: 1, color: p.rule),
                            _VaultFieldRow(
                              palette: p,
                              isArabic: s.ar,
                              label: s.apiHashLabel,
                              hint: s.apiHashHint,
                              controller: _apiHashCtrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleAction(),
                              enabled: !isConnecting,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.apiCredsHelper,
                        style: VaultText.body(
                          p,
                          s.ar,
                          size: 12,
                          color: p.muted,
                        ),
                      ),
                    ] else if (status.kind == AuthStatusKind.awaitingPhone)
                      VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.md,
                        child: _VaultFieldRow(
                          palette: p,
                          isArabic: s.ar,
                          label: s.phoneLabel,
                          hint: s.phoneHint,
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAction(),
                        ),
                      )
                    else if (status.kind == AuthStatusKind.awaitingCode)
                      VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.md,
                        child: _VaultFieldRow(
                          palette: p,
                          isArabic: s.ar,
                          label: s.codeLabel,
                          hint: s.codeHint,
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAction(),
                        ),
                      )
                    else if (status.kind == AuthStatusKind.awaitingPassword)
                      VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.md,
                        child: _VaultFieldRow(
                          palette: p,
                          isArabic: s.ar,
                          label: s.passwordLabel,
                          hint: s.passwordHint,
                          controller: _passwordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAction(),
                        ),
                      ),
                    if (ctrl.authError != null) ...[
                      const SizedBox(height: 14),
                      VaultSurface(
                        palette: p,
                        borderRadius: VaultRadii.sm,
                        backgroundColor: p.dangerSoft,
                        borderColor: p.danger,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          ctrl.authError!,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 13,
                            weight: FontWeight.w600,
                            color: p.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isConnecting ? null : _handleAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.signal,
                          foregroundColor: p.signalInk,
                          disabledBackgroundColor:
                              p.signal.withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VaultRadii.sm),
                          ),
                          elevation: 0,
                        ),
                        child: isConnecting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: p.signalInk,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    cta,
                                    style: VaultText.body(
                                      p,
                                      s.ar,
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: p.signalInk,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                cta,
                                style: VaultText.body(
                                  p,
                                  s.ar,
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: p.signalInk,
                                ),
                              ),
                      ),
                    ),
                    if (status.kind == AuthStatusKind.awaitingPhone ||
                        status.kind == AuthStatusKind.awaitingCode ||
                        status.kind == AuthStatusKind.awaitingPassword) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ctrl.resetAuthStep();
                          },
                          child: Text(
                            s.changePhoneOrKeys,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 13,
                              weight: FontWeight.w600,
                              color: p.cobalt,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultFieldRow extends StatelessWidget {
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

  const _VaultFieldRow({
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
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: VaultText.body(
                palette,
                isArabic,
                size: 14,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              obscureText: obscureText,
              enabled: enabled,
              style: VaultText.body(palette, isArabic, size: 14.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: VaultText.body(
                  palette,
                  isArabic,
                  size: 14,
                  color: palette.muted,
                ),
                border: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: palette.cobalt, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
