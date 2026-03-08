import re

with open(r'C:\Users\josma\cruise-app\lib\screens\identity_verification_screen.dart', encoding='utf-8') as f:
    content = f.read()

# ── 1. Step comment ──────────────────────────────────────────────────────────
content = content.replace(
    '  int _step =\n      0; // 0=intro, 1=docType, 2=capture, 3=processing, 4=confirm, 5=pending, 6=rejected',
    '  int _step =\n      0; // 0=intro, 1=docType, 2=ssn, 3=capture, 4=processing, 5=confirm, 6=pending, 7=rejected'
)

# ── 2. SSN state variables after _rejectionReason ────────────────────────────
content = content.replace(
    '  String? _rejectionReason;\n  Timer? _pollTimer;',
    '  String? _rejectionReason;\n  Timer? _pollTimer;\n\n  // SSN\n  String _ssn = \'\';\n  final _ssnCtrl = TextEditingController();\n  bool _ssnHasError = false;\n  String? _ssnErrorMsg;'
)

# ── 3. Add ssnCtrl listener in initState ──────────────────────────────────────
content = content.replace(
    '    _checkCtrl = AnimationController(\n      vsync: this,\n      duration: const Duration(milliseconds: 800),\n    );\n  }',
    '''    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ssnCtrl.addListener(() {
      final formatted = _formatSsnInput(_ssnCtrl.text);
      if (_ssnCtrl.text != formatted) {
        _ssnCtrl.value = _ssnCtrl.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      setState(() {
        _ssn = formatted;
        _ssnHasError = false;
        _ssnErrorMsg = null;
      });
    });
  }'''
)

# ── 4. Add _ssnCtrl.dispose() and SSN helper methods ─────────────────────────
content = content.replace(
    '  @override\n  void dispose() {\n    _pollTimer?.cancel();\n    _pulseCtrl.dispose();\n    _checkCtrl.dispose();\n    super.dispose();\n  }',
    '''  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _checkCtrl.dispose();
    _ssnCtrl.dispose();
    super.dispose();
  }

  // ── SSN helpers ────────────────────────────────────────────────────────────

  /// Auto-formats raw input to XXX-XX-XXXX pattern.
  String _formatSsnInput(String raw) {
    final digits = raw.replaceAll(RegExp(r\'[^\\d]\'), \'\');
    final limited = digits.length > 9 ? digits.substring(0, 9) : digits;
    if (limited.length <= 3) return limited;
    if (limited.length <= 5) {
      return \'${limited.substring(0, 3)}-${limited.substring(3)}\';
    }
    return \'${limited.substring(0, 3)}-${limited.substring(3, 5)}-${limited.substring(5)}\';
  }

  /// Returns null if valid, an error string if invalid.
  String? _validateSsn(String val) {
    final digits = val.replaceAll(RegExp(r\'[^\\d]\'), \'\');
    if (digits.length != 9) return \'Enter a complete 9-digit SSN\';
    final area   = int.parse(digits.substring(0, 3));
    final group  = int.parse(digits.substring(3, 5));
    final serial = int.parse(digits.substring(5, 9));
    // Area: cannot be 000, 666, or 900-999 (ITINs/invalid)
    if (area == 0 || area == 666 || area >= 900) {
      return \'Invalid SSN — area number not assignable\';
    }
    if (group  == 0) return \'Invalid SSN — group number cannot be 00\';
    if (serial == 0) return \'Invalid SSN — serial number cannot be 0000\';
    // All same digit
    if (RegExp(r\'^(\\d)\\1{8}$\').hasMatch(digits)) {
      return \'Invalid SSN — cannot be all identical digits\';
    }
    // Sequential
    if (digits == \'123456789\' || digits == \'987654321\') {
      return \'Invalid SSN — sequential numbers not allowed\';
    }
    // Known advertised/invalid SSNs
    const knownFake = {\'078051120\', \'219099999\', \'457555462\'};
    if (knownFake.contains(digits)) return \'This SSN is invalid\';
    return null; // valid
  }'''
)

# ── 5. Update _buildStep switch ───────────────────────────────────────────────
content = content.replace(
    '''  Widget _buildStep(AppColors c) {
    switch (_step) {
      case 0:
        return _buildIntro(c);
      case 1:
        return _buildDocTypeSelection(c);
      case 2:
        return _buildCapture(c);
      case 3:
        return _buildLiveness(c);
      case 4:
        return _buildConfirmed(c);
      case 5:
        return _buildPendingReview(c);
      case 6:
        return _buildRejected(c);
      default:
        return _buildIntro(c);
    }
  }''',
    '''  Widget _buildStep(AppColors c) {
    switch (_step) {
      case 0:
        return _buildIntro(c);
      case 1:
        return _buildDocTypeSelection(c);
      case 2:
        return _buildSsn(c);
      case 3:
        return _buildCapture(c);
      case 4:
        return _buildLiveness(c);
      case 5:
        return _buildConfirmed(c);
      case 6:
        return _buildPendingReview(c);
      case 7:
        return _buildRejected(c);
      default:
        return _buildIntro(c);
    }
  }'''
)

# ── 6. Add SSN preview to intro ───────────────────────────────────────────────
content = content.replace(
    "          _stepPreview(c, Icons.badge_rounded, 'Upload a valid ID document'),\n          const SizedBox(height: 12),\n          _stepPreview(c, Icons.face_rounded, 'Quick selfie verification'),",
    "          _stepPreview(c, Icons.badge_rounded, 'Upload a valid ID document'),\n          const SizedBox(height: 12),\n          _stepPreview(c, Icons.security_rounded, 'Social Security Number (SSN)'),\n          const SizedBox(height: 12),\n          _stepPreview(c, Icons.face_rounded, 'Quick selfie verification'),"
)

# ── 7. _launchLiveness: step 3 → 4 ────────────────────────────────────────────
content = content.replace(
    '      _step = 3; // Processing / submitting',
    '      _step = 4; // Processing / submitting'
)

# ── 8. _completeVerification: add ssn to body ─────────────────────────────────
content = content.replace(
    "    final Map<String, dynamic> body = {'id_document_type': docType};",
    "    final Map<String, dynamic> body = {\n      'id_document_type': docType,\n      if (_ssn.isNotEmpty) 'ssn': _ssn,\n    };"
)

# ── 9. _completeVerification: step 5 → 6 ─────────────────────────────────────
content = content.replace(
    '      _step = 5; // Pending review',
    '      _step = 6; // Pending review'
)

# ── 10. _startPolling: confirmed 4 → 5 ────────────────────────────────────────
content = content.replace(
    '            _step = 4; // Confirmed',
    '            _step = 5; // Confirmed'
)

# ── 11. _startPolling: rejected 6 → 7 ─────────────────────────────────────────
content = content.replace(
    '            _step = 6; // Rejected',
    '            _step = 7; // Rejected'
)

# ── 12. Update ValueKeys in existing widgets: 2→3, 3→4, 4→5, 5→6, 6→7 ────────
# ValueKey(2) in capture (the key= line right inside the Padding of _buildCapture)
# We need to be careful to only change in the context of the build methods, not our new SSN one
# The ValueKey(2) appears ONCE in the old file (in _buildCapture), now it should be ValueKey(3)
content = content.replace('key: const ValueKey(2),', 'key: const ValueKey(3),', 1)
# ValueKey(3) in liveness (processing step)
content = content.replace(
    '      key: const ValueKey(3),\n      child: Padding(\n        padding: const EdgeInsets.symmetric(horizontal: 32),',
    '      key: const ValueKey(4),\n      child: Padding(\n        padding: const EdgeInsets.symmetric(horizontal: 32),'
)
# ValueKey(4) in confirmed
content = content.replace(
    '        key: const ValueKey(4),\n        padding: const EdgeInsets.symmetric(horizontal: 24),\n        child: Column(\n          children: [\n            const SizedBox(height: 60),\n            // Animated check',
    '        key: const ValueKey(5),\n        padding: const EdgeInsets.symmetric(horizontal: 24),\n        child: Column(\n          children: [\n            const SizedBox(height: 60),\n            // Animated check'
)
# ValueKey(5) in pending (has 'Animated clock icon' comment after it)
content = content.replace(
    '      key: const ValueKey(5),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        children: [\n          const SizedBox(height: 60),\n          const Spacer(),\n          // Animated clock icon',
    '      key: const ValueKey(6),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        children: [\n          const SizedBox(height: 60),\n          const Spacer(),\n          // Animated clock icon'
)
# ValueKey(6) in rejected (has 'Navigator.pop(context, false)' later)
content = content.replace(
    'key: const ValueKey(6),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        children: [\n          const SizedBox(height: 8),\n          Align(\n            alignment: Alignment.centerLeft,\n            child: GestureDetector(\n              onTap: () => Navigator.pop(context, false),',
    'key: const ValueKey(7),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        children: [\n          const SizedBox(height: 8),\n          Align(\n            alignment: Alignment.centerLeft,\n            child: GestureDetector(\n              onTap: () => Navigator.pop(context, false),'
)

# ── 13. _buildCapture back button: step 1 → 2 ────────────────────────────────
# The ValueKey(3) capture widget has a back button that goes to step 1
# After step renumbering the capture widget's key is now ValueKey(3)
# We need to change the onTap inside _buildCapture from _step = 1 back to _step = 2 (SSN)
# The capture's back button: around line 663 context
content = content.replace(
    '      key: const ValueKey(3),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          const SizedBox(height: 8),\n          GestureDetector(\n            onTap: () => setState(() => _step = 1),',
    '      key: const ValueKey(3),\n      padding: const EdgeInsets.symmetric(horizontal: 24),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          const SizedBox(height: 8),\n          GestureDetector(\n            onTap: () => setState(() => _step = 2),'
)

print('All replacements done. Checking key fields...')
checks = [
    ('SSN state', '_ssn = \'\''),
    ('_ssnCtrl', '_ssnCtrl = TextEditingController()'),
    ('SSN step case', 'case 2:\n        return _buildSsn(c)'),
    ('Processing step 4', '_step = 4; // Processing'),
    ('Pending step 6', '_step = 6; // Pending review'),
    ('Confirmed step 5', '_step = 5; // Confirmed'),
    ('Rejected step 7', '_step = 7; // Rejected'),
    ('SSN in body', "'ssn': _ssn"),
    ('ValueKey 3', 'ValueKey(3)'),
    ('ValueKey 7', 'ValueKey(7)'),
    ('Capture back to step 2', '_step = 2),\n            child: Padding'),
]
for label, text in checks:
    status = '✅' if text in content else '❌ MISSING'
    print(f'  {status}: {label}')

with open(r'C:\Users\josma\cruise-app\lib\screens\identity_verification_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('File saved.')
