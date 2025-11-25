#!/bin/bash
set -e

echo "🔧 Setting up Jules environment..."

# Install dependencies for building Ruby
echo "🛠️ Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev

# Install rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
if [ ! -d "$HOME/.rbenv" ]; then
    echo "💎 Installing rbenv..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    eval "$(rbenv init -)"
    
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    eval "$(rbenv init -)"
fi

# Install Ruby 3.4.4
if ! rbenv versions | grep -q "3.4.4"; then
    echo "💎 Installing Ruby 3.4.4 (this may take a while)..."
    rbenv install 3.4.4
    rbenv global 3.4.4
else
    echo "💎 Ruby 3.4.4 already installed."
    rbenv global 3.4.4
fi

# Install Bundler
echo "📦 Installing Bundler..."
gem install bundler

# Install dependencies for book-generator
echo "📚 Installing book-generator dependencies..."
cd book-generator
bundle install
cd ..

# Install dependencies for site
echo "🌐 Installing site dependencies..."
cd site
bundle install
cd ..

echo "✅ Environment setup complete!"
echo "You can now run:"
echo "  - ./quick_test.sh to verify the setup"
echo "  - book-generator/bin/book to use the CLI"
echo "  - cd site && bundle exec jekyll serve to run the website"
