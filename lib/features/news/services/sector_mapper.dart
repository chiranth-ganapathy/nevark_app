// lib/features/news/services/sector_mapper.dart
//
// Maps article text → sector + related NSE stock symbols.
// Built from the same kSectorStocks + kNseTokens that the rest
// of the project uses, so it always stays in sync.

import '../../../services/api_service.dart';

class SectorMapResult {
  final String sector;
  final List<String> relatedStocks;

  const SectorMapResult({required this.sector, required this.relatedStocks});
}

/// Human-readable company name → NSE symbol
const Map<String, String> _nameToSymbol = {
  // IT
  'tcs': 'TCS',
  'tata consultancy': 'TCS',
  'infosys': 'INFY',
  'wipro': 'WIPRO',
  'hcl': 'HCLTECH',
  'hcltech': 'HCLTECH',
  'tech mahindra': 'TECHM',
  'techm': 'TECHM',
  'mphasis': 'MPHASIS',
  'persistent': 'PERSISTENT',
  'coforge': 'COFORGE',
  'ltimindtree': 'LTIM',
  'mindtree': 'LTIM',

  // Banking
  'hdfc bank': 'HDFCBANK',
  'hdfcbank': 'HDFCBANK',
  'icici bank': 'ICICIBANK',
  'icicibank': 'ICICIBANK',
  'sbi': 'SBIN',
  'state bank': 'SBIN',
  'kotak': 'KOTAKBANK',
  'kotakbank': 'KOTAKBANK',
  'axis bank': 'AXISBANK',
  'axisbank': 'AXISBANK',
  'indusind': 'INDUSINDBK',
  'bandhan': 'BANDHANBNK',
  'federal bank': 'FEDERALBNK',
  'idfc': 'IDFCFIRSTB',

  // Pharma
  'sun pharma': 'SUNPHARMA',
  'sunpharma': 'SUNPHARMA',
  'sun pharmaceutical': 'SUNPHARMA',
  "dr reddy": 'DRREDDY',
  "dr. reddy": 'DRREDDY',
  'cipla': 'CIPLA',
  'divi': 'DIVISLAB',
  "divislab": 'DIVISLAB',
  'apollo hospitals': 'APOLLOHOSP',
  'apollo': 'APOLLOHOSP',
  'torrent pharma': 'TORNTPHARM',
  'aurobindo': 'AUROPHARMA',

  // Energy
  'reliance': 'RELIANCE',
  'ril': 'RELIANCE',
  'ongc': 'ONGC',
  'ntpc': 'NTPC',
  'power grid': 'POWERGRID',
  'powergrid': 'POWERGRID',
  'tata power': 'TATAPOWER',
  'bpcl': 'BPCL',
  'bharat petroleum': 'BPCL',
  'ioc': 'IOC',
  'indian oil': 'IOC',
  'gail': 'GAIL',

  // FMCG
  'hindustan unilever': 'HINDUNILVR',
  'hul': 'HINDUNILVR',
  'itc': 'ITC',
  'nestle': 'NESTLEIND',
  'britannia': 'BRITANNIA',
  'dabur': 'DABUR',
  'marico': 'MARICO',
  'colgate': 'COLPAL',
  'tata consumer': 'TATACONSUM',

  // Auto
  'maruti': 'MARUTI',
  'maruti suzuki': 'MARUTI',
  'tata motors': 'TATAMOT',
  'bajaj auto': 'BAJAJ-AUTO',
  'hero': 'HEROMOTOCO',
  'hero motocorp': 'HEROMOTOCO',
  'eicher': 'EICHERMOT',
  'royal enfield': 'EICHERMOT',
  'mahindra': 'M&M',
  'm&m': 'M&M',

  // Finance
  'bajaj finserv': 'BAJAJFINSV',
  'bajaj finance': 'BAJFINANCE',
  'muthoot': 'MUTHOOTFIN',
  'chola': 'CHOLAFIN',
  'hdfc life': 'HDFCLIFE',
  'sbi life': 'SBILIFE',
  'shriram': 'SHRIRAMFIN',

  // Metal
  'jsw steel': 'JSWSTEEL',
  'jsw': 'JSWSTEEL',
  'tata steel': 'TATASTEEL',
  'hindalco': 'HINDALCO',
  'vedanta': 'VEDL',
  'coal india': 'COALINDIA',
  'nmdc': 'NMDC',
  'sail': 'SAIL',

  // Infra
  'l&t': 'LT',
  'larsen': 'LT',
  'siemens': 'SIEMENS',
  'abb': 'ABB',
  'havells': 'HAVELLS',
  'bhel': 'BHEL',

  // Telecom
  'airtel': 'BHARTIARTL',
  'bharti': 'BHARTIARTL',
  'jio': 'BHARTIARTL',

  // Real Estate
  'dlf': 'DLF',
  'oberoi': 'OBEROIRLTY',
  'prestige': 'PRESTIGE',
  'godrej properties': 'GODREJPROP',
  'godrej': 'GODREJPROP',
};

/// Sector keywords used to tag articles even without a stock match
const Map<String, List<String>> _sectorKeywords = {
  'IT': [
    'software', 'technology', 'tech', 'it sector', 'digital', 'cloud',
    'cybersecurity', 'artificial intelligence', 'ai', 'saas',
  ],
  'Banking': [
    'bank', 'banking', 'rbi', 'npa', 'credit', 'loan', 'interest rate',
    'repo rate', 'monetary', 'nbfc', 'fintech',
  ],
  'Pharma': [
    'pharma', 'pharmaceutical', 'drug', 'medicine', 'fda', 'clinical',
    'healthcare', 'hospital', 'biotech',
  ],
  'Energy': [
    'oil', 'gas', 'crude', 'fuel', 'power', 'electricity', 'renewable',
    'solar', 'wind', 'energy', 'petroleum', 'lng',
  ],
  'FMCG': [
    'fmcg', 'consumer goods', 'consumer staples', 'packaged', 'food',
    'beverage', 'household', 'personal care',
  ],
  'Auto': [
    'automobile', 'automotive', 'car', 'vehicle', 'ev', 'electric vehicle',
    'suv', 'two-wheeler', 'commercial vehicle', 'auto sector',
  ],
  'Metal': [
    'steel', 'metal', 'aluminium', 'copper', 'iron', 'mining', 'coal',
  ],
  'Telecom': [
    'telecom', 'telecommunication', '5g', 'spectrum', 'mobile network',
  ],
  'Real Estate': [
    'real estate', 'realty', 'property', 'housing', 'construction', 'reit',
  ],
  'Agriculture': [
    'agriculture', 'agri', 'farm', 'farming', 'crop', 'fertilizer',
  ],
  'Finance': [
    'nbfc', 'insurance', 'mutual fund', 'asset management', 'lending',
  ],
};

class SectorMapper {
  /// Given the combined text (title + description) of an article, returns
  /// the best-matching sector and a list of related NSE symbols.
  static SectorMapResult map(String text) {
    // 1. Clean common disclaimers containing the word "reliance"
    String lower = text.toLowerCase()
        .replaceAll(RegExp(r'\bundue reliance\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\breliance on\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\breliance should\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bplace reliance\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bplaced reliance\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bno reliance\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\breliance is\b', caseSensitive: false), '');

    final Map<String, int> sectorScore = {};
    final Set<String> foundSymbols = {};

    // ── Step 1: match company names as whole words ──────────────────────
    _nameToSymbol.forEach((name, symbol) {
      final regex = RegExp(r'\b' + RegExp.escape(name) + r'\b');
      if (regex.hasMatch(lower)) {
        foundSymbols.add(symbol);
        // Find which sector this symbol belongs to
        kSectorStocks.forEach((sector, stocks) {
          if (stocks.contains(symbol)) {
            sectorScore[sector] = (sectorScore[sector] ?? 0) + 3;
          }
        });
      }
    });

    // ── Step 2: match NSE ticker symbols as whole words ─────────────────
    kSectorStocks.forEach((sector, stocks) {
      for (final sym in stocks) {
        // Match the symbol as a whole word
        final regex = RegExp(r'\b' + sym.toLowerCase() + r'\b');
        if (regex.hasMatch(lower)) {
          foundSymbols.add(sym);
          sectorScore[sector] = (sectorScore[sector] ?? 0) + 3;
        }
      }
    });

    // ── Step 3: match sector keywords as whole words ────────────────────
    _sectorKeywords.forEach((sector, keywords) {
      for (final kw in keywords) {
        final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
        if (regex.hasMatch(lower)) {
          sectorScore[sector] = (sectorScore[sector] ?? 0) + 1;
        }
      }
    });

    // ── Determine winning sector ─────────────────────────────────────────
    String bestSector = 'General';
    if (sectorScore.isNotEmpty) {
      final sorted = sectorScore.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      bestSector = sorted.first.key;
    }

    return SectorMapResult(
      sector: bestSector,
      relatedStocks: foundSymbols.toList(),
    );
  }
}
