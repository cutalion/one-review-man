#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'llm_service'

# Test script to verify task-specific model configuration
class TaskModelTester
  def initialize
    @llm_service = LLMService.new
  end

  def test_task_models
    puts "🧪 Testing task-specific model configuration..."
    puts "=" * 50

    # Test model selection for different tasks
    test_model_selection
    
    # Test task options
    test_task_options
    
    # Test naming conventions in prompts
    test_naming_conventions
    
    puts "\n✅ Task-specific model tests completed!"
  end

  private

  def test_model_selection
    puts "\n📋 Testing model selection for different tasks:"
    
    # Access private methods for testing
    generation_model = @llm_service.send(:get_model_for_task, 'generation')
    translation_model = @llm_service.send(:get_model_for_task, 'translation')
    chat_model = @llm_service.send(:get_model_for_task, 'chat')
    unknown_model = @llm_service.send(:get_model_for_task, 'unknown_task')
    
    puts "  Generation tasks: #{generation_model}"
    puts "  Translation tasks: #{translation_model}"
    puts "  Chat tasks: #{chat_model}"
    puts "  Unknown task (fallback): #{unknown_model}"
  end

  def test_task_options
    puts "\n⚙️  Testing task-specific options:"
    
    # Test different task options
    generation_options = @llm_service.send(:get_task_options, 'generation', {})
    translation_options = @llm_service.send(:get_task_options, 'translation', {})
    chat_options = @llm_service.send(:get_task_options, 'chat', {})
    
    puts "  Generation options:"
    puts "    Temperature: #{generation_options[:temperature]}"
    puts "    Max tokens: #{generation_options[:max_tokens]}"
    
    puts "  Translation options:"
    puts "    Temperature: #{translation_options[:temperature]}"
    puts "    Max tokens: #{translation_options[:max_tokens]}"
    
    puts "  Chat options:"
    puts "    Temperature: #{chat_options[:temperature]}"
    puts "    Max tokens: #{chat_options[:max_tokens]}"
  end

  def test_naming_conventions
    puts "\n🏷️  Testing naming conventions in character schema:"
    
    # Test character prompt with schema
    test_prompt = "Create a test character for verification"
    enhanced_prompt = @llm_service.send(:build_character_prompt_with_schema, test_prompt)
    
    # Check if the schema includes the naming conventions
    if enhanced_prompt.include?('real_name')
      puts "  ✅ Character schema includes real_name field"
    else
      puts "  ❌ Character schema missing real_name field"
    end
    
    if enhanced_prompt.include?('Satoru') && enhanced_prompt.include?('Genki')
      puts "  ✅ Schema includes protagonist naming examples"
    else
      puts "  ❌ Schema missing protagonist naming examples"
    end
    
    if enhanced_prompt.include?('NAMING CONVENTIONS')
      puts "  ✅ Schema includes naming convention guidance"
    else
      puts "  ❌ Schema missing naming convention guidance"
    end
    
    # Test Russian transliteration in translation prompts
    puts "\n🇷🇺 Testing Russian transliteration in translation prompts:"
    
    # Test chapter translation prompt
    chapter_prompt = @llm_service.send(:build_chapter_translation_prompt, 
                                       "Test Chapter", "Test Summary", "Test Content", "ru")
    
    if chapter_prompt.include?('Ванревьюмен')
      puts "  ✅ Chapter translation includes Russian transliteration 'Ванревьюмен'"
    else
      puts "  ❌ Chapter translation missing Russian transliteration"
    end
    
    if chapter_prompt.include?('Сатору') && chapter_prompt.include?('Генки')
      puts "  ✅ Chapter translation includes Russian name transliterations"
    else
      puts "  ❌ Chapter translation missing Russian name transliterations"
    end
    
    # Test character translation prompt
    character_prompt = @llm_service.send(:build_character_translation_prompt,
                                         "One Review Man", "Test description", ["trait1"], 
                                         "Test skills", "Test phrase", "Test backstory", 
                                         "Test quirks", "ru")
    
    if character_prompt.include?('Ванревьюмен')
      puts "  ✅ Character translation includes Russian transliteration 'Ванревьюмен'"
    else
      puts "  ❌ Character translation missing Russian transliteration"
    end
    
    if character_prompt.include?('ИИ-Усиленный Ученик')
      puts "  ✅ Character translation includes AI-Enhanced Disciple Russian translation"
    else
      puts "  ❌ Character translation missing AI-Enhanced Disciple Russian translation"
    end
  end
end

# Run the test if this script is executed directly
if __FILE__ == $PROGRAM_NAME
  tester = TaskModelTester.new
  tester.test_task_models
end 
