
import os
import re
import json
import argparse
import numpy as np

from kb_common import (
    load_model,
    get_s3_client,
    get_vector_client,
    get_index_args,
    DIMENSION,
    MODEL_NAME
)

MAX_TOKENS = 200
OVERLAP = 30
BATCH_SIZE = 50


# Read an object from Amazon S3
def read_s3_file(s3, bucket, key):
    response = s3.get_object(
        Bucket=bucket,
        Key=key
    )

    return response["Body"].read().decode("utf-8-sig")


# Split Markdown documents into meaningful chunks
def chunk_document(text, tokenizer):

    sections = re.split(
        r"(?m)(?=^##[ \t]+)",
        text
    )

    title = text.splitlines()[0].strip()
    chunks = []

    for section in sections:
        section = section.strip()

        if not section or section == title:
            continue

        if not section.startswith(title):
            section = title + "\n\n" + section

        encoded = tokenizer(
            section,
            add_special_tokens=False,
            return_offsets_mapping=True,
            truncation=False
        )

        offsets = encoded["offset_mapping"]

        start = 0

        while start < len(offsets):

            end = min(start + MAX_TOKENS, len(offsets))

            char_start = offsets[start][0]
            char_end = offsets[end - 1][1]

            chunk = section[char_start:char_end].strip()

            if chunk:
                chunks.append(chunk)

            if end == len(offsets):
                break

            start = end - OVERLAP

    return chunks


def prune_stale_vectors(client, index_args, records):

    expected_keys = {
        record["key"] for record in records
    }

    existing_keys = set()

    paginator = client.get_paginator("list_vectors")

    for page in paginator.paginate(**index_args):

        for vector in page.get("vectors", []):
            existing_keys.add(vector["key"])

    stale_keys = sorted(
        existing_keys - expected_keys
    )

    print("Obsolete vectors found:", len(stale_keys))

    if not stale_keys:
        return

    for key in stale_keys:
        print("Obsolete:", key)

    confirmation = input(
        "Type DELETE to remove obsolete vectors: "
    )

    if confirmation != "DELETE":
        print("Cleanup cancelled.")
        return

    for start in range(0, len(stale_keys), 100):

        batch = stale_keys[start:start + 100]

        client.delete_vectors(
            **index_args,
            keys=batch
        )

    print("Obsolete vectors removed successfully.")



def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
    "--prune",
    action="store_true",
    help="Remove obsolete vectors after successful ingestion"
    )
    args = parser.parse_args()

    docs_bucket = os.environ["KB_DOCS_BUCKET"]

    print("Loading MiniLM model...")
    model = load_model()

    s3 = get_s3_client()
    vector_client = get_vector_client()
    index_args = get_index_args()

    records = []
    document_count = 0

    # List all documents in the S3 bucket
    paginator = s3.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=docs_bucket):

        for obj in page.get("Contents", []):

            key = obj["Key"]

            # Only process Markdown documents
            if not key.endswith(".md"):
                continue

            document_count += 1

            text = read_s3_file(s3, docs_bucket, key)

            if not text.strip():
                raise ValueError(f"Empty document: {key}")

            # Read document metadata
            metadata_text = read_s3_file(
                s3,
                docs_bucket,
                key + ".metadata.json"
            )

            labels = json.loads(metadata_text)[
                "metadataAttributes"
            ]

            # Create chunks
            chunks = chunk_document(
                text,
                model.tokenizer
            )

            print(f"{key}: {len(chunks)} chunks")

            # Prepare records
            for number, chunk in enumerate(chunks, start=1):

                metadata = {
                    **labels,
                    "text": chunk,
                    "source": key,
                    "source_uri": f"s3://{docs_bucket}/{key}",
                    "chunk_number": number,
                    "embedding_model": MODEL_NAME
                }

                records.append({
                    "key": f"{key}#{number:04d}",
                    "metadata": metadata
                })

    print("\nDocuments found:", document_count)
    print("Total chunks:", len(records))

    if not records:
        raise ValueError("No document chunks found")

    if args.dry_run:
        print("\nExample chunk:")
        print(records[0]["metadata"]["text"])
        print("\nDry run completed. No vectors written.")
        return

    # Generate embeddings and upload in batches
    uploaded = 0

    for start in range(0, len(records), BATCH_SIZE):

        batch = records[start:start + BATCH_SIZE]

        texts = [
            record["metadata"]["text"]
            for record in batch
        ]

        embeddings = model.encode(
            texts,
            normalize_embeddings=True,
            convert_to_numpy=True
        )

        vectors = []

        for record, embedding in zip(batch, embeddings):

            if len(embedding) != DIMENSION:
                raise ValueError("Invalid vector dimension")

            if not np.isfinite(embedding).all():
                raise ValueError("Invalid embedding values")

            vectors.append({
                "key": record["key"],
                "data": {
                    "float32": embedding.astype(
                        np.float32
                    ).tolist()
                },
                "metadata": record["metadata"]
            })

        # Upload embeddings to AWS S3 Vectors
        vector_client.put_vectors(
            **index_args,
            vectors=vectors
        )

        uploaded += len(vectors)

        print(f"Uploaded {uploaded}/{len(records)} vectors")

    if args.prune:
        prune_stale_vectors(
            vector_client,
            index_args,
            records
        )
    

    print("\nIngestion completed successfully!")


if __name__ == "__main__":
    main()
