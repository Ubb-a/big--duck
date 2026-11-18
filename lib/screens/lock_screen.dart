import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_motion_widgets.dart';
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
  late final AnimationController _exitScaleCtrl;
  bool _breathRunning = false;
  bool _authenticating = false;
  late bool _failed = widget.initialFailed;
  bool _succeeded = false;
  int _shakeCounter = 0;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.ambient, // 4s ease-in-out loop
    );
    _exitScaleCtrl = AnimationController(
      vsync: this,
      duration: vaultMotion.slow, // 400ms emphasized
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.initialFailed) {
        _unlock();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allow = vaultMotion.allowLoops(context) && !_succeeded;
    if (allow && !_breathRunning) {
      _breathRunning = true;
      _breathCtrl.repeat(reverse: true);
    } else if (!allow && _breathRunning) {
      _breathRunning = false;
      _breathCtrl.stop();
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _exitScaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_authenticating || _succeeded) return;
    final reduced = vaultMotion.isReduced(context);
    final playTransition = !reduced && vaultMotion.allowLoops(context);
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    try {
      final ok = await widget.controller.unlockWithBiometrics(
        onBeforeUnlock: playTransition
            ? () async {
                VaultHaptics.success();
                if (!mounted) return;
                setState(() {
                  _breathRunning = false;
                  _breathCtrl.stop();
                  _succeeded = true;
                });
                await _exitScaleCtrl.forward(from: 0.0);
              }
            : null,
      );
      if (!mounted) return;
      if (ok) {
        if (!playTransition) VaultHaptics.success();
      } else {
        VaultHaptics.error();
        setState(() {
          _failed = true;
          _shakeCounter++;
        });
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
              VaultGlassInputContainer(
                palette: p,
                borderRadius: VaultRadii.tile,
                builder: (context, focusNode) => TextField(
                  focusNode: focusNode,
                  controller: passCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: VaultText.mono(p, size: 16, color: p.ink),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: VaultText.mono(p, size: 16, color: p.muted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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
    final reduced = vaultMotion.isReduced(context);
    final fastDur = vaultMotion.duration(context, vaultMotion.fast);

    return Scaffold(
      backgroundColor: p.canvas,
      body: VaultCanvasBackdrop(
        palette: p,
        child: SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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

                VaultHorizontalShake(
                  triggerCount: _shakeCounter,
                  amplitude: 8,
                  cycles: 3,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_breathCtrl, _exitScaleCtrl]),
                    builder: (context, _) {
                      final breath = _breathRunning ? _breathCtrl.value : 0.4;
                      final exitT =
                          vaultMotion.emphasized.transform(_exitScaleCtrl.value);
                      final scale = reduced
                          ? 1.0
                          : (_succeeded
                              ? (1.0 + 0.4 * exitT)
                              : (1.0 + 0.06 * breath));
                      final opacity = _succeeded ? (1.0 - exitT) : 1.0;

                      final ringColor = _succeeded
                          ? p.signalGreen
                          : (_failed
                              ? p.coral
                              : p.champagne.withValues(
                                  alpha: 0.20 + 0.30 * breath,
                                ));

                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: VaultTap(
                            onTap: _authenticating ? null : _unlock,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_succeeded
                                            ? p.signalGreen
                                            : (_failed
                                                ? p.coral
                                                : p.champagne))
                                        .withValues(
                                            alpha: _failed
                                                ? 0.28
                                                : (0.08 + breath * 0.16)),
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
                                  child: AnimatedSwitcher(
                                    duration: vaultMotion.duration(
                                        context, vaultMotion.base),
                                    child: _succeeded
                                        ? VaultAnimatedDrawCheck(
                                            key: const ValueKey('lock_ok'),
                                            color: p.signalGreen,
                                            size: 52,
                                            strokeWidth: 2.5,
                                          )
                                        : (_authenticating
                                            ? SizedBox(
                                                key:
                                                    const ValueKey('lock_busy'),
                                                width: 34,
                                                height: 34,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 1.8,
                                                  color: p.champagne,
                                                ),
                                              )
                                            : Icon(
                                                Icons.fingerprint_rounded,
                                                key: const ValueKey(
                                                    'lock_finger'),
                                                size: 56,
                                                color: _failed
                                                    ? p.coral
                                                    : p.champagne,
                                              )),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),
                Text(
                  s.vaultLockedHeadline,
                  textAlign: TextAlign.center,
                  style: VaultText.heading(p, s.ar, size: 22),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: fastDur,
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
                    VaultHaptics.selection();
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
      ),
    );
  }
}
