import 'package:material_ui/material_ui.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_surface.dart';

class LockScreen extends StatefulWidget {
  final AppPalette palette;
  final AppController controller;

  const LockScreen({
    super.key,
    required this.palette,
    required this.controller,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unlock();
    });
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      await widget.controller.unlockWithBiometrics();
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ctrl = widget.controller;
    final s = ctrl.strings;

    return Scaffold(
      backgroundColor: p.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Archival Masthead
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(bottom: BorderSide(color: p.rule, width: 1)),
              ),
              child: Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.appTitle,
                          style: VaultText.heading(p, s.ar, size: 15),
                        ),
                        Text(
                          ctrl.displayAccountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VaultText.body(
                            p,
                            s.ar,
                            size: 12,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline, size: 18, color: p.signal),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Asymmetric Vault Door Block
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fingerprint, size: 42, color: p.signal),
                  const SizedBox(height: 18),
                  Text(
                    s.vaultLockedTitle,
                    style: VaultText.display(p, s.ar, size: 30),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: p.signal,
                            borderRadius: BorderRadius.circular(VaultRadii.pill),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.vaultLockedSub,
                            style: VaultText.body(
                              p,
                              s.ar,
                              size: 14.5,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            // Pinned Footer Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: VaultTap(
                      onTap: _authenticating ? null : _unlock,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.signal,
                          borderRadius: BorderRadius.circular(VaultRadii.sm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_authenticating)
                              SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.signalInk,
                                ),
                              )
                            else
                              Icon(Icons.lock_open_outlined,
                                  size: 18, color: p.signalInk),
                            const SizedBox(width: 8),
                            Text(
                              s.unlockVault,
                              style: VaultText.body(
                                p,
                                s.ar,
                                size: 15,
                                weight: FontWeight.w700,
                                color: p.signalInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => ctrl.logout(),
                      child: Text(
                        s.signOut,
                        style: VaultText.body(
                          p,
                          s.ar,
                          size: 13,
                          weight: FontWeight.w600,
                          color: p.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
