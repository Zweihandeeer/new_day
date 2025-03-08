import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gemini/services/metrics_service.dart';

class MetricsScreen extends StatefulWidget {
  final MetricsService metricsService;

  const MetricsScreen({Key? key, required this.metricsService}) : super(key: key);

  @override
  _MetricsScreenState createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  Map<String, double>? retrievalMetrics;
  Map<String, double>? responseQualityMetrics;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    var retrieval = await widget.metricsService.calculateRetrievalMetrics();
    var responseQuality = await widget.metricsService.evaluateResponseQuality("generated text", "expected text");

    setState(() {
      retrievalMetrics = retrieval;
      responseQualityMetrics = responseQuality;
    });
  }

  Widget _buildGroupedBarChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(toY: retrievalMetrics?["precision@5"] ?? 0.0, color: Colors.blue, width: 10),
              BarChartRodData(toY: retrievalMetrics?["recall@5"] ?? 0.0, color: Colors.green, width: 10),
              BarChartRodData(toY: retrievalMetrics?["mrr"] ?? 0.0, color: Colors.orange, width: 10),
              BarChartRodData(toY: responseQualityMetrics?["f1"] ?? 0.0, color: Colors.red, width: 10),
            ])
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  switch (value.toInt()) {
                    case 1:
                      return Text("Precision@5", style: TextStyle(color: Colors.blue));
                    case 2:
                      return Text("Recall@5", style: TextStyle(color: Colors.green));
                    case 3:
                      return Text("MRR", style: TextStyle(color: Colors.orange));
                    case 4:
                      return Text("F1 Score", style: TextStyle(color: Colors.red));
                    default:
                      return Text("");
                  }
                },
                reservedSize: 100,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }

  Widget _buildMetricTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildTableRow("Métrica", "Valor", isHeader: true),
            _buildTableRow("Precision@5", "${retrievalMetrics?["precision@5"]?.toStringAsFixed(2) ?? "N/A"}"),
            _buildTableRow("Recall@5", "${retrievalMetrics?["recall@5"]?.toStringAsFixed(2) ?? "N/A"}"),
            _buildTableRow("MRR", "${retrievalMetrics?["mrr"]?.toStringAsFixed(2) ?? "N/A"}"),
            _buildTableRow("BLEU", "${responseQualityMetrics?["bleu"]?.toStringAsFixed(2) ?? "N/A"}"),
            _buildTableRow("ROUGE", "${responseQualityMetrics?["rouge"]?.toStringAsFixed(2) ?? "N/A"}"),
            _buildTableRow("F1 Score", "${responseQualityMetrics?["f1"]?.toStringAsFixed(2) ?? "N/A"}"),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(String metric, String value, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(metric, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
          Text(value, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Resumen de Métricas"),
          centerTitle: true,
      ),
      body: retrievalMetrics == null || responseQualityMetrics == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Visualización de Métricas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _buildGroupedBarChart(),
            SizedBox(height: 20),
            Text("Detalles de Métricas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _buildMetricTable(),
          ],
        ),
      ),
    );
  }
}
