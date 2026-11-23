"""Búsqueda semántica en vivo sobre Atlas Vector Search.

Uso (desde la carpeta vectorial):
    pip install pymongo spacy
    python -m spacy download es_core_news_md
    set MONGODB_URI=mongodb+srv://USUARIO:CLAVE@cluster.xxxxx.mongodb.net/
    python buscar_semantico.py "quiero comer pescado frente al mar"

En PowerShell use:  $env:MONGODB_URI="mongodb+srv://..."
Opcional: --municipio Sampués   para combinar con un filtro exacto.
"""
import argparse
import os
import sys

import numpy as np
import spacy

MODELO = "es_core_news_md"
INDICE = "idx_vector_experiencias"
_nlp = None


def embedding(texto):
    """Mismo cálculo usado para las experiencias: promedio de los vectores
    de las palabras con contenido, normalizado a longitud 1."""
    global _nlp
    if _nlp is None:
        _nlp = spacy.load(MODELO)
    doc = _nlp(texto.lower())
    vectores = [t.vector for t in doc if t.is_alpha and not t.is_stop and t.has_vector]
    if not vectores:
        raise ValueError("La frase no tiene palabras reconocibles por el modelo.")
    v = np.mean(vectores, axis=0)
    return v / np.linalg.norm(v)


def buscar(coleccion, frase, municipio=None, limite=3):
    filtro = {"estado": "ACTIVA"}
    if municipio:
        filtro["municipio"] = municipio
    pipeline = [
        {"$vectorSearch": {
            "index": INDICE,
            "path": "embedding",
            "queryVector": [round(float(x), 5) for x in embedding(frase)],
            "numCandidates": 100,
            "limit": limite,
            "filter": filtro,
        }},
        {"$project": {"_id": 0, "titulo": 1, "municipio": 1, "categoria": 1,
                      "score": {"$meta": "vectorSearchScore"}}},
    ]
    return list(coleccion.aggregate(pipeline))


def main():
    p = argparse.ArgumentParser(description="Búsqueda semántica de experiencias")
    p.add_argument("frase", help="lo que busca el turista, en lenguaje natural")
    p.add_argument("--municipio", help="filtrar por un municipio exacto")
    p.add_argument("--limite", type=int, default=3)
    a = p.parse_args()

    uri = os.environ.get("MONGODB_URI")
    if not uri:
        sys.exit("Defina la variable MONGODB_URI con la cadena de conexión de Atlas.")

    from pymongo import MongoClient
    col = MongoClient(uri)["sabores_rutas_sucre"]["experiencias"]
    print(f'Búsqueda: "{a.frase}"\n')
    for n, r in enumerate(buscar(col, a.frase, a.municipio, a.limite), 1):
        print(f"{n}. {r['titulo']} ({r['municipio']}, {r['categoria']}) - score {r['score']:.3f}")


if __name__ == "__main__":
    main()
