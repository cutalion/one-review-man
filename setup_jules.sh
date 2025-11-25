#!/bin/bash
set -e

echo "🔧 Setting up Jules environment (Docker)..."

# Build the Docker image
echo "🐳 Building Docker image..."
docker compose build

echo "✅ Environment setup complete!"
echo "You can now run:"
echo "  - docker compose run --rm app ./quick_test.sh to verify the setup"
echo "  - docker compose run --rm app book-generator/bin/book to use the CLI"
echo "  - docker compose up to run the website"
