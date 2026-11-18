
import argparse
import numpy as np

from kb_common import (
    load_model,
    get_vector_client,
    get_index_args
)


def retrieve(question, top_k=3, category=None):

    if not question.strip():
        raise ValueError("Question cannot be empty")

    model = load_model()
    client = get_vector_client()

    # Generate a vector for the user's question
    embedding = model.encode(
        question,
        normalize_embeddings=True
    )

    # Prepare the search request
    params = {
        **get_index_args(),
        "queryVector": {
            "float32": embedding.astype(
                np.float32
            ).tolist()
        },
        "topK": top_k,
        "returnMetadata": True,
        "returnDistance": True
    }

    # Optional metadata filter
    if category:
        params["filter"] = {
            "category": {"$eq": category}
        }

    # Search for relevant document chunks
    response = client.query_vectors(**params)

    return response.get("vectors", [])


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument("question")
    parser.add_argument("--top-k", type=int, default=3)
    parser.add_argument("--category")

    args = parser.parse_args()

    results = retrieve(
        args.question,
        args.top_k,
        args.category
    )

    print("\nQuestion:", args.question)

    for rank, result in enumerate(results, start=1):

        metadata = result["metadata"]

        print(f"\n--- Result {rank} ---")
        print("Source:", metadata["source"])
        print("Category:", metadata["category"])
        print("Distance:", result.get("distance"))
        print("Content:")
        print(metadata["text"])


if __name__ == "__main__":
    main()
