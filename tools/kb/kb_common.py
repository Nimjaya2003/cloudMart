
import os
import boto3
from functools import lru_cache
from sentence_transformers import SentenceTransformer

REGION = "ap-south-1"
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
DIMENSION = 384



@lru_cache(maxsize=1)
def load_model():

    model_path = os.environ.get("KB_MODEL_PATH")

    revision = os.environ.get("KB_MODEL_REVISION")

    if model_path:

        # Cloud runtime: use the bundled MiniLM model
        model = SentenceTransformer(
            model_path,
            device="cpu",
            local_files_only=True
        )

    else:

        # Local development: use Hugging Face cache
        model = SentenceTransformer(
            MODEL_NAME,
            revision=revision,
            device="cpu"
        )

    if model.get_embedding_dimension() != DIMENSION:

        raise ValueError(
            "Incorrect embedding dimension"
        )

    return model



def get_s3_client():
    return boto3.client("s3", region_name=REGION)


def get_vector_client():
    return boto3.client("s3vectors", region_name=REGION)


def get_index_args():
    return {
        "vectorBucketName": os.environ["KB_VECTOR_BUCKET"],
        "indexName": os.environ["KB_VECTOR_INDEX"]
    }
