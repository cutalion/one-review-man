# LLM Integration for One Review Man

This directory contains LLM-powered content generation tools for the "One Review Man" programming comedy series.

## 🤖 What's New

The scripts now include AI-powered content generation capabilities using the [official OpenAI Ruby SDK](https://github.com/openai/openai-ruby):

- **Automatic Chapter Generation**: Create entire chapters with AI
- **Character Creation**: Generate detailed characters with personalities and quirks
- **Content Improvement**: Enhance existing content for humor, clarity, or consistency
- **Interactive Chat**: Discuss story ideas with the AI

## 🚀 Quick Start

### 1. Install Dependencies

```bash
bundle install
```

### 2. Set Up OpenAI Configuration

Run the setup command to create a configuration template:

```bash
ruby scripts/demo_llm.rb setup
```

This creates `scripts/llm_config.yml` with example settings.

### 3. Configure Your OpenAI API Key

**🔒 Recommended: Use Environment Variables (Secure)**

```bash
export OPENAI_API_KEY="your-api-key-here"
export OPENAI_ORG_ID="your-org-id"        # optional
export OPENAI_PROJECT_ID="your-project"   # optional
```

**Alternative: Edit Config File (Less Secure)**

Edit `scripts/llm_config.yml`:

```yaml
# openai_api_key: your-api-key-here  # Uncomment and set, or use env var
model: gpt-4o-mini
timeout: 240
max_retries: 2
default_options:
  temperature: 0.7
  max_tokens: 2000
```

**Why Environment Variables?**
- ✅ Keeps secrets out of your git repository
- ✅ Follows [OpenAI Ruby SDK conventions](https://raw.githubusercontent.com/openai/openai-ruby/5160a5d0055f436b55680bdf7ea9e4b174c2b0fc/lib/openai/client.rb)
- ✅ Works seamlessly in production environments
- ✅ Easy to manage across different environments (dev/staging/prod)

Get your API key from: https://platform.openai.com/api-keys

### 4. Try the Demo

```bash
ruby scripts/demo_llm.rb
```

## 📚 Usage Guide

### Generate Characters

```bash
# Generate different types of characters
ruby scripts/manage_characters.rb generate hero     # Fellow programmer
ruby scripts/manage_characters.rb generate villain  # Bad coder
ruby scripts/manage_characters.rb generate side     # Workplace NPC
ruby scripts/manage_characters.rb generate mentor   # Senior figure
```

### Generate Chapters

```bash
# Generate next chapter (interactive)
ruby scripts/generate_chapter.rb next

# Generate automatically without prompts
ruby scripts/generate_chapter.rb next --auto

# Regenerate an existing chapter
ruby scripts/generate_chapter.rb regenerate 1
```

### Improve Content

```bash
# Make a character funnier
ruby scripts/manage_characters.rb improve character_slug humor

# Improve chapter clarity
ruby scripts/generate_chapter.rb improve 1 clarity

# Ensure consistency
ruby scripts/generate_chapter.rb improve 1 consistency
```

### View Prompts

```bash
# See the prompt that would be used for a chapter
ruby scripts/generate_chapter.rb prompt 1
```

## 🎭 Character Types

### Hero Characters
Fellow programmers with impressive skills but not as perfect as One Review Man.
- Look up to or compete with One Review Man
- Have specialties that create comedy
- Represent positive programming practices

### Villain Characters  
Represent bad programming practices and create chaos.
- Challenge One Review Man's perfect code
- Embody everything wrong with software development
- Create obstacles through poor practices

### Side Characters
Workplace NPCs that provide comic relief.
- Fill specific roles in the tech company
- Have unique perspectives on One Review Man
- Represent common workplace archetypes

### Mentor Characters
Senior figures with deep programming wisdom.
- May have trained One Review Man or others
- Represent old-school vs new-school development
- Provide guidance during coding crises

## 🎭 Character Features

### Naming Conventions (NEW!)

**Mirrors One-Punch Man anime naming structure:**

#### Main Characters
- **One Review Man** (Professional Title) 
  - Real Name: **Satoru** (パロディ of Saitama)
  - Most people call him "One Review Man" or "One Review Man-san"
  - Only his disciple calls him "Satoru" or "Satoru-sensei"

- **AI-Enhanced Disciple** (Professional Title)
  - Real Name: **Genki** (パロディ of Genos)
  - Others call him "AI-Enhanced Disciple" or "Disciple-kun"
  - Satoru calls him "Genki" in private conversations

#### Dialogue Rules
- **Other characters → Satoru**: "One Review Man", "One Review Man-san", "sir"
- **Genki → Satoru**: "Satoru-sensei", "Satoru", "Master"
- **Satoru → Genki**: "Genki", occasionally "Disciple"
- **Others → Genki**: "AI-Enhanced Disciple", "Disciple-kun"
- **Internal monologue**: Can use real names

#### Other Characters
- May have both professional titles and real names
- Use workplace hierarchy when addressing the protagonist
- Follow formal/respectful address patterns typical in programming environments

#### Russian Transliteration (NEW!)
**Maintains consistency with original One-Punch Man Russian localization:**

- **"One Review Man" → "Ванревьюмен"** (follows "One Punch Man" → "Ванпанчмен" pattern)
- **"AI-Enhanced Disciple" → "ИИ-Усиленный Ученик"** (professional title translation)
- **Real names keep Japanese style:** "Satoru" → "Сатору", "Genki" → "Генки"
- **Respectful address:** "Сатору-сенсей" for "Satoru-sensei"
- **Programming terms:** Natural mix of English and Russian ("код", "программист", but "pull request", "git")

### Automatic Content Generation
- Full chapter content with proper formatting
- Character interactions and dialogue
- Programming humor and parody elements
- Proper story progression
- **Consistent naming conventions** following One-Punch Man structure

### Character Integration
- Automatically includes relevant existing characters
- Creates new characters mentioned in the story
- Maintains character consistency across chapters
- Tracks character relationships and interactions
- **Uses proper naming conventions** (professional titles vs. real names)

### World Building
- Maintains consistency with established universe
- Tracks used plot devices to avoid repetition
- Builds on previous chapters and character development
- Integrates One-Punch Man parody elements

## 🛠 Advanced Features

### Content Improvement Types

#### Humor Enhancement
- Adds more programming jokes and puns
- Enhances workplace comedy situations
- Improves timing and delivery of jokes
- Adds more absurdist elements

#### Clarity Improvement
- Improves readability and flow
- Clarifies confusing passages
- Enhances story structure
- Maintains humor while improving clarity

#### Consistency Check
- Ensures character behavior matches established traits
- Maintains world-building consistency
- Checks for continuity errors
- Aligns with established programming parody themes

### Mock Responses

If no OpenAI API key is configured, the system provides mock responses for development:
- Sample chapter content with programming humor
- Example characters with proper structure
- Allows testing without API costs
- Demonstrates expected output format

## 🔧 Configuration Options

### OpenAI Settings

The system uses the official [OpenAI Ruby SDK](https://github.com/openai/openai-ruby) for reliable, well-maintained API access.

```yaml
# Basic configuration
openai_api_key: your-api-key-here
model: gpt-4o-mini  # Default model for all tasks

# Task-specific models (NEW!)
models:
  generation: gpt-4o        # For chapters, characters, improvements
  translation: gpt-4o-mini  # For translation tasks
  chat: gpt-4o-mini        # For interactive chat

timeout: 240

# Task-specific options (NEW!)
task_options:
  generation:
    temperature: 0.8    # More creative for content
    max_tokens: 4000    # Longer responses for chapters
  translation:
    temperature: 0.3    # More consistent for translation
    max_tokens: 3000    # Adequate for translation
  chat:
    temperature: 0.7    # Balanced for conversations
    max_tokens: 2000    # Standard length
```

### Task-Specific Model Configuration

**NEW FEATURE**: You can now use different models for different types of tasks to optimize for quality and cost:

#### Content Generation Tasks
- **Chapters**: Higher quality model (gpt-4o) for creative writing
- **Characters**: Higher quality model (gpt-4o) for detailed character creation
- **Content Improvement**: Higher quality model (gpt-4o) for nuanced edits

#### Translation Tasks
- **Chapter Translation**: Cost-effective model (gpt-4o-mini) for consistent translation
- **Character Translation**: Cost-effective model (gpt-4o-mini) for efficient translation

#### Interactive Tasks
- **Chat/Demo**: Fast model (gpt-4o-mini) for quick responses

### Model Selection

Available OpenAI models:

| Model | Best For | Cost | Speed | Recommended Use |
|-------|----------|------|-------|-----------------|
| `gpt-4o-mini` | **Translation & Chat** - Great balance of quality and cost | Low | Fast | Translation, chat, testing |
| `gpt-4o` | **Content Generation** - Highest quality, complex tasks | High | Moderate | Chapters, characters, improvements |
| `gpt-4-turbo` | Good balance of capability and speed | Medium | Fast | Alternative for generation tasks |
| `gpt-3.5-turbo` | Simple tasks, fastest responses | Very Low | Very Fast | Development testing only |

### Advanced Configuration

```yaml
# Complete configuration example
openai_api_key: your-api-key-here
model: gpt-4o-mini  # Fallback model

# Task-specific models
models:
  generation: gpt-4o        # High quality for creative content
  translation: gpt-4o-mini  # Fast and cost-effective
  chat: gpt-4o-mini        # Quick responses

timeout: 240
max_retries: 2

# Global defaults
default_options:
  temperature: 0.7
  max_tokens: 2000

# Task-specific overrides
task_options:
  generation:
    temperature: 0.8    # More creative
    max_tokens: 4000    # Longer content
  translation:
    temperature: 0.3    # More consistent
    max_tokens: 3000    # Adequate length
  chat:
    temperature: 0.7    # Balanced
    max_tokens: 2000    # Standard length
```

## 🎯 Best Practices

### API Usage
1. **Use task-specific models** for optimal cost and quality balance:
   - `gpt-4o` for content generation (chapters, characters)
   - `gpt-4o-mini` for translation and interactive chat
2. Start with the recommended configuration, then adjust based on your needs
3. Monitor your API usage and costs at https://platform.openai.com/usage
4. Set reasonable `max_tokens` limits to control costs

### Model Selection Strategy
1. **Content Generation**: Use `gpt-4o` for highest quality creative writing
2. **Translation**: Use `gpt-4o-mini` for cost-effective, consistent translation
3. **Development/Testing**: Use `gpt-4o-mini` or `gpt-3.5-turbo` to save costs
4. **Production**: Mix models based on task importance and budget

### Character Generation
1. Start with main characters (hero/mentor types)
2. Add supporting characters gradually
3. Create villains to provide conflict
4. Use side characters for comic relief

### Chapter Generation
1. Generate chapters in order for better continuity
2. Review and edit generated content before finalizing
3. Use improvement commands to enhance specific aspects
4. Translate chapters after English version is complete

### Content Quality
1. Always review AI-generated content before publishing
2. Use improvement commands to refine humor and clarity
3. Maintain consistency with established characters
4. Keep the programming parody theme consistent

### Cost Optimization
1. Use `gpt-4o` only for final content generation
2. Use `gpt-4o-mini` for drafts, translation, and testing
3. Set appropriate `max_tokens` limits for each task type
4. Consider using `gpt-3.5-turbo` for development and experimentation

## 🐛 Troubleshooting

### Common Issues

#### "No OpenAI client configured"
- Run `ruby scripts/demo_llm.rb setup` to create config
- Edit `scripts/llm_config.yml` with your API key
- Get API key from https://platform.openai.com/api-keys

#### "OpenAI API Error" messages
- Verify API key is correct and active
- Check you have API credits/quota available
- Ensure internet connection is working
- Try a different model (e.g., gpt-3.5-turbo for testing)

#### Generation quality issues
- Try different temperature settings (0.6-0.8)
- Use more specific prompts or character types
- Run improvement commands on generated content
- Consider switching to gpt-4o for higher quality

#### Rate limiting errors
- The official SDK handles retries automatically
- Consider adding delays between requests for bulk operations
- Check your rate limits at https://platform.openai.com/account/limits

### Getting Help

1. Run the demo for interactive guidance: `ruby scripts/demo_llm.rb`
2. Check script help: `ruby scripts/generate_chapter.rb` (no arguments)
3. View configuration: Option 5 in the demo menu
4. Check the existing prompts in `scripts/prompts/` for examples

## 📁 File Structure

```
scripts/
├── llm_service.rb           # Core OpenAI integration
├── generate_chapter.rb      # Chapter generation with AI
├── manage_characters.rb     # Character management with AI
├── demo_llm.rb             # Interactive demo
├── llm_config.yml          # OpenAI configuration (created)
└── prompts/
    ├── chapter_prompts.txt  # Chapter generation prompts
    └── character_prompts.txt # Character generation prompts
```

## 🎬 Example Workflow

1. **Set up OpenAI configuration**
   ```bash
   # Recommended: Set environment variable (secure)
   export OPENAI_API_KEY="your-api-key-here"
   
   # Create config file for non-sensitive settings
   ruby scripts/demo_llm.rb setup
   ```

2. **Generate initial characters**
   ```bash
   ruby scripts/manage_characters.rb generate hero
   ruby scripts/manage_characters.rb generate side
   ```

3. **Generate first chapter**
   ```bash
   ruby scripts/generate_chapter.rb next
   ```

4. **Improve the chapter**
   ```bash
   ruby scripts/generate_chapter.rb improve 1 humor
   ```

5. **Translate to other languages**
   ```bash
   ruby scripts/translate_content.rb chapter 1 ru
   ```

## 🔮 Future Extensibility

The `LLMService` class is designed as an abstraction layer. While currently OpenAI-only, it can be extended to support additional providers in the future:

- Other API providers (Claude, Cohere, etc.)
- Local models (Ollama, LM Studio)
- Custom fine-tuned models
- Multi-provider fallbacks

The interface remains consistent, making it easy to add new providers without changing the higher-level generation scripts.

Enjoy creating hilarious programming comedy with AI assistance! 🚀 
