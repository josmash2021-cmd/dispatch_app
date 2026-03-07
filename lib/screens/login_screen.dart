import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const _gold = AppColors.primary;
  static const _goldLight = AppColors.primaryLight;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _emailActive = false;
  bool _passActive = false;

  // Entry animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Logo glow animation
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.30,
      end: 0.55,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  bool get _canSignIn => _emailController.text.trim().isNotEmpty;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            auth.errorMessage ?? 'Sign in failed',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 52),

                        // ── Logo + Brand ──────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              AnimatedBuilder(
                                animation: _glowAnim,
                                builder: (_, child) => Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: _gold,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _gold.withValues(
                                          alpha: _glowAnim.value,
                                        ),
                                        blurRadius: 40 + 10 * _glowAnim.value,
                                        offset: const Offset(0, 14),
                                      ),
                                      BoxShadow(
                                        color: _goldLight.withValues(
                                          alpha: _glowAnim.value * 0.3,
                                        ),
                                        blurRadius: 60,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                                child: const Icon(
                                  Icons.local_taxi_rounded,
                                  color: Color(0xFF08090C),
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Dispatch',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Admin Dashboard',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.40),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Sign In label ─────────────────────────────────
                        const Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Email field ───────────────────────────────────
                        _InputContainer(
                          active: _emailActive,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            onTap: () => setState(() => _emailActive = true),
                            onEditingComplete: () =>
                                setState(() => _emailActive = false),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Email address',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: _emailActive
                                    ? _gold
                                    : Colors.white.withValues(alpha: 0.25),
                                size: 20,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 0,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your email';
                              }
                              if (!v.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Password field ────────────────────────────────
                        _InputContainer(
                          active: _passActive,
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            onTap: () => setState(() => _passActive = true),
                            onEditingComplete: () {
                              setState(() => _passActive = false);
                              _handleLogin();
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '••••••••',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: _passActive
                                    ? _gold
                                    : Colors.white.withValues(alpha: 0.25),
                                size: 20,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 0,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white.withValues(alpha: 0.30),
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your password';
                              }
                              if (v.length < 6) return 'At least 6 characters';
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Sign In button — gradient pill ────────────────
                        GestureDetector(
                          onTap: (auth.isLoading || !_canSignIn)
                              ? null
                              : _handleLogin,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _canSignIn
                                  ? const LinearGradient(
                                      colors: [_gold, _goldLight, _gold],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      stops: [0.0, 0.5, 1.0],
                                    )
                                  : null,
                              color: _canSignIn
                                  ? null
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: _canSignIn
                                  ? [
                                      BoxShadow(
                                        color: _gold.withValues(alpha: 0.40),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: _goldLight.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 50,
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF08090C),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _canSignIn
                                            ? const Color(0xFF1A1400)
                                            : Colors.white.withValues(
                                                alpha: 0.25,
                                              ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // ── Footer ────────────────────────────────────────
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Cruise · Dispatch Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.18),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Input container matching cruise_app style ─────────────────────────────
class _InputContainer extends StatelessWidget {
  final Widget child;
  final bool active;
  const _InputContainer({required this.child, this.active = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.06),
          width: active ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    );
  }
}
