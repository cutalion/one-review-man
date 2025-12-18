# frozen_string_literal: true

require 'json'

module BookCore
  module AgentTools
    # Tool definitions for Story Bible interaction.
    # These tools allow an LLM agent to query and update the Story Bible.
    class StoryBibleTools
      def self.definitions
        [
          {
            type: 'function',
            function: {
              name: 'get_character',
              description: 'Get full character profile by ID. Use when you need details about a character\'s appearance, personality, backstory, or skills.',
              parameters: {
                type: 'object',
                properties: {
                  id: { type: 'string', description: "Character slug, e.g. 'kenji_yamamoto'" }
                },
                required: ['id']
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'list_characters',
              description: 'List all characters (IDs and names only). Call get_character for full details.',
              parameters: {
                type: 'object',
                properties: {
                  appeared_in: {
                    type: 'integer',
                    description: 'Filter to characters who appeared in this chapter number'
                  }
                }
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'get_location',
              description: 'Get location details by ID.',
              parameters: {
                type: 'object',
                properties: {
                  id: { type: 'string', description: "Location slug, e.g. 'server_room'" }
                },
                required: ['id']
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'list_locations',
              description: 'List all locations (IDs and names only).',
              parameters: { type: 'object', properties: {} }
            }
          },
          {
            type: 'function',
            function: {
              name: 'get_chapter_summaries',
              description: 'Get summaries of recent chapters for context.',
              parameters: {
                type: 'object',
                properties: {
                  count: {
                    type: 'integer',
                    description: 'Number of recent chapter summaries to return (default: 3)'
                  }
                }
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'get_plot_threads',
              description: 'Get all active plot threads that need to be continued or resolved.',
              parameters: { type: 'object', properties: {} }
            }
          },
          {
            type: 'function',
            function: {
              name: 'get_world_rules',
              description: 'Get established world rules and facts about how this universe works.',
              parameters: { type: 'object', properties: {} }
            }
          },
          {
            type: 'function',
            function: {
              name: 'search_facts',
              description: 'Keyword search over all story facts (events, rules, locations). Use when looking for specific information.',
              parameters: {
                type: 'object',
                properties: {
                  query: { type: 'string', description: 'Search keyword (case-insensitive)' }
                },
                required: ['query']
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'get_relationships',
              description: 'Get relationships involving a specific character.',
              parameters: {
                type: 'object',
                properties: {
                  character_id: { type: 'string', description: 'Character slug to get relationships for' }
                },
                required: ['character_id']
              }
            }
          },
          {
            type: 'function',
            function: {
              name: 'submit_chapter',
              description: 'Submit the completed chapter. Call this when you have finished writing the chapter.',
              parameters: {
                type: 'object',
                properties: {
                  title: { type: 'string', description: 'Chapter title' },
                  content: { type: 'string', description: 'Full chapter content in Markdown format' },
                  summary: { type: 'string', description: 'Brief summary of what happens in this chapter' },
                  characters_featured: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'List of character IDs featured in this chapter'
                  },
                  new_characters: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        name: { type: 'string' },
                        description: { type: 'string' },
                        personality_traits: { type: 'array', items: { type: 'string' } }
                      }
                    },
                    description: 'Any new characters introduced in this chapter'
                  },
                  new_facts: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        type: { type: 'string', enum: %w[event world_rule location] },
                        id: { type: 'string' },
                        description: { type: 'string' }
                      }
                    },
                    description: 'Any new facts established in this chapter'
                  }
                },
                required: %w[title content summary]
              }
            }
          }
        ]
      end

      # Convert tool definitions to the format expected by the API
      def self.for_api
        definitions.map do |tool|
          {
            type: tool[:type],
            function: tool[:function].transform_keys(&:to_s)
          }
        end
      end
    end
  end
end
