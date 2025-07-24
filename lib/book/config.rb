class Config
  def book_metadata
    @book_metadata ||= YAML.load_file('_data/book_metadata.yml')
  end

  def characters
    @characters ||= YAML.load_file('_data/characters.yml')
  end

  def world
    @world ||= YAML.load_file('_data/world.yml')
  end

  def strings
    @strings ||= YAML.load_file('_data/strings.yml')
  end

  def llm_config
    @llm_config ||= YAML.load_file('scripts/llm_config.yml') || {}
  end

  def generation_log
    @generation_log ||= YAML.load_file('_data/generation_log.yml') || {}
  end

  def chapters_dir
    '_chapters'
  end

  def characters_dir
    '_characters'
  end

  def data_dir
    '_data'
  end
end
