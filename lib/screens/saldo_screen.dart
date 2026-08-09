import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SaldoScreen extends StatefulWidget {
  const SaldoScreen({super.key});

  @override
  State<SaldoScreen> createState() => _SaldoScreenState();
}

class _SaldoScreenState extends State<SaldoScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";

  int myOutletId = 1;
  int pusatOutletId = 1;
  bool isPusatOutlet = false;

  double cashLaciCurrent = 0; 
  double totalSaldoBank = 0;
  double totalSaldoEWallet = 0;
  double totalSaldoQRIS = 0;
  List<dynamic> listBalances = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadOutletSession();
  }

  Future<void> loadOutletSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
    });
    fetchDashboardBalances();
  }

  Future<void> fetchDashboardBalances() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_all_balances_dashboard.php?outlet_id=$myOutletId"),
      );
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        double calcTotalBank = 0;
        double calcTotalEWallet = 0;
        double calcTotalQRIS = 0;
        List<dynamic> accounts = data['data'] ?? [];

        double cashLaci = double.tryParse(data['cash_laci_current'].toString()) ?? 0;
        
        if (data['pusat_outlet_id'] != null) {
          pusatOutletId = int.tryParse(data['pusat_outlet_id'].toString()) ?? 1;
        }
        isPusatOutlet = data['is_pusat_outlet'] == true;
        
        // ============ DEBUG ============
        print("Total accounts: ${accounts.length}");
        for (var acc in accounts) {
          print("Akun: ${acc['name']}, Kategori: ${acc['category']}, Sub: ${acc['sub_category']}, Saldo: ${acc['balance']}, DariPusat: ${acc['is_from_pusat']}");
        }
        // ===============================

        for (var acc in accounts) {
          if (acc == null) continue;
          double bal = double.tryParse(acc['balance'].toString()) ?? 0;
          String category = (acc['category'] ?? '').toString().toLowerCase();

          if (category == 'bank') {
            calcTotalBank += bal;
          } else if (category == 'e-wallet') {
            calcTotalEWallet += bal;
          } else if (category == 'qris') {
            calcTotalQRIS += bal;
          }
        }

        setState(() {
          cashLaciCurrent = cashLaci;
          totalSaldoBank = calcTotalBank;
          totalSaldoEWallet = calcTotalEWallet;
          totalSaldoQRIS = calcTotalQRIS;
          listBalances = accounts;
        });
      } else {
        print("Error from API: ${data['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Gagal memuat data saldo"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal memuat data saldo outlet: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  Color _getCategoryColor(String category) {
    String cat = category.toLowerCase();
    if (cat == 'bank') return const Color(0xFF00529C);
    if (cat == 'e-wallet') return const Color(0xFFF26A25);
    if (cat == 'qris') return const Color(0xFF7B1FA2);
    if (cat == 'cash') return const Color(0xFFE65100);
    return Colors.grey;
  }

  Color _getCategoryBgColor(String category) {
    Color color = _getCategoryColor(category);
    return color.withOpacity(0.08);
  }

  IconData _getCategoryIcon(String category) {
    String cat = category.toLowerCase();
    if (cat == 'bank') return Icons.account_balance_rounded;
    if (cat == 'e-wallet') return Icons.phone_android_rounded;
    if (cat == 'qris') return Icons.qr_code_scanner_rounded;
    if (cat == 'cash') return Icons.money_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Informasi Saldo",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF00529C),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchDashboardBalances,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            color: const Color(0xFFF26A25),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26A25)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      LayoutBuilder(
                        builder: (context, cardConstraints) {
                          bool isMobile = cardConstraints.maxWidth < 700;
                          if (isMobile) {
                            return Column(
                              children: [
                                buildSummaryCard(
                                  "UANG KAS (LACI FISIK)",
                                  cashLaciCurrent,
                                  const Color(0xFFF26A25),
                                  Icons.account_balance_rounded,
                                ),
                                const SizedBox(height: 12),
                                buildSummaryCard(
                                  "TOTAL SALDO BANK",
                                  totalSaldoBank,
                                  const Color(0xFF00529C),
                                  Icons.account_balance_wallet_rounded,
                                ),
                                const SizedBox(height: 12),
                                buildSummaryCard(
                                  "TOTAL E-WALLET",
                                  totalSaldoEWallet,
                                  const Color(0xFFF26A25),
                                  Icons.phone_android_rounded,
                                ),
                                const SizedBox(height: 12),
                                buildSummaryCard(
                                  "TOTAL QRIS",
                                  totalSaldoQRIS,
                                  const Color(0xFF7B1FA2),
                                  Icons.qr_code_scanner_rounded,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: buildSummaryCard(
                                  "UANG KAS (LACI FISIK)",
                                  cashLaciCurrent,
                                  const Color(0xFFF26A25),
                                  Icons.account_balance_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: buildSummaryCard(
                                  "TOTAL SALDO BANK",
                                  totalSaldoBank,
                                  const Color(0xFF00529C),
                                  Icons.account_balance_wallet_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: buildSummaryCard(
                                  "TOTAL E-WALLET",
                                  totalSaldoEWallet,
                                  const Color(0xFFF26A25),
                                  Icons.phone_android_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: buildSummaryCard(
                                  "TOTAL QRIS",
                                  totalSaldoQRIS,
                                  const Color(0xFF7B1FA2),
                                  Icons.qr_code_scanner_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Table Section
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00529C).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.list_alt_rounded,
                                    color: Color(0xFF00529C),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Rincian Saldo Aktif Per Akun",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00529C),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Total: ${listBalances.length} akun',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            Container(
                              height: 2,
                              color: const Color(0xFFF26A25),
                            ),
                            const SizedBox(height: 16),

                            listBalances.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.account_balance_rounded,
                                            size: 48,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Belum ada akun finansial terdaftar",
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      double availableWidth = constraints.maxWidth;
                                      double subCategoryColumnWidth = 110;
                                      double categoryColumnWidth = 130;
                                      double balanceColumnWidth = 200;
                                      double nameColumnWidth = availableWidth - (categoryColumnWidth + subCategoryColumnWidth + balanceColumnWidth + 40); 
                                      
                                      if (nameColumnWidth < 200) nameColumnWidth = 200;

                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: availableWidth < 640 ? 640 : availableWidth,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                                            dataRowHeight: 64,
                                            columnSpacing: 6,
                                            horizontalMargin: 12,
                                            headingTextStyle: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Color(0xFF00529C),
                                            ),
                                            columns: [
                                              DataColumn(
                                                label: SizedBox(
                                                  width: nameColumnWidth,
                                                  child: const Text(
                                                    'Nama Akun',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: categoryColumnWidth,
                                                  child: const Text(
                                                    'Kategori',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: subCategoryColumnWidth,
                                                  child: const Text(
                                                    'Sub-Kategori',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: balanceColumnWidth,
                                                  child: const Text(
                                                    'Saldo Berjalan',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            rows: listBalances.map((item) {
                                              double currentBalance = double.tryParse(item['balance'].toString()) ?? 0;
                                              String category = item['category'] ?? '-';
                                              String subCategory = item['sub_category'] ?? '-';
                                              String name = item['name'] ?? '-';
                                              bool isBank = category.toLowerCase() == 'bank';
                                              bool hasSubCategory = isBank && subCategory != '-';
                                              bool isFromPusat = item['is_from_pusat'] == true;
                                              bool isPenampung = isBank && subCategory == 'Penampung';

                                              return DataRow(
                                                cells: [
                                                  // Nama Akun
                                                  DataCell(
                                                    SizedBox(
                                                      width: nameColumnWidth,
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(6),
                                                            decoration: BoxDecoration(
                                                              color: _getCategoryBgColor(category),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Icon(
                                                              _getCategoryIcon(category),
                                                              size: 16,
                                                              color: _getCategoryColor(category),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              name,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w500,
                                                                fontSize: 14,
                                                                color: isFromPusat ? Colors.blue.shade700 : Colors.black87,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isFromPusat)
                                                            Container(
                                                              margin: const EdgeInsets.only(left: 4),
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue.shade50,
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: Colors.blue.shade200),
                                                              ),
                                                              child: Text(
                                                                "PUSAT",
                                                                style: TextStyle(
                                                                  fontSize: 7,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.blue.shade700,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // Kategori
                                                  DataCell(
                                                    SizedBox(
                                                      width: categoryColumnWidth,
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: _getCategoryBgColor(category),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            category.toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: _getCategoryColor(category),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Sub-Kategori
                                                  DataCell(
                                                    SizedBox(
                                                      width: subCategoryColumnWidth,
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: hasSubCategory
                                                            ? Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                                decoration: BoxDecoration(
                                                                  color: isPenampung 
                                                                      ? const Color(0xFFFF6F00).withOpacity(0.1)
                                                                      : Colors.grey.shade200,
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  border: isPenampung
                                                                      ? Border.all(color: const Color(0xFFFF6F00).withOpacity(0.3))
                                                                      : null,
                                                                ),
                                                                child: Text(
                                                                  subCategory,
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w500,
                                                                    color: isPenampung 
                                                                        ? const Color(0xFFFF6F00)
                                                                        : Colors.grey.shade700,
                                                                  ),
                                                                ),
                                                              )
                                                            : Text(
                                                                '-',
                                                                style: TextStyle(
                                                                  color: Colors.grey.shade400,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Saldo
                                                  DataCell(
                                                    SizedBox(
                                                      width: balanceColumnWidth,
                                                      child: Text(
                                                        "Rp ${_formatIdr(currentBalance)}",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14,
                                                          color: isFromPusat ? Colors.blue.shade700 : (isBank ? const Color(0xFF00529C) : Colors.black87),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                      
                      // ============ INFO TAMBAHAN ============
                      if (!isPusatOutlet && listBalances.isNotEmpty)
                        const SizedBox(height: 16),
                      if (!isPusatOutlet && listBalances.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Akun dengan label PUSAT adalah rekening penampung (M-Banking) dari outlet pusat. Saldo ditampilkan secara real-time.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // =================================================
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget buildSummaryCard(String title, double value, Color themeColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: themeColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rp ${_formatIdr(value)}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}