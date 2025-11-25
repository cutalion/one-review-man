# Syntax=docker/dockerfile:1

FROM ruby:3.4.4

# Install system dependencies
RUN apt-get update -qq && apt-get install -y build-essential libffi-dev nodejs npm

# Set working directory
WORKDIR /app

# Copy the Gemfiles and gemspecs first to cache dependencies
COPY book-generator/Gemfile book-generator/book-generator.gemspec /app/book-generator/
COPY site/Gemfile /app/site/

# Install dependencies for book-generator
WORKDIR /app/book-generator
RUN bundle install

# Install dependencies for site
WORKDIR /app/site
RUN bundle install

# Copy the rest of the application
WORKDIR /app
COPY . .

# Expose port for Jekyll
EXPOSE 4000

# Default command (can be overridden)
CMD ["/bin/bash"]
