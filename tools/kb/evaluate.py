
import csv
import time

from pathlib import Path
from statistics import mean

from ask import retrieve
from kb_common import load_model


BASE_DIR = Path(__file__).resolve().parent

QUESTIONS_FILE = BASE_DIR / "questions.csv"
RESULTS_FILE = BASE_DIR / "evaluation-results.csv"

TOP_K = 3


def main():

    print("Loading MiniLM model...")
    load_model()

    with QUESTIONS_FILE.open(
        "r", encoding="utf-8-sig"
    ) as file:

        questions = list(csv.DictReader(file))

    total = 0
    hit_at_1 = 0
    hit_at_3 = 0
    reciprocal_ranks = []
    latencies = []
    out_of_scope_distances = []
    report = []

    for number, row in enumerate(questions, start=1):

        question = row["question"]
        expected = row["expected_source"]

        # Measure retrieval time
        start = time.perf_counter()

        results = retrieve(
            question,
            top_k=TOP_K
        )

        elapsed_ms = (
            time.perf_counter() - start
        ) * 1000

        sources = [
            result["metadata"]["source"]
            for result in results
        ]

        best_distance = (
            results[0].get("distance")
            if results else None
        )

        best_source = sources[0] if sources else ""

        rank = None

        # Handle out-of-scope questions separately
        if expected == "OUT_OF_SCOPE":

            status = "OUT_OF_SCOPE"

            if best_distance is not None:
                out_of_scope_distances.append(
                    best_distance
                )

        else:

            total += 1
            latencies.append(elapsed_ms)

            if expected in sources:
                rank = sources.index(expected) + 1

            if rank == 1:
                hit_at_1 += 1

            if rank is not None and rank <= TOP_K:
                hit_at_3 += 1
                reciprocal_ranks.append(1 / rank)
                status = "PASS"
            else:
                reciprocal_ranks.append(0)
                status = "MISS"

        print(f"\n[{number}] {question}")
        print("Expected:", expected)
        print("Retrieved:", best_source)
        print("Correct rank:", rank)
        print("Distance:", best_distance)
        print(f"Latency: {elapsed_ms:.2f} ms")
        print("Status:", status)

        report.append({
            "question": question,
            "expected_source": expected,
            "top_source": best_source,
            "retrieved_sources": "; ".join(sources),
            "correct_rank": rank,
            "best_distance": best_distance,
            "latency_ms": round(elapsed_ms, 2),
            "status": status
        })

    # Save detailed results
    with RESULTS_FILE.open(
        "w",
        newline="",
        encoding="utf-8"
    ) as file:

        writer = csv.DictWriter(
            file,
            fieldnames=[
                "question",
                "expected_source",
                "top_source",
                "retrieved_sources",
                "correct_rank",
                "best_distance",
                "latency_ms",
                "status"
            ]
        )

        writer.writeheader()
        writer.writerows(report)

    # Final evaluation summary
    print("\n" + "=" * 50)
    print("CLOUDMART RETRIEVAL EVALUATION")
    print("=" * 50)

    print("Questions evaluated:", total)

    if total:
        print(
            f"Hit@1: {hit_at_1}/{total} "
            f"({hit_at_1 / total * 100:.2f}%)"
        )

        print(
            f"Hit@3: {hit_at_3}/{total} "
            f"({hit_at_3 / total * 100:.2f}%)"
        )

        print(
            f"MRR@3: {mean(reciprocal_ranks):.4f}"
        )

        print(
            f"Average retrieval latency: "
            f"{mean(latencies):.2f} ms"
        )

    print("\nOut-of-scope distances:")

    for distance in out_of_scope_distances:
        print(round(distance, 4))

    print("\nReport saved to:", RESULTS_FILE)


if __name__ == "__main__":
    main()
