from typing import List, Dict
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


# Ключевые слова для каждого научного направления
DIRECTIONS_KEYWORDS = {
    'it': ('программирование алгоритмы искусственный интеллект '
           'машинное обучение базы данных сети кибербезопасность '
           'цифровизация ИТ-решения разработка ПО'),
    'ecology': ('экология окружающая среда загрязнение '
                'устойчивое развитие биоразнообразие климат'),
    'chemistry': ('химия материалы нанотехнологии полимеры катализ синтез'),
    'energy': ('энергетика возобновляемые источники солнечная энергия '
               'ветер водород эффективность')
}


def calculate_direction_similarity(direction_code: str, fund_profile: str) -> float:
    """Расчёт косинусного сходства направления с профилем фонда."""
    direction_text = DIRECTIONS_KEYWORDS.get(direction_code, '')
    if not direction_text or not fund_profile:
        return 0.0
    vectorizer = TfidfVectorizer()
    tfidf_matrix = vectorizer.fit_transform([direction_text, fund_profile])
    similarity = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])[0][0]
    return float(similarity)


class FundRatingCalculator:
    """Калькулятор рейтинга грантовых фондов."""

    @staticmethod
    def calculate_base_score(
        fund_id: int,
        weights: Dict[str, float],
        criteria_scores: Dict[int, Dict[str, float]]
    ) -> float:
        """Расчёт базового рейтинга методом SAW."""
        base_score = 0.0
        fund_scores = criteria_scores.get(fund_id, {})
        for criterion, weight in weights.items():
            v_ik = fund_scores.get(criterion, 0.0)
            base_score += weight * v_ik
        return base_score

    @classmethod
    def calculate_rating(
        cls,
        funds: List[Dict],
        weights: Dict[str, float],
        criteria_scores: Dict[int, Dict[str, float]],
        fund_profiles: Dict[int, str],
        direction_code: str
    ) -> List[Dict]:
        """Расчёт итогового рейтинга с учётом профильного соответствия."""
        ALPHA = 0.6
        results = []
        for fund in funds:
            fid = fund['id']
            # Базовый рейтинг методом SAW
            base = cls.calculate_base_score(fid, weights, criteria_scores)
            # Косинусное сходство направления с профилем фонда
            similarity = calculate_direction_similarity(
                direction_code,
                fund_profiles.get(fid, '')
            )
            # Аддитивная свёртка
            final = ALPHA * base + (1 - ALPHA) * similarity
            results.append({
                'fund_id': fid,
                'name': fund['name'],
                'score': round(final * 100, 2)
            })
        # Сортировка и ранжирование
        results.sort(key=lambda x: x['score'], reverse=True)
        for i, item in enumerate(results, 1):
            item['rank'] = i
        return results