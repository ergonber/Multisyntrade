import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/signals_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/deriv_provider.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/trade_execution_model.dart';
import '../signals/signals_screen.dart';
import '../profile/profile_screen.dart';
import '../deriv/deriv_connect_screen.dart';
import '../profile/capital_risk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SignalsProvider>().fetchAll();
      context.read<SignalsProvider>().fetchPerformance();
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<ProfileProvider>().loadProfile(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          SignalsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.show_chart_outlined, Icons.show_chart, 'Señales'),
                _buildNavItem(2, Icons.person_outline, Icons.person, 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _selectedPeriod = 'all';
  Timer? _refreshTimer;

  static const _periods = [
    ('all', 'Todo'),
    ('day', 'Hoy'),
    ('week', 'Semana'),
    ('month', 'Mes'),
  ];

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    context.read<SignalsProvider>().fetchPerformance(period: period);
  }

  List<Widget> _buildSetupBanners(ProfileProvider profile, DerivProvider deriv) {
    final p = profile.profile;
    final needsCapital = p == null || !p.hasCapital;
    final needsDeriv = !deriv.isConnected;

    if (!needsCapital && !needsDeriv) return [];

    return [
      if (needsCapital)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Configurá tu capital y riesgo para empezar a operar.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CapitalRiskScreen())),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('CONFIGURAR AHORA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      if (needsDeriv)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_outlined, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Conectá tu cuenta Deriv para operar.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DerivConnectScreen())),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('CONECTAR DERIV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<SignalsProvider>().fetchAll();
        context.read<SignalsProvider>().fetchPerformance(period: _selectedPeriod);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final signals = context.watch<SignalsProvider>();
    final profile = context.watch<ProfileProvider>();
    final deriv = context.watch<DerivProvider>();
    final perf = signals.performance;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, ${auth.userName}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Bienvenido a SynTrade',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _BalanceCard(profile: profile.profile, deriv: deriv),
            const SizedBox(height: 16),

            // UX Banners: capital y Deriv
            ..._buildSetupBanners(profile, deriv),

            const SizedBox(height: 24),

            const SectionHeader(title: 'ÚLTIMAS OPERACIONES'),
            const SizedBox(height: 12),
            _RecentOperationsSection(
              executions: signals.recentExecutions,
              onVerHistorial: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState._currentIndex = 1);
              },
            ),


            const SizedBox(height: 24),
            _ResultsSection(
              performance: perf,
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: _onPeriodChanged,
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'ACCIONES RÁPIDAS'),
            const SizedBox(height: 16),
            Row(
              children: [
                _QuickAction(icon: Icons.show_chart, label: 'Ver\nSeñales', onTap: () {}),
                const SizedBox(width: 12),
                _QuickAction(icon: Icons.account_balance_wallet_outlined, label: 'Conectar\nDeriv', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DerivConnectScreen()));
                }),
                const SizedBox(width: 12),
                _QuickAction(icon: Icons.assessment_outlined, label: 'Mis\nObjetivos', onTap: () {}),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  final dynamic performance;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const _ResultsSection({
    required this.performance,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = performance != null && performance.trades > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'MIS RESULTADOS'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (value, label) in _DashboardTabState._periods) ...[
                            GestureDetector(
                              onTap: () => onPeriodChanged(value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selectedPeriod == value
                                      ? AppColors.primary.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedPeriod == value
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: selectedPeriod == value
                                        ? AppColors.primary
                                        : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasData)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Todavía no tenés resultados.\nCuando operes una señal, aparecerán acá.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    _ResultStat(
                      label: 'Operaciones',
                      value: '${performance.trades}',
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _ResultStat(
                      label: 'Ganadas',
                      value: '${performance.wins}',
                      color: AppColors.positive,
                    ),
                    const SizedBox(width: 12),
                    _ResultStat(
                      label: 'Perdidas',
                      value: '${performance.losses}',
                      color: AppColors.negative,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ResultStat(
                      label: '% Acierto',
                      value: '${performance.winRate.toStringAsFixed(1)}%',
                      color: AppColors.primary,
                    ),
                    const Spacer(),
                    _ResultPnl(pnl: performance.pnl),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _ResultPnl extends StatelessWidget {
  final double pnl;
  const _ResultPnl({required this.pnl});

  @override
  Widget build(BuildContext context) {
    final isPositive = pnl >= 0;
    final color = isPositive ? AppColors.positive : AppColors.negative;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('PnL Total', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '$sign\$${pnl.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final dynamic profile;
  final DerivProvider deriv;
  const _BalanceCard({this.profile, required this.deriv});

  @override
  Widget build(BuildContext context) {
    final capital = profile?.capitalInicial ?? 0.0;
    final ganancia = profile?.gananciaAcumulada ?? 0.0;
    final derivBalance = deriv.isConnected ? deriv.account.balance : 0.0;
    final totalBalance = deriv.isConnected ? derivBalance : (capital + ganancia);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF00B894)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deriv.isConnected ? 'SALDO DERIV' : 'CAPITAL TOTAL ESTIMADO',
            style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (deriv.isConnected) ...[
                _StatItem(label: 'CUENTA', value: deriv.account.loginid),
                const SizedBox(width: 24),
                _StatItem(label: 'MONEDA', value: deriv.account.currency),
              ] else ...[
                _StatItem(label: 'GANANCIA', value: '+\$${ganancia.toStringAsFixed(2)}'),
                const SizedBox(width: 24),
                _StatItem(label: 'RIESGO', value: '${profile?.riskPercentage ?? 2}%'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOperationsSection extends StatelessWidget {
  final List<TradeExecutionModel> executions;
  final VoidCallback onVerHistorial;

  const _RecentOperationsSection({
    required this.executions,
    required this.onVerHistorial,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = executions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasData)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Todavía no operaste ninguna señal.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            ),
          )
        else
          ...executions.map((e) => _buildExecutionRow(e)),
        if (hasData) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onVerHistorial,
            child: Center(
              child: Text(
                'Ver historial',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExecutionRow(TradeExecutionModel e) {
    final isPositive = e.resultado != null && e.resultado! >= 0;
    final color = isPositive ? AppColors.positive : AppColors.negative;
    final sign = isPositive ? '+' : '';
    final label = e.isGanada ? 'Ganada' : e.isPerdida ? 'Perdida' : e.estado.toUpperCase();
    final dateStr = '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                e.estado == 'ganada' ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.derivSymbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  e.resultado != null ? '$sign\$${e.resultado!.toStringAsFixed(2)}' : '--',
                  style: TextStyle(
                    color: e.resultado != null ? color : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
