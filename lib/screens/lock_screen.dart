import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_surface.dart';

class LockScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;
  final bool initialFailed;

  const LockScreen({
    super.key,
    required this.palette,
    required this.controller,
    this.initialFailed = false,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _shakeCtrl;
  bool _authenticating = false;
  late bool _failed = widget.initialFailed;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _breathCtrl.repeat(reverse: true);
      }
      if (!widget.initialFailed) {
        _unlock();
      }
    });
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    try {
      final ok = await widget.controller.unlockWithBiometrics();
      if (!mounted) return;
      if (!ok) {
        setState(() => _failed = true);
        if (!MediaQuery.disableAnimationsOf(context)) {
          _shakeCtrl.forward(from: 0.0);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  void _showPasscodeSheet() {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;
    final passCtrl = TextEditingController();

    showDialog<void>(
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
                s.usePasscodeCta,
                textAlign: TextAlign.center,
                style: VaultText.heading(p, s.ar, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                s.ar
                    ? 'استخدم التحقق الأمني للنظام أو سجّل الخروج لإعادة ربط الجلسة.'
                    : 'Use system credential verification or log out to reset this device session.',
                textAlign: TextAlign.center,
                style: VaultText.body(p, s.ar, size: 13, color: p.secondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: VaultText.mono(p, size: 16, color: p.ink),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: VaultText.mono(p, size: 16, color: p.muted),
                  filled: true,
                  fillColor: p.glassFill,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VaultRadii.tile),
                    borderSide: BorderSide(color: p.champagne),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              VaultPillButton(
                palette: p,
                isArabic: s.ar,
                label: s.unlockVault,
                onPressed: () {
                  Navigator.pop(ctx);
                  _unlock();
                },
              ),
              const SizedBox(height: 10),
              VaultPillButton(
                palette: p,
                isArabic: s.ar,
                variant: VaultPillVariant.danger,
                height: 44,
                label: s.logOut,
                onPressed: () {
                  Navigator.pop(ctx);
                  ctrl.logout();
                },
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(passCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.controller.strings;
    final motion = vaultMotion(context, 250);

    return Scaffold(
      backgroundColor: p.canvas,
      body: VaultCanvasBackdrop(
        palette: p,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 18),
                Text(
                  s.appTitle,
                  style: VaultText.mono(
                    p,
                    size: 12,
                    weight: FontWeight.w600,
                    color: p.secondary,
                  ),
                ),
                const Spacer(),

                AnimatedBuilder(
                  animation: Listenable.merge([_breathCtrl, _shakeCtrl]),
                  builder: (context, child) {
                    final breath = _breathCtrl.value;
                    final shakeDx = _shakeCtrl.isAnimating
                        ? math.sin(_shakeCtrl.value * math.pi * 4) * 8
                        : 0.0;
                    final ringColor = _failed
                        ? p.coral
                        : Color.lerp(
                              p.champagne.withValues(alpha: 0.28),
                              p.champagne.withValues(alpha: 0.72),
                              breath,
                            ) ??
                            p.champagne;

                    return Transform.translate(
                      offset: Offset(shakeDx, 0),
                      child: VaultTap(
                        onTap: _authenticating ? null : _unlock,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_failed ? p.coral : p.champagne)
                                    .withValues(
                                        alpha: _failed
                                            ? 0.28
                                            : (0.08 + breath * 0.14)),
                                blurRadius: 36 + (breath * 16),
                                spreadRadius: 2 + (breath * 4),
                              ),
                            ],
                          ),
                          child: VaultSurface(
                            palette: p,
                            borderRadius: VaultRadii.pill,
                            elevated: true,
                            borderColor: ringColor,
                            child: Center(
                              child: _authenticating
                                  ? SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: p.champagne,
                                      ),
                                    )
                                  : Icon(
                                      Icons.fingerprint_rounded,
                                      size: 56,
                                      color: _failed ? p.coral : p.champagne,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),
                Text(
                  s.vaultLockedHeadline,
                  textAlign: TextAlign.center,
                  style: VaultText.heading(p, s.ar, size: 22),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: motion,
                  child: Text(
                    _failed ? s.tryAgainText : s.vaultLockedSub,
                    key: ValueKey(_failed),
                    textAlign: TextAlign.center,
                    style: VaultText.body(
                      p,
                      s.ar,
                      size: 13.5,
                      color: _failed ? p.coral : p.secondary,
                      applyArabicScale: false,
                    ),
                  ),
                ),

                const Spacer(),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showPasscodeSheet();
                  },
                  child: Text(
                    s.usePasscodeCta,
                    style: VaultText.body(
                      p,
                      s.ar,
                      size: 14,
                      weight: FontWeight.w500,
                      color: p.secondary,
                      applyArabicScale: false,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
