// Hanagram — Finans ekranı (bağımsız, Supabase bağımlılığı yok)
//
// Gelir/gider takibi, özet kartları, ekleme formu.
// Arkadram'ın finans.tsx ekranının Flutter karşılığı.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

/// İşlem türü.
enum _TxType { income, expense }

/// Tek bir gelir/gider kalemi.
class _FinanceEntry {
  const _FinanceEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  final String id;
  final _TxType type;
  final String title;
  final int amount; // kuruş
  final String category;
  final DateTime date;

  bool get isIncome => type == _TxType.income;
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<_FinanceEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Örnek veri — Supabase bağlanınca oradan çekilecek
    final now = DateTime.now();
    _entries = [
      _FinanceEntry(
        id: 'f1', type: _TxType.income, title: 'Makyaj Kampanyası — Elif',
        amount: 150000, category: 'Güzellik',
        date: now.subtract(const Duration(hours: 3)),
      ),
      _FinanceEntry(
        id: 'f2', type: _TxType.income, title: 'Çekim Paketi — Studio Nova',
        amount: 320000, category: 'Çekim',
        date: now.subtract(const Duration(days: 1)),
      ),
      _FinanceEntry(
        id: 'f3', type: _TxType.expense, title: 'Kira',
        amount: 120000, category: 'Sabit Gider',
        date: now.subtract(const Duration(days: 3)),
      ),
      _FinanceEntry(
        id: 'f4', type: _TxType.income, title: 'Kaş Laminasyonu — Zeynep',
        amount: 80000, category: 'Güzellik',
        date: now.subtract(const Duration(days: 4)),
      ),
      _FinanceEntry(
        id: 'f5', type: _TxType.expense, title: 'Malzeme Alımı',
        amount: 45000, category: 'Malzeme',
        date: now.subtract(const Duration(days: 5)),
      ),
      _FinanceEntry(
        id: 'f6', type: _TxType.income, title: 'Saç Bakım — Cenk',
        amount: 250000, category: 'Saç',
        date: now.subtract(const Duration(days: 6)),
      ),
      _FinanceEntry(
        id: 'f7', type: _TxType.expense, title: 'Personel Maaşı',
        amount: 155000, category: 'Personel',
        date: now.subtract(const Duration(days: 7)),
      ),
    ];
    setState(() => _isLoading = false);
  }

  int get _totalIncome => _entries
      .where((e) => e.isIncome)
      .fold<int>(0, (s, e) => s + e.amount);

  int get _totalExpense => _entries
      .where((e) => !e.isIncome)
      .fold<int>(0, (s, e) => s + e.amount);

  int get _netProfit => _totalIncome - _totalExpense;

  void _openAddSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FinanceAddSheet(
        onAdded: (entry) {
          setState(() => _entries.insert(0, entry));
        },
      ),
    );
  }

  void _removeEntry(String id) {
    setState(() => _entries.removeWhere((e) => e.id == id));
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
        title: Text('Finans', style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.add, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.lg, HgSpace.lg, 96),
                  children: [
                    // ─── Özet kartları ───
                    Row(
                      children: [
                        Expanded(child: _SummaryCard(
                          label: 'Gelir', amount: _totalIncome, color: c.success, c: c,
                        )),
                        const SizedBox(width: HgSpace.md),
                        Expanded(child: _SummaryCard(
                          label: 'Gider', amount: _totalExpense, color: c.coral, c: c,
                        )),
                      ],
                    ),
                    const SizedBox(height: HgSpace.md),
                    _SummaryCard(
                      label: 'Net Kâr', amount: _netProfit,
                      color: _netProfit >= 0 ? c.success : c.coral, c: c,
                    ),
                    const SizedBox(height: HgSpace.xl),

                    // ─── İşlem listesi ───
                    Text('İşlemler', style: HgText.heading.copyWith(color: c.text, shadows: null)),
                    const SizedBox(height: HgSpace.md),
                    if (_entries.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Henüz işlem yok',
                        message: 'İlk gelir/gider kaydını + ile ekleyin.',
                      )
                    else
                      ..._entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: HgSpace.sm),
                        child: _EntryTile(entry: e, onDelete: () => _removeEntry(e.id)),
                      )),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Özet kartı ───

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.amount, required this.color, required this.c});
  final String label;
  final int amount;
  final Color color;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return HgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
          const SizedBox(height: HgSpace.xs),
          Text(formatCurrency(amount), style: HgText.title.copyWith(color: color, shadows: null)),
        ],
      ),
    );
  }
}

// ─── İşlem satırı ───

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});
  final _FinanceEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (entry.isIncome ? c.success : c.coral).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Icon(
              entry.isIncome ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: entry.isIncome ? c.success : c.coral,
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                const SizedBox(height: 2),
                Text(
                  '${entry.category} · ${formatDateFromMs(entry.date.millisecondsSinceEpoch)}',
                  style: HgText.caption.copyWith(color: c.textMuted, shadows: null),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(entry.amount),
            style: HgText.bodyStrong.copyWith(
              color: entry.isIncome ? c.success : c.coral,
              shadows: null,
            ),
          ),
          const SizedBox(width: HgSpace.sm),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, size: 18, color: c.textFaint),
          ),
        ],
      ),
    );
  }
}

// ─── Ekleme formu ───

class _FinanceAddSheet extends StatefulWidget {
  const _FinanceAddSheet({required this.onAdded});
  final ValueChanged<_FinanceEntry> onAdded;

  @override
  State<_FinanceAddSheet> createState() => _FinanceAddSheetState();
}

class _FinanceAddSheetState extends State<_FinanceAddSheet> {
  _TxType _type = _TxType.income;
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = 'Genel';

  static const _categories = ['Genel', 'Güzellik', 'Çekim', 'Saç', 'Malzeme', 'Sabit Gider', 'Personel', 'Diğer'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.isEmpty || _amountCtrl.text.isEmpty) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;

    widget.onAdded(_FinanceEntry(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      title: _titleCtrl.text.trim(),
      amount: amount * 100, // TL → kuruş
      category: _category,
      date: DateTime.now(),
    ));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(
        HgSpace.lg, HgSpace.lg, HgSpace.lg,
        MediaQuery.of(context).viewInsets.bottom + HgSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: HgSpace.lg),
          Text('İşlem Ekle', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.lg),

          // Gelir/Gider toggle
          Row(
            children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _type = _TxType.income),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
                  decoration: BoxDecoration(
                    color: _type == _TxType.income ? c.success.withValues(alpha: 0.15) : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    border: Border.all(color: _type == _TxType.income ? c.success : c.border),
                  ),
                  child: Center(child: Text('Gelir', style: HgText.bodyStrong.copyWith(
                    color: _type == _TxType.income ? c.success : c.textMuted, shadows: null,
                  ))),
                ),
              )),
              const SizedBox(width: HgSpace.md),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _type = _TxType.expense),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
                  decoration: BoxDecoration(
                    color: _type == _TxType.expense ? c.coral.withValues(alpha: 0.15) : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    border: Border.all(color: _type == _TxType.expense ? c.coral : c.border),
                  ),
                  child: Center(child: Text('Gider', style: HgText.bodyStrong.copyWith(
                    color: _type == _TxType.expense ? c.coral : c.textMuted, shadows: null,
                  ))),
                ),
              )),
            ],
          ),
          const SizedBox(height: HgSpace.lg),

          // Başlık
          HgFormField(label: 'Açıklama', controller: _titleCtrl),
          const SizedBox(height: HgSpace.md),

          // Tutar
          HgFormField(label: 'Tutar (₺)', controller: _amountCtrl),
          const SizedBox(height: HgSpace.md),

          // Kategori
          Text('Kategori', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
          const SizedBox(height: HgSpace.sm),
          Wrap(
            spacing: HgSpace.sm,
            runSpacing: HgSpace.sm,
            children: _categories.map((cat) => GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: HgChip(
                label: cat,
                color: _category == cat ? c.violet : c.textFaint,
                filled: _category == cat,
              ),
            )).toList(),
          ),
          const SizedBox(height: HgSpace.xl),

          // Kaydet
          SizedBox(
            width: double.infinity,
            child: BrandButton(label: 'Kaydet', onPressed: _submit),
          ),
        ],
      ),
    );
  }
}
