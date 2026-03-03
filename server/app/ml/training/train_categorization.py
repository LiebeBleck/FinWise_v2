"""
Скрипт для обучения ML модели категоризации транзакций.
Алгоритм: LinearSVC (лучший для sparse TF-IDF)
Features: word n-grams + char n-grams (FeatureUnion)
"""
import pandas as pd
import pickle
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.pipeline import FeatureUnion
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, accuracy_score
import sys

# Add parent directories to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from loguru import logger
from services.text_preprocessing_service import preprocess_batch


def train_categorization_model():
    """Обучить модель категоризации"""

    # Пути
    data_path = Path(__file__).parent.parent.parent.parent / "data" / "training" / "transactions_dataset.csv"
    model_dir = Path(__file__).parent.parent / "models"
    model_dir.mkdir(parents=True, exist_ok=True)

    logger.info(f"📂 Loading dataset from {data_path}")

    try:
        df = pd.read_csv(data_path)
        logger.info(f"✅ Loaded {len(df)} transactions")
        logger.info(f"📊 Categories: {df['category'].nunique()}")
        logger.info(f"📋 Category distribution:\n{df['category'].value_counts()}")
    except FileNotFoundError:
        logger.error(f"❌ Dataset not found at {data_path}")
        return False

    # NLP предобработка (лемматизация + стоп-слова)
    logger.info("🔤 Preprocessing text (lemmatization + stop words)...")
    X_raw = df['description'].tolist()
    X = pd.Series(preprocess_batch(X_raw))
    logger.info(f"✅ Preprocessing done. Example: '{X_raw[0]}' → '{X.iloc[0]}'")

    y = df['category']

    # Кодирование меток
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)

    # Stratified split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
    )
    logger.info(f"📊 Train size: {len(X_train)}, Test size: {len(X_test)}")

    # FeatureUnion: word n-grams + char n-grams
    logger.info("🔤 Building FeatureUnion (word + char n-grams)...")
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
    logger.info(f"✅ Feature matrix shape: {X_train_vec.shape}")

    # LinearSVC + калибровка вероятностей (для confidence score)
    logger.info("🤖 Training LinearSVC model...")
    base_svc = LinearSVC(
        C=1.0,
        max_iter=2000,
        random_state=42,
    )
    model = CalibratedClassifierCV(base_svc, cv=5)
    model.fit(X_train_vec, y_train)
    logger.info("✅ Model trained successfully")

    # Оценка
    y_pred = model.predict(X_test_vec)
    accuracy = accuracy_score(y_test, y_pred)
    logger.info(f"🎯 Test Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")

    try:
        unique_labels = sorted(set(y_test) | set(y_pred))
        target_names_filtered = [label_encoder.classes_[i] for i in unique_labels]
        report = classification_report(
            y_test, y_pred,
            labels=unique_labels,
            target_names=target_names_filtered,
            zero_division=0,
        )
        logger.info(f"📋 Classification Report:\n{report}")
    except Exception as e:
        logger.warning(f"Could not generate classification report: {e}")

    # Сохранение модели
    logger.info("💾 Saving model...")
    model_path = model_dir / "categorization_model.pkl"
    vectorizer_path = model_dir / "vectorizer.pkl"
    encoder_path = model_dir / "label_encoder.pkl"

    with open(model_path, "wb") as f:
        pickle.dump(model, f)
    with open(vectorizer_path, "wb") as f:
        pickle.dump(vectorizer, f)
    with open(encoder_path, "wb") as f:
        pickle.dump(label_encoder, f)

    logger.info(f"✅ Model saved to {model_dir}")
    logger.info("✅ Training completed successfully!")
    return True


if __name__ == "__main__":
    logger.info("🚀 Starting ML model training...")
    success = train_categorization_model()
    if success:
        logger.info("✅ Training script completed")
    else:
        logger.error("❌ Training failed")
        sys.exit(1)
