import 'package:dio/dio.dart';
import '../../models/balance_info.dart';

/// Multi-platform API balance/usage query service.
///
/// Adapted from api-balance-kit. Supports OpenAI-compatible APIs
/// (DeepSeek, StepFun, SiliconFlow, Novita AI), OpenRouter, and Anthropic.
class BalanceService {
  final Dio _dio;

  BalanceService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// Detect provider from [baseUrl] and query the appropriate balance endpoint.
  Future<BalanceInfo> queryBalance(String baseUrl, String apiKey) async {
    final url = baseUrl.toLowerCase();

    if (url.contains('api.deepseek.com')) {
      return _queryDeepSeek(apiKey);
    }
    if (url.contains('api.stepfun')) {
      return _queryStepFun(apiKey);
    }
    if (url.contains('api.siliconflow.cn')) {
      return _querySiliconFlow(apiKey, 'CNY');
    }
    if (url.contains('api.siliconflow.com')) {
      return _querySiliconFlow(apiKey, 'USD');
    }
    if (url.contains('openrouter.ai')) {
      return _queryOpenRouter(apiKey);
    }
    if (url.contains('api.novita.ai')) {
      return _queryNovita(apiKey);
    }
    if (url.contains('api.anthropic.com')) {
      return _queryAnthropic(apiKey);
    }

    return BalanceInfo(checkedAt: DateTime.now());
  }

  // ── DeepSeek ───────────────────────────────────────────────────────
  // GET /user/balance → { balance_infos: [{ currency, total_balance, granted_balance, topped_up_balance }], is_available }

  Future<BalanceInfo> _queryDeepSeek(String apiKey) async {
    try {
      final resp = await _dio.get(
        'https://api.deepseek.com/user/balance',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final infos = (data['balance_infos'] as List?) ?? [];
      if (infos.isEmpty) {
        return BalanceInfo(provider: 'DeepSeek', checkedAt: DateTime.now());
      }
      final info = infos.first as Map<String, dynamic>;
      return BalanceInfo(
        total: _toDouble(info['total_balance']),
        used: _toDouble(info['topped_up_balance']),
        unit: (info['currency'] as String?) ?? 'CNY',
        provider: 'DeepSeek',
        checkedAt: DateTime.now(),
      );
    } on DioException {
      return BalanceInfo(provider: 'DeepSeek', checkedAt: DateTime.now());
    }
  }

  // ── StepFun ────────────────────────────────────────────────────────
  // GET /v1/accounts → { accounts: [{ account_type, balance }] }

  Future<BalanceInfo> _queryStepFun(String apiKey) async {
    try {
      final resp = await _dio.get(
        'https://api.stepfun.com/v1/accounts',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final accounts = (data['accounts'] as List?) ?? [];
      if (accounts.isEmpty) {
        return BalanceInfo(provider: 'StepFun', checkedAt: DateTime.now());
      }
      final total = accounts.fold<double>(
        0,
        (sum, a) =>
            sum + (_toDouble((a as Map<String, dynamic>)['balance']) ?? 0),
      );
      return BalanceInfo(
        total: total,
        unit: 'CNY',
        provider: 'StepFun',
        checkedAt: DateTime.now(),
      );
    } on DioException {
      return BalanceInfo(provider: 'StepFun', checkedAt: DateTime.now());
    }
  }

  // ── SiliconFlow ────────────────────────────────────────────────────
  // GET /v1/user/info → { data: { totalBalance, chargeBalance } }

  Future<BalanceInfo> _querySiliconFlow(String apiKey, String unit) async {
    try {
      final baseUrl = unit == 'CNY'
          ? 'https://api.siliconflow.cn'
          : 'https://api.siliconflow.com';
      final resp = await _dio.get(
        '$baseUrl/v1/user/info',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final userData = data['data'] as Map<String, dynamic>?;
      if (userData == null) {
        return BalanceInfo(provider: 'SiliconFlow', checkedAt: DateTime.now());
      }
      return BalanceInfo(
        total: _toDouble(userData['totalBalance']),
        remaining: _toDouble(userData['chargeBalance']),
        unit: unit,
        provider: 'SiliconFlow',
        checkedAt: DateTime.now(),
      );
    } on DioException {
      return BalanceInfo(provider: 'SiliconFlow', checkedAt: DateTime.now());
    }
  }

  // ── OpenRouter ─────────────────────────────────────────────────────
  // GET /api/v1/credits → { data: { total_credits, total_usage } }

  Future<BalanceInfo> _queryOpenRouter(String apiKey) async {
    try {
      final resp = await _dio.get(
        'https://openrouter.ai/api/v1/credits',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final credits = data['data'] as Map<String, dynamic>?;
      if (credits == null) {
        return BalanceInfo(provider: 'OpenRouter', checkedAt: DateTime.now());
      }
      final total = _toDouble(credits['total_credits']) ?? 0;
      final used = _toDouble(credits['total_usage']) ?? 0;
      return BalanceInfo(
        total: total,
        used: used,
        remaining: total - used,
        unit: 'credits',
        provider: 'OpenRouter',
        checkedAt: DateTime.now(),
      );
    } on DioException {
      return BalanceInfo(provider: 'OpenRouter', checkedAt: DateTime.now());
    }
  }

  // ── Novita AI ──────────────────────────────────────────────────────
  // GET /v3/user/balance → { balance: <int> }

  Future<BalanceInfo> _queryNovita(String apiKey) async {
    try {
      final resp = await _dio.get(
        'https://api.novita.ai/v3/user/balance',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final raw = _toDouble(data['balance']);
      // Novita balance needs ÷10000 to convert to USD
      final balance = raw != null ? raw / 10000 : null;
      return BalanceInfo(
        remaining: balance,
        unit: 'USD',
        provider: 'Novita AI',
        checkedAt: DateTime.now(),
      );
    } on DioException {
      return BalanceInfo(provider: 'Novita AI', checkedAt: DateTime.now());
    }
  }

  // ── Anthropic ──────────────────────────────────────────────────────
  // Anthropic uses OAuth-based subscription API — not directly queryable
  // with just an API key. Return a placeholder.

  Future<BalanceInfo> _queryAnthropic(String apiKey) async {
    return BalanceInfo(
      unit: 'usage-based',
      provider: 'Anthropic',
      checkedAt: DateTime.now(),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
