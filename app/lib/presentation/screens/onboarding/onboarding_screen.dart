import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/validators.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/profile_provider.dart';
import '../../../presentation/screens/home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _capitalController = TextEditingController();
  double _riskPercent = 2.0;
  String _selectedPlan = 'gratis';

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final auth = context.read<AuthProvider>();
    final profile = context.read<ProfileProvider>();
    if (auth.currentUser != null) {
      await profile.updateProfile(auth.currentUser!.id, {
        'nombre': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : auth.userName,
        'capital_inicial': double.tryParse(_capitalController.text) ?? 0,
        'capital_inicial_configurado': _capitalController.text.isNotEmpty,
        'risk_percentage': _riskPercent,
      });
    }
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'PASO ${_currentPage + 1} DE $_totalSteps',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (_currentPage + 1) / _totalSteps,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'ANTES DE EMPEZAR',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'QUEREMOS CONOCERTE MEJOR',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            '"La precisión es la base de toda inversión exitosa."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 40),
          _buildInput(
            label: 'TU NOMBRE COMPLETO',
            hint: 'Ej. Alexander Hamilton',
            icon: Icons.person_outline,
            controller: _nameController,
          ),
          const Spacer(flex: 2),
          AppButton(
            label: 'CONTINUAR',
            icon: Icons.arrow_forward,
            onPressed: _nextPage,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'TU CAPITAL',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿CUÁNTO TIENES PARA OPERAR?',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          _buildInput(
            label: 'CAPITAL EN USD',
            hint: '1000',
            icon: Icons.attach_money,
            controller: _capitalController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Puedes empezar con tan solo \$10. Tu capital es confidential y solo tú lo controlas.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          AppButton(
            label: 'CONTINUAR',
            icon: Icons.arrow_forward,
            onPressed: _nextPage,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'TU PERFIL DE RIESGO',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿CUÁNTO RIESGO ESTÁS DISPUESTO A TOMAR?',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_riskPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'de tu capital por operación',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 24),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: _riskPercent,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setState(() => _riskPercent = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CONSERVADOR', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    Text('AGRESIVO', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recomendación: El 2-3% es ideal para principiantes.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          AppButton(
            label: 'CONTINUAR',
            icon: Icons.arrow_forward,
            onPressed: _nextPage,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'ELIGE TU PLAN',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'COMIENZA GRATIS, MEJORA CUANDO QUIERAS',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          _buildPlanOption(
            id: 'gratis',
            name: 'Gratuito',
            price: '\$0',
            period: 'Siempre',
            features: ['Ver señales', 'Historial básico', '1 cuenta'],
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          _buildPlanOption(
            id: 'basico',
            name: 'Básico',
            price: '\$29',
            period: '/mes',
            features: ['Auto-copy', 'Estadísticas', 'Soporte'],
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildPlanOption(
            id: 'pro',
            name: 'Pro',
            price: '\$79',
            period: '/mes',
            features: ['Multi-cuenta', 'Simulador', 'API'],
            color: AppColors.warning,
          ),
          const Spacer(flex: 2),
          AppButton(
            label: '¡COMENZAR!',
            icon: Icons.rocket_launch,
            onPressed: _finishOnboarding,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String id,
    required String name,
    required String price,
    required String period,
    required List<String> features,
    required Color color,
  }) {
    final isSelected = _selectedPlan == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : Colors.grey, width: 2),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(features.join(' • '), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(period, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
