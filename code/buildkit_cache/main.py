import numpy as np
import pandas as pd
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression


def main():
    # Загрузка данных iris
    data = load_iris()
    X, y = data.data, data.target

    # Обучение модели логистической регрессии
    model = LogisticRegression(max_iter=200)
    model.fit(X, y)
    print("Модель успешно обучена!")


if __name__ == "__main__":
    main()
