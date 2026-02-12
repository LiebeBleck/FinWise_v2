"""
Скрипт для обучения ML модели категоризации транзакций
"""
import pandas as pd
import pickle
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, accuracy_score
import sys
import os

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from loguru import logger


def train_categorization_model():
    """Обучить модель категоризации"""

    # Пути
    data_path = Path(__file__).parent.parent.parent.parent / "data" / "training" / "transactions_dataset.csv"
    model_dir = Path(__file__).parent.parent / "models"
    model_dir.mkdir(parents=True, exist_ok=True)

    logger.info(f"📂 Loading dataset from {data_path}")

    # Загрузка данных
    try:
        df = pd.read_csv(data_path)
        logger.info(f"✅ Loaded {len(df)} transactions")
        logger.info(f"📊 Categories: {df['category'].nunique()}")
        logger.info(f"📋 Category distribution:\n{df['category'].value_counts()}")
    except FileNotFoundError:
        logger.error(f"❌ Dataset not found at {data_path}")
        logger.error("Please create the dataset first using the provided CSV template")
        return False

    # Подготовка данных
    X = df['description'].str.lower()  # Приводим к нижнему регистру
    y = df['category']

    # Кодирование меток
    logger.info("🔤 Encoding labels...")
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)

    # Разделение на train/test
    # Не используем stratify из-за небольшого датасета (88 примеров для 19 категорий)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_encoded, test_size=0.2, random_state=42
    )
    logger.info(f"📊 Train size: {len(X_train)}, Test size: {len(X_test)}")

    # Векторизация текста (TF-IDF)
    logger.info("🔤 Vectorizing text with TF-IDF...")
    vectorizer = TfidfVectorizer(
        max_features=500,
        ngram_range=(1, 2),  # unigrams и bigrams
        min_df=1,
        analyzer='word'
    )
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)
    logger.info(f"✅ Vocabulary size: {len(vectorizer.vocabulary_)}")

    # Обучение модели
    logger.info("🤖 Training Random Forest model...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=20,
        min_samples_split=2,
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train_vec, y_train)
    logger.info("✅ Model trained successfully")

    # Оценка модели
    logger.info("📊 Evaluating model...")
    y_pred = model.predict(X_test_vec)
    accuracy = accuracy_score(y_test, y_pred)
    logger.info(f"🎯 Test Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")

    # Детальный отчет (только для классов, присутствующих в тесте)
    try:
        unique_labels = sorted(set(y_test) | set(y_pred))
        target_names_filtered = [label_encoder.classes_[i] for i in unique_labels]
        report = classification_report(
            y_test, y_pred,
            labels=unique_labels,
            target_names=target_names_filtered,
            zero_division=0
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
    logger.info(f"✅ Model saved to {model_path}")

    with open(vectorizer_path, "wb") as f:
        pickle.dump(vectorizer, f)
    logger.info(f"✅ Vectorizer saved to {vectorizer_path}")

    with open(encoder_path, "wb") as f:
        pickle.dump(label_encoder, f)
    logger.info(f"✅ Label encoder saved to {encoder_path}")

    # Feature importance (топ-10 фичей)
    feature_names = vectorizer.get_feature_names_out()
    importances = model.feature_importances_
    top_indices = importances.argsort()[-10:][::-1]

    logger.info("🔝 Top 10 most important features:")
    for idx in top_indices:
        logger.info(f"  - {feature_names[idx]}: {importances[idx]:.4f}")

    logger.info("✅ Training completed successfully!")
    logger.info(f"📦 Model files saved in: {model_dir}")

    return True


if __name__ == "__main__":
    logger.info("🚀 Starting ML model training...")
    success = train_categorization_model()
    if success:
        logger.info("✅ Training script completed")
    else:
        logger.error("❌ Training failed")
        sys.exit(1)
