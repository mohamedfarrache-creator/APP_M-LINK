import 'package:flutter/material.dart';

import '../../data/models/app_user.dart';
import '../../data/models/intervention.dart';
import '../../data/models/machine.dart';
import '../../data/repositories/maintenance_repository.dart';
import 'delayed_machines_list_screen.dart';
import 'open_anomalies_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final delayedMachines = repository.machines
        .where((machine) => machine.status == MachineStatus.due)
        .toList();
    final List<Intervention> openAnomalies = repository.interventions
        .where((item) => item.status.toLowerCase() == 'open')
        .toList();
    final interventionsThisWeek = repository.interventions
        .where((item) => item.forKw == _isoWeekNumber(DateTime.now()))
        .length;

    final cards = <Widget>[
      KpiCard(
        title: 'Machines en retard',
        value: '${delayedMachines.length}',
        accent: Color(0xFFE05757),
        icon: Icons.warning_amber_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DelayedMachinesListScreen(machines: delayedMachines),
            ),
          );
        },
      ),
      KpiCard(
        title: 'Anomalies ouvertes',
        value: '${openAnomalies.length}',
        accent: Color(0xFFFFA239),
        icon: Icons.handyman_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OpenAnomaliesListScreen(anomalies: openAnomalies),
            ),
          );
        },
      ),
      KpiCard(
        title: 'Interventions (Semaine)',
        value: '$interventionsThisWeek',
        accent: Color(0xFF00B4D8),
        icon: Icons.calendar_month_outlined,
      ),
      const KpiCard(
        title: 'Taux de realisation',
        value: '85%',
        accent: Color(0xFF44C27A),
        icon: Icons.pie_chart_outline_rounded,
        progress: 0.85,
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 4 : 2;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: <Color>[Color(0xFF000521), Color(0xFF020C47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: <Color>[Color(0xFFCAF0F8), Color(0xFFE8F8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Bonjour ${user.fullName}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Vue globale des operations de maintenance',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, index) => cards[index],
            ),
          ),
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
    this.progress,
    this.onTap,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: theme.cardTheme.color,
            boxShadow: isDark
                ? const <BoxShadow>[]
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000F1A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Color(0x99FFFFFF),
                      blurRadius: 12,
                      offset: Offset(-3, -3),
                    ),
                  ],
            border: Border.all(
              color: isDark ? const Color(0x5548CAE4) : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: progress == null
                ? _KpiStandardContent(
                    title: title,
                    value: value,
                    accent: accent,
                    icon: icon,
                  )
                : _KpiProgressContent(
                    title: title,
                    value: value,
                    accent: accent,
                    progress: progress!,
                  ),
          ),
        ),
      ),
    );
  }
}

int _isoWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = DateTime.thursday - firstDayOfYear.weekday;
  final firstThursday = firstDayOfYear.add(Duration(days: daysOffset));
  final difference = date.difference(firstThursday);
  return 1 + (difference.inDays / 7).floor();
}

class _KpiStandardContent extends StatelessWidget {
  const _KpiStandardContent({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: accent.withValues(alpha: 0.18),
          child: Icon(icon, color: accent),
        ),
        const Spacer(),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _KpiProgressContent extends StatelessWidget {
  const _KpiProgressContent({
    required this.title,
    required this.value,
    required this.accent,
    required this.progress,
  });

  final String title;
  final String value;
  final Color accent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Center(
          child: SizedBox(
            height: 68,
            width: 68,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  color: accent,
                ),
                Center(
                  child: Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
