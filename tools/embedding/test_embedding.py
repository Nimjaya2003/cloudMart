
from sentence_transformers import SentenceTransformer
import numpy as np

# Load the MiniLM embedding model
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

print("Loading MiniLM model...")
model = SentenceTransformer(MODEL_NAME)

# Example sentences
texts = [
    "Can I return hiking boots that I have already worn?",
    "Footwear with visible outdoor wear cannot be returned unless defective.",
    "Standard delivery takes three to five business days."
]

# Generate embeddings
embeddings = model.encode(
    texts,
    normalize_embeddings=True
)

# Display embedding information
print("\nEmbedding results:")
print("Number of sentences:", len(embeddings))
print("Embedding dimensions:", embeddings.shape[1])

# Calculate cosine similarities
similarity = np.dot(embeddings, embeddings.T)

print("\nSimilarity between sentences:")
print("Question vs returns:", round(float(similarity[0][1]), 4))
print("Question vs delivery:", round(float(similarity[0][2]), 4))
