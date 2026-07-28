// Hanagram Admin — Referans yönetimi (v2)
//
// Her kullanıcı → benzersiz kodu → davet ettiği kişiler.
// Kullanıcı adı benzersiz, kod sınırsız.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hanagram_design/design.dart';

class ReferralsTab extends StatefulWidget {
  const ReferralsTab({
    super.key,
    required this.users,
    required this.referrals,
  });

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> referrals;

  @override
  State<ReferralsTab> createState() => _ReferralsTabState();
}

class _ReferralsTabState extends State<ReferralsTab> {
  String _search = '';
  Map<String, dynamic>? _selectedUser;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    // Filtrelenmiş kullanıcılar
    final filtered = widget.users.where((u) {
      if (_search.isEmpty) return true;
      final name = (u['full_name'] as String? ?? '').toLowerCase();
      final username = (u['username'] as String? ?? '').toLowerCase();
      return name.contains(_search.toLowerCase()) ||
          username.contains(_search.toLowerCase());
    }).toList();

    // Seçili kullanıcının davetleri
    final userReferrals = _selectedUser != null
        ? widget.referrals
            .where((r) => r['referrer_id'] == _selectedUser!['id'])
            .toList()
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.all(HgSpace.lg),
      child: Row(
        children: [
          // Sol panel: Kullanıcı listesi
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Referans Yönetimi',
                    style: HgText.title.copyWith(color: c.text)),
                const SizedBox(height: HgSpace.sm),
                Text(
                  'Her kullanıcıya 1 benzersiz kod. Kod sınırsız kullanılabilir.',
                  style: HgText.small.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: HgSpace.md),

                // Arama
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: HgText.body.copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı ara...',
                    hintStyle: HgText.body.copyWith(color: c.textFaint),
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: c.textMuted),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(HgRadius.md),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(HgRadius.md),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                ),
                const SizedBox(height: HgSpace.md),

                // Kullanıcı listesi
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final code = user['my_referral_code'] as String?;
                      final referralCount = widget.referrals
                          .where((r) => r['referrer_id'] == user['id'])
                          .length;
                      final isSelected =
                          _selectedUser?['id'] == user['id'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.violet.withValues(alpha: 0.12)
                              : c.surface,
                          borderRadius:
                              BorderRadius.circular(HgRadius.sm),
                          border: Border.all(
                            color: isSelected ? c.violet : c.border,
                          ),
                        ),
                        child: ListTile(
                          onTap: () =>
                              setState(() => _selectedUser = user),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: c.violet.withValues(alpha: 0.2),
                            child: Text(
                              (user['full_name'] as String? ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: HgText.bodyStrong
                                  .copyWith(color: c.violet),
                            ),
                          ),
                          title: Text(
                            user['full_name'] as String? ?? '?',
                            style: HgText.bodyStrong
                                .copyWith(color: c.text),
                          ),
                          subtitle: Text(
                            '@${user['username'] ?? '?'}',
                            style: HgText.caption
                                .copyWith(color: c.textMuted),
                          ),
                          trailing: code != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Davet sayısı badge'i
                                    if (referralCount > 0)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c.success
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  HgRadius.sm),
                                        ),
                                        child: Text(
                                          '$referralCount',
                                          style:
                                              HgText.caption.copyWith(
                                                  color: c.success),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    // Kod kopyala
                                    IconButton(
                                      icon: Icon(Icons.copy,
                                          size: 16,
                                          color: c.textMuted),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: code));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '$code kopyalandı'),
                                            backgroundColor:
                                                c.success,
                                          ),
                                        );
                                      },
                                      tooltip: 'Kodu kopyala',
                                    ),
                                  ],
                                )
                              : Text('Yok',
                                  style: HgText.caption
                                      .copyWith(color: c.textFaint)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Dikey ayırıcı
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: HgSpace.lg),
            child: Container(
                width: 1, color: c.border),
          ),

          // Sağ panel: Seçili kullanıcının detayı
          Expanded(
            child: _selectedUser == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vpn_key_outlined,
                            size: 48, color: c.textFaint),
                        const SizedBox(height: HgSpace.md),
                        Text('Bir kullanıcı seçin',
                            style: HgText.body
                                .copyWith(color: c.textMuted)),
                      ],
                    ),
                  )
                : _buildUserDetail(c, userReferrals),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetail(
      HgColors c, List<Map<String, dynamic>> userReferrals) {
    final user = _selectedUser!;
    final code = user['my_referral_code'] as String? ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kullanıcı başlığı
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: c.violet.withValues(alpha: 0.2),
              child: Text(
                (user['full_name'] as String? ?? '?')
                    .substring(0, 1)
                    .toUpperCase(),
                style:
                    HgText.heading.copyWith(color: c.violet),
              ),
            ),
            const SizedBox(width: HgSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['full_name'] as String? ?? '?',
                    style:
                        HgText.title.copyWith(color: c.text)),
                Text('@${user['username'] ?? '?'}',
                    style: HgText.body
                        .copyWith(color: c.textMuted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: HgSpace.lg),

        // Referans kodu kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HgSpace.md),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(
                color: c.violet.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.vpn_key, size: 20, color: c.violet),
              const SizedBox(width: HgSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Referans Kodu',
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
                  Text(code,
                      style: HgText.mono.copyWith(
                          color: c.text, fontSize: 18)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy,
                    size: 20, color: c.violet),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$code kopyalandı'),
                      backgroundColor: c.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: HgSpace.lg),

        // Davet ettiği kişiler
        Text(
          'Davet Edilenler (${userReferrals.length})',
          style: HgText.heading.copyWith(color: c.text),
        ),
        const SizedBox(height: HgSpace.sm),

        Expanded(
          child: userReferrals.isEmpty
              ? Center(
                  child: Text(
                    'Henüz kimsesi davet etmemiş',
                    style:
                        HgText.body.copyWith(color: c.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: userReferrals.length,
                  itemBuilder: (context, index) {
                    final ref = userReferrals[index];
                    final referred =
                        ref['referred'] as Map<String, dynamic>?;
                    final createdAt =
                        ref['created_at'] as String?;

                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(HgSpace.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(
                            HgRadius.sm),
                        border:
                            Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: c.success
                                .withValues(alpha: 0.15),
                            child: Icon(Icons.person,
                                size: 16,
                                color: c.success),
                          ),
                          const SizedBox(
                              width: HgSpace.md),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                referred?['full_name']
                                        as String? ??
                                    '?',
                                style: HgText.bodyStrong
                                    .copyWith(
                                        color: c.text),
                              ),
                              Text(
                                '@${referred?['username'] ?? '?'}',
                                style: HgText.caption
                                    .copyWith(
                                        color:
                                            c.textMuted),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt),
                              style: HgText.caption
                                  .copyWith(
                                      color: c.textFaint),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
