// Hanagram — Muhasebe ekranı (Supabase)
//
// Gelir/gider yönetimi, aylık rapor, istatistikler, geçen ay karşılaştırma.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/accounting_service.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  late int _year;
  late int _month;
  MonthlyReport? _current;
  MonthlyReport? _previous;
  List<AccountingEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Mevcut ay raporu
    final current = await AccountingService.getMonthlyReport(_year, _month);

    // Önceki ay raporu
    final prevMonth = _month == 1 ? 12 : _month - 1;
    final prevYear = _month == 1 ? _year - 1 : _year;
    final previous =
        await AccountingService.getMonthlyReport(prevYear, prevMonth);

    // İşlemler
    final from = DateTime(_year, _month, 1);
    final to = DateTime(_year, _month + 1, 0, 23, 59, 59);
    final entries =
        await AccountingService.getEntries(from: from, to: to);

    if (mounted) {
      setState(() {
        _current = current;
        _previous = previous;
        _entries = entries;
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Muhasebe',
            style: HgText.title
                .copyWith(color: c.text, shadows: null)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context, c),
        backgroundColor: c.violet,
        child: Icon(Icons.add, color: c.onBrand),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(HgSpace.lg),
                children: [
                  // ─── Ay Seçici ───
                  _monthSelector(c),
                  const SizedBox(height: HgSpace.xl),

                  // ─── Ana Gelir/Gider Kartları ───
                  _mainCards(c),
                  const SizedBox(height: HgSpace.xl),

                  // ─── Karşılaştırma ───
                  if (_previous != null) ...[
                    _comparisonCard(c),
                    const SizedBox(height: HgSpace.xl),
                  ],

                  // ─── İstatistikler ───
                  _statsGrid(c),
                  const SizedBox(height: HgSpace.xl),

                  // ─── Son İşlemler ───
                  _transactionsList(c),
                ],
              ),
            ),
    );
  }

  // ─── Ay Seçici ───

  Widget _monthSelector(HgColors c) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: c.text),
          onPressed: _prevMonth,
        ),
        const Spacer(),
        Text('${months[_month]} $_year',
            style: HgText.display
                .copyWith(color: c.text, fontSize: 20)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.chevron_right, color: c.text),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  // ─── Ana Gelir/Gider Kartları ───

  Widget _mainCards(HgColors c) {
    final income = _current?.totalIncome ?? 0;
    final expense = _current?.totalExpense ?? 0;
    final profit = _current?.netProfit ?? 0;

    return Row(
      children: [
        Expanded(
          child: _bigStatCard(c, 'Gelir', income, Icons.trending_up,
              c.success, true),
        ),
        const SizedBox(width: HgSpace.md),
        Expanded(
          child: _bigStatCard(c, 'Gider', expense, Icons.trending_down,
              c.danger, false),
        ),
        const SizedBox(width: HgSpace.md),
        Expanded(
          child: _bigStatCard(
              c,
              'Kâr',
              profit,
              profit >= 0
                  ? Icons.star_outline
                  : Icons.warning_amber,
              profit >= 0 ? c.violet : c.coral,
              true),
        ),
      ],
    );
  }

  Widget _bigStatCard(HgColors c, String label, int amount,
      IconData icon, Color color, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: HgSpace.md),
          Text(_formatMoney(amount),
              style: HgText.title
                  .copyWith(color: c.text, fontSize: 18)),
          Text(label,
              style:
                  HgText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }

  // ─── Karşılaştırma Kartı ───

  Widget _comparisonCard(HgColors c) {
    final cur = _current!;
    final prev = _previous!;

    double pctChange(int current, int previous) {
      if (previous == 0) return current > 0 ? 100 : 0;
      return ((current - previous) / previous * 100);
    }

    final incomeChange =
        pctChange(cur.totalIncome, prev.totalIncome);
    final expenseChange =
        pctChange(cur.totalExpense, prev.totalExpense);
    final profitChange =
        pctChange(cur.netProfit, prev.netProfit);

    return HgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 17, color: c.violet),
              const SizedBox(width: HgSpace.sm),
              Text('Geçen aya göre karşılaştırma',
                  style:
                      HgText.heading.copyWith(color: c.text)),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          _compareRow(c, 'Gelir', incomeChange),
          _compareRow(c, 'Gider', expenseChange),
          _compareRow(c, 'Kâr', profitChange),
          const Divider(height: HgSpace.xl),
          _compareRow(c, 'İşlem sayısı',
              pctChange(cur.transactionCount, prev.transactionCount)),
          _compareRow(c, 'Randevu',
              pctChange(cur.totalAppointments, prev.totalAppointments)),
        ],
      ),
    );
  }

  Widget _compareRow(HgColors c, String label, double pct) {
    final isUp = pct > 0;
    final isDown = pct < 0;
    final color = isUp ? c.success : isDown ? c.danger : c.textMuted;
    final icon = isUp
        ? Icons.arrow_upward
        : isDown
            ? Icons.arrow_downward
            : Icons.remove;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style:
                  HgText.small.copyWith(color: c.textMuted)),
          const Spacer(),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('%${pct.abs().toStringAsFixed(1)}',
              style: HgText.bodyStrong
                  .copyWith(color: color)),
        ],
      ),
    );
  }

  // ─── İstatistik Grid'i ───

  Widget _statsGrid(HgColors c) {
    final cur = _current!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detaylı İstatistikler',
            style: HgText.heading.copyWith(color: c.text)),
        const SizedBox(height: HgSpace.md),
        Wrap(
          spacing: HgSpace.md,
          runSpacing: HgSpace.md,
          children: [
            _statBox(c, 'Yeni Müşteri', '${cur.newCustomers}',
                Icons.person_add_outlined, c.violet),
            _statBox(c, 'Toplam Randevu', '${cur.totalAppointments}',
                Icons.event_outlined, c.blue),
            _statBox(c, 'Yeni Randevu', '${cur.newAppointments}',
                Icons.fiber_new, c.success),
            _statBox(c, 'Onaylanan', '${cur.completedAppointments}',
                Icons.check_circle_outline, c.success),
            _statBox(c, 'İptal', '${cur.cancelledAppointments}',
                Icons.cancel_outlined, c.danger),
            _statBox(c, 'Kâr Marjı',
                '%${cur.profitMargin.toStringAsFixed(1)}',
                Icons.percent, c.coral),
          ],
        ),
      ],
    );
  }

  Widget _statBox(HgColors c, String label, String value,
      IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: HgSpace.sm),
          Text(value,
              style: HgText.title.copyWith(color: c.text)),
          Text(label,
              style: HgText.caption
                  .copyWith(color: c.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── İşlem Listesi ───

  Widget _transactionsList(HgColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('İşlemler',
                style: HgText.heading.copyWith(color: c.text)),
            const SizedBox(width: HgSpace.sm),
            HgChip(
                label: '${_entries.length}', color: c.violet),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        if (_entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(HgSpace.xl),
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Bu ay işlem yok',
                message: '+ butonu ile gelir veya gider ekleyin.',
              ),
            ),
          )
        else
          for (final entry in _entries)
            _transactionTile(c, entry),
      ],
    );
  }

  Widget _transactionTile(HgColors c, AccountingEntry entry) {
    final isIncome = entry.isIncome;
    final color = isIncome ? c.success : c.danger;
    final icon = isIncome
        ? Icons.arrow_downward
        : Icons.arrow_upward;
    final sign = isIncome ? '+' : '-';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: HgText.bodyStrong
                        .copyWith(color: c.text)),
                Row(
                  children: [
                    if (entry.category.isNotEmpty) ...[
                      Text(entry.category,
                          style: HgText.caption
                              .copyWith(color: c.textMuted)),
                      const SizedBox(width: HgSpace.sm),
                    ],
                    Text(_formatDate(entry.date),
                        style: HgText.caption
                            .copyWith(color: c.textFaint)),
                  ],
                ),
              ],
            ),
          ),
          Text('$sign${_formatMoney(entry.amount)}',
              style: HgText.bodyStrong
                  .copyWith(color: color)),
          const SizedBox(width: HgSpace.sm),
          IconButton(
            onPressed: () => _confirmDelete(entry),
            icon: Icon(Icons.delete_outline,
                size: 18, color: c.textFaint),
          ),
        ],
      ),
    );
  }

  // ─── Yeni İşlem Ekleme ───

  void _showAddTransactionSheet(BuildContext context, HgColors c) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final customerCtrl = TextEditingController();
    TransactionType type = TransactionType.income;
    String category = 'Satış';

    final categories = [
      'Satış', 'Hizmet', 'Kira', 'Maaş', 'Malzeme',
      'Reklam', 'Vergi', 'Diğer'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.xl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(HgRadius.xl)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: HgSpace.lg),
                  Text('Yeni İşlem',
                      style: HgText.title
                          .copyWith(color: c.text, shadows: null)),
                  const SizedBox(height: HgSpace.lg),

                  // Gelir/Gider seçimi
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(
                              () => type = TransactionType.income),
                          child: Container(
                            padding: const EdgeInsets.all(HgSpace.md),
                            decoration: BoxDecoration(
                              color: type == TransactionType.income
                                  ? c.success.withValues(alpha: 0.15)
                                  : c.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                  HgRadius.md),
                              border: Border.all(
                                color: type == TransactionType.income
                                    ? c.success
                                    : c.border,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.trending_up,
                                    color: type == TransactionType.income
                                        ? c.success
                                        : c.textMuted,
                                    size: 18),
                                const SizedBox(width: HgSpace.sm),
                                Text('Gelir',
                                    style: HgText.bodyStrong.copyWith(
                                        color: type ==
                                                TransactionType.income
                                            ? c.success
                                            : c.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: HgSpace.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(
                              () => type = TransactionType.expense),
                          child: Container(
                            padding: const EdgeInsets.all(HgSpace.md),
                            decoration: BoxDecoration(
                              color: type == TransactionType.expense
                                  ? c.danger.withValues(alpha: 0.15)
                                  : c.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                  HgRadius.md),
                              border: Border.all(
                                color: type == TransactionType.expense
                                    ? c.danger
                                    : c.border,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.trending_down,
                                    color: type == TransactionType.expense
                                        ? c.danger
                                        : c.textMuted,
                                    size: 18),
                                const SizedBox(width: HgSpace.sm),
                                Text('Gider',
                                    style: HgText.bodyStrong.copyWith(
                                        color: type ==
                                                TransactionType.expense
                                            ? c.danger
                                            : c.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HgSpace.lg),

                  // Başlık
                  TextField(
                    controller: titleCtrl,
                    style: HgText.body.copyWith(color: c.text),
                    decoration: _inputDec(c, 'İşlem başlığı'),
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Tutar
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: HgText.body.copyWith(color: c.text),
                    decoration: _inputDec(c, 'Tutar (₺)'),
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Kategori
                  Text('Kategori',
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
                  const SizedBox(height: HgSpace.sm),
                  Wrap(
                    spacing: HgSpace.sm,
                    runSpacing: HgSpace.sm,
                    children: categories.map((cat) {
                      final selected = category == cat;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => category = cat),
                        child: HgChip(
                          label: cat,
                          color: selected ? c.violet : c.textMuted,
                          filled: selected,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Müşteri adı
                  TextField(
                    controller: customerCtrl,
                    style: HgText.body.copyWith(color: c.text),
                    decoration: _inputDec(c, 'Müşteri adı (isteğe bağlı)'),
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Açıklama
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: HgText.body.copyWith(color: c.text),
                    decoration: _inputDec(c, 'Açıklama (isteğe bağlı)'),
                  ),
                  const SizedBox(height: HgSpace.xl),

                  // Kaydet
                  SizedBox(
                    width: double.infinity,
                    child: BrandButton(
                      label: 'Kaydet',
                      icon: Icons.check,
                      onPressed: titleCtrl.text.trim().isEmpty ||
                              amountCtrl.text.trim().isEmpty
                          ? null
                          : () async {
                              final amount =
                                  int.tryParse(amountCtrl.text.trim()) ??
                                      0;
                              await AccountingService.addEntry(
                                type: type,
                                title: titleCtrl.text.trim(),
                                amount: amount * 100, // TL → kuruş
                                date: DateTime.now(),
                                category: category,
                                description: descCtrl.text.trim(),
                                customerName:
                                    customerCtrl.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(HgColors c, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: HgText.body.copyWith(color: c.textFaint),
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HgRadius.md),
        borderSide: BorderSide(color: c.border),
      ),
    );
  }

  void _confirmDelete(AccountingEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İşlemi sil'),
        content: Text('"${entry.title}" silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AccountingService.deleteEntry(entry.id);
              _loadData();
            },
            child: const Text('Sil',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Yardımcılar ───

  static String _formatMoney(int kurus) {
    final tl = kurus ~/ 100;
    final kr = kurus % 100;
    if (kr == 0) return '₺${tl.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    return '₺${tl.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')},$kr';
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }
}
