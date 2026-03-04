"""
Экспорт обученной LinearSVC модели в JSON формат для Pure Dart Offline ML.

Запуск (в директории server/):
    python -m app.ml.training.export_dart_model

Выходные файлы (помещаются в assets/ml/ во Flutter проекте):
    vocabulary.json    — список признаков (word + char n-grams)
    idf_weights.json   — IDF веса для каждого признака
    model_weights.json — матрица W и вектор b LinearSVC
    label_classes.json — список классов (категорий)

Размер: ~900KB для 4000 признаков × 30 категорий.
"""
import json
import pickle
import sys
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.pipeline import FeatureUnion
from sklearn.svm import LinearSVC
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score

# Пути
ROOT = Path(__file__).parent.parent.parent.parent
MODEL_DIR = Path(__file__).parent.parent / "models"
DATA_PATH = ROOT / "data" / "training" / "transactions_dataset.csv"
FLUTTER_ASSETS = ROOT.parent / "assets" / "ml"  # D:/FinWise_v2/assets/ml/

sys.path.insert(0, str(ROOT.parent))
sys.path.insert(0, str(ROOT))


def main():
    print("📂 Loading dataset...")
    df = pd.read_csv(DATA_PATH)
    print(f"✅ Loaded {len(df)} rows, {df['category'].nunique()} categories")

    # NLP предобработка (лемматизация)
    try:
        from app.services.text_preprocessing_service import preprocess_batch
        print("🔤 Applying NLP preprocessing...")
        X = pd.Series(preprocess_batch(df["description"].tolist()))
    except ImportError:
        print("⚠️  text_preprocessing_service not found, using raw text")
        X = df["description"]

    # Кодирование меток
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df["category"])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # FeatureUnion: word n-grams + char n-grams
    print("🔤 Fitting FeatureUnion vectorizer...")
    vectorizer = FeatureUnion([
        ("word", TfidfVectorizer(
            analyzer="word",
            ngram_range=(1, 2),
            max_features=2000,
            sublinear_tf=True,
            min_df=1,
        )),
        ("char", TfidfVectorizer(
            analyzer="char_wb",
            ngram_range=(3, 5),
            max_features=2000,
            sublinear_tf=True,
            min_df=1,
        )),
    ])
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)
    print(f"✅ Feature matrix: {X_train_vec.shape}")

    # Standalone LinearSVC (без CalibratedClassifierCV — проще экспортировать)
    print("🤖 Training standalone LinearSVC for export...")
    svc = LinearSVC(C=1.0, max_iter=2000, random_state=42)
    svc.fit(X_train_vec, y_train)

    y_pred = svc.predict(X_test_vec)
    acc = accuracy_score(y_test, y_pred)
    print(f"🎯 Export model accuracy: {acc*100:.2f}%")

    # Извлекаем vocabulary и IDF из FeatureUnion
    print("📦 Extracting vocabulary and weights...")

    # Vocabulary: объединяем фичи обоих векторайзеров
    word_tfidf: TfidfVectorizer = vectorizer.transformer_list[0][1]
    char_tfidf: TfidfVectorizer = vectorizer.transformer_list[1][1]

    word_vocab = word_tfidf.get_feature_names_out().tolist()
    char_vocab = char_tfidf.get_feature_names_out().tolist()
    vocabulary = word_vocab + char_vocab

    word_idf = word_tfidf.idf_.tolist()
    char_idf = char_tfidf.idf_.tolist()
    idf_weights = word_idf + char_idf

    # W: shape (n_classes, n_features), b: shape (n_classes,)
    W = svc.coef_.astype(np.float32).tolist()  # float32 → меньше размер
    b = svc.intercept_.astype(np.float32).tolist()
    classes = label_encoder.classes_.tolist()

    print(f"📊 Vocabulary size: {len(vocabulary)}")
    print(f"📊 Classes: {len(classes)}")
    print(f"📊 W shape: {svc.coef_.shape}")

    # Сохраняем JSON файлы
    FLUTTER_ASSETS.mkdir(parents=True, exist_ok=True)

    vocab_path = FLUTTER_ASSETS / "vocabulary.json"
    idf_path = FLUTTER_ASSETS / "idf_weights.json"
    weights_path = FLUTTER_ASSETS / "model_weights.json"
    classes_path = FLUTTER_ASSETS / "label_classes.json"

    with open(vocab_path, "w", encoding="utf-8") as f:
        json.dump(vocabulary, f, ensure_ascii=False)
    print(f"✅ Saved {vocab_path} ({vocab_path.stat().st_size // 1024}KB)")

    with open(idf_path, "w") as f:
        json.dump(idf_weights, f)
    print(f"✅ Saved {idf_path} ({idf_path.stat().st_size // 1024}KB)")

    with open(weights_path, "w") as f:
        json.dump({"W": W, "b": b}, f)
    print(f"✅ Saved {weights_path} ({weights_path.stat().st_size // 1024}KB)")

    with open(classes_path, "w", encoding="utf-8") as f:
        json.dump(classes, f, ensure_ascii=False)
    print(f"✅ Saved {classes_path} ({classes_path.stat().st_size // 1024}KB)")

    total_kb = sum(
        p.stat().st_size for p in [vocab_path, idf_path, weights_path, classes_path]
    ) // 1024
    print(f"\n🎉 Export complete! Total size: {total_kb}KB")
    print(f"📁 Files in: {FLUTTER_ASSETS}")
    print("\n⚠️  Добавь assets/ml/ в pubspec.yaml если ещё не добавлено:")
    print("   flutter:\n     assets:\n       - assets/ml/")


if __name__ == "__main__":
    main()
