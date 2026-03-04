import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'text_preprocessor.dart';

/// Pure Dart offline ML — TF-IDF + LinearSVC.
///
/// Загружает предобученные веса из assets/ml/*.json.
/// Если веса не загружены (JSON пустые) — сервис не active и
/// ReceiptCategorizationService использует словарный fallback.
///
/// Для генерации весов запустите на сервере:
///   python -m app.ml.training.export_dart_model
/// и скопируйте полученные JSON в assets/ml/.
class OfflineMLService {
  static final OfflineMLService _instance = OfflineMLService._();
  factory OfflineMLService() => _instance;
  OfflineMLService._();

  List<double> _idfWeights = [];
  List<List<double>> _weights = [];
  List<double> _bias = [];
  List<String> _classes = [];
  Map<String, int> _vocabIndex = {};

  bool _isLoaded = false;

  /// True если модель загружена и готова к работе.
  bool get isActive => _isLoaded;

  /// Загрузить веса из assets/ml/. Вызывается один раз при старте.
  Future<void> load() async {
    try {
      final vocabRaw = await rootBundle.loadString('assets/ml/vocabulary.json');
      final idfRaw = await rootBundle.loadString('assets/ml/idf_weights.json');
      final weightsRaw =
          await rootBundle.loadString('assets/ml/model_weights.json');
      final classesRaw =
          await rootBundle.loadString('assets/ml/label_classes.json');

      final vocab = List<String>.from(jsonDecode(vocabRaw) as List);
      final idf = (jsonDecode(idfRaw) as List)
          .map((v) => (v as num).toDouble())
          .toList();
      final weights = jsonDecode(weightsRaw) as Map<String, dynamic>;
      final classes = List<String>.from(jsonDecode(classesRaw) as List);

      final wRaw = weights['W'] as List;
      final bRaw = weights['b'] as List;

      if (vocab.isEmpty || classes.isEmpty || wRaw.isEmpty) {
        // Placeholder пустые файлы — модель ещё не сгенерирована
        return;
      }

      _idfWeights = idf;
      _weights = wRaw
          .map((row) =>
              (row as List).map((v) => (v as num).toDouble()).toList())
          .toList();
      _bias = bRaw.map((v) => (v as num).toDouble()).toList();
      _classes = classes;

      // Строим индекс vocabulary для быстрого поиска
      _vocabIndex = {for (int i = 0; i < vocab.length; i++) vocab[i]: i};

      _isLoaded = true;
    } catch (_) {
      // Ошибка загрузки — сервис inactive, fallback к словарю
    }
  }

  /// Предсказать категорию для [text].
  /// Возвращает null если модель не загружена.
  String? predict(String text) {
    if (!_isLoaded) return null;

    final features = _buildFeatureVector(text);
    final scores = _decisionFunction(features);

    int maxIdx = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[maxIdx]) maxIdx = i;
    }
    return _classes[maxIdx];
  }

  /// Предсказать категорию с confidence score (0..1).
  ({String category, double confidence})? predictWithConfidence(String text) {
    if (!_isLoaded) return null;

    final features = _buildFeatureVector(text);
    final scores = _decisionFunction(features);

    int maxIdx = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[maxIdx]) maxIdx = i;
    }

    // Простая нормализация через softmax (стабильная версия)
    final maxScore = scores[maxIdx];
    double expSum = 0;
    final exps = scores.map((s) {
      final e = math.exp((s - maxScore).clamp(-30.0, 0.0));
      expSum += e;
      return e;
    }).toList();
    final confidence =
        expSum > 0 ? exps[maxIdx] / expSum : 1.0 / scores.length;

    return (
      category: _classes[maxIdx],
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ── Internal ──────────────────────────────────────────

  /// Строим sparse TF-IDF вектор признаков (word unigrams+bigrams + char 3-5grams).
  Map<int, double> _buildFeatureVector(String text) {
    final tokens = TextPreprocessor.tokenize(text);
    final processed = tokens.join(' ');

    final counts = <int, double>{};

    // Word n-grams (unigrams + bigrams)
    final wordNg = [
      ...TextPreprocessor.wordNgrams(tokens, 1),
      ...TextPreprocessor.wordNgrams(tokens, 2),
    ];
    for (final ng in wordNg) {
      final idx = _vocabIndex[ng];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }

    // Char n-grams (char_wb, 3-5)
    final charNg = TextPreprocessor.charNgrams(processed, 3, 5);
    for (final ng in charNg) {
      final idx = _vocabIndex[ng];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }

    // TF с sublinear_tf: tf = 1 + ln(count)
    final tfIdf = <int, double>{};
    for (final e in counts.entries) {
      final tf = 1.0 + math.log(e.value);
      tfIdf[e.key] = tf * _idfWeights[e.key];
    }

    // L2 нормализация
    double norm = 0;
    for (final v in tfIdf.values) { norm += v * v; }
    norm = math.sqrt(norm);
    if (norm > 0) {
      for (final key in tfIdf.keys) {
        tfIdf[key] = tfIdf[key]! / norm;
      }
    }

    return tfIdf;
  }

  /// Sparse decision_function: scores[cls] = weights[cls] · x + bias[cls]
  List<double> _decisionFunction(Map<int, double> x) {
    final n = _classes.length;
    final scores = List<double>.filled(n, 0.0);
    for (int cls = 0; cls < n; cls++) {
      double s = _bias[cls];
      for (final entry in x.entries) {
        s += _weights[cls][entry.key] * entry.value;
      }
      scores[cls] = s;
    }
    return scores;
  }
}
