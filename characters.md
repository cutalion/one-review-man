---
layout: default
title: "Characters - One Review Man"
lang: en
permalink: /characters/
---

# Characters

Meet the quirky cast of **One Review Man** - each with their own unique personality, backstory, and role in our workplace comedy!

{% assign characters = site.data.characters.en.characters %}

{% if characters and characters.size > 0 %}
  <div class="characters-grid">
    {% for character_data in characters %}
      {% assign character = character_data[1] %}
      <div class="character-profile-card">
        <div class="character-header">
          <h2 class="character-name">
            <a href="/characters/{{ character.slug }}">{{ character.name }}</a>
          </h2>
          {% if character.first_appearance %}
            <span class="first-appearance-badge">
              Since {{ character.first_appearance }}
            </span>
          {% endif %}
        </div>
        
        <p class="character-description">{{ character.description }}</p>
        
        {% if character.personality_traits and character.personality_traits.size > 0 %}
          <div class="traits-section">
            <strong>Personality:</strong>
            <div class="traits-list">
              {% for trait in character.personality_traits %}
                <span class="trait-badge">{{ trait }}</span>
              {% endfor %}
            </div>
          </div>
        {% endif %}
        
        {% if character.catchphrase %}
          <div class="catchphrase">
            <em>"{{ character.catchphrase }}"</em>
          </div>
        {% endif %}
        
        {% if character.relationships and character.relationships.size > 0 %}
          <div class="relationships-section">
            <strong>Relationships:</strong>
            <ul class="relationships-list">
              {% for relationship in character.relationships %}
                {% assign other_char = site.data.characters.characters[relationship.character] %}
                <li>
                  {% if other_char %}
                    <a href="/characters/{{ relationship.character }}">{{ other_char.name }}</a>
                  {% else %}
                    {{ relationship.character }}
                  {% endif %}
                  - {{ relationship.type }}
                </li>
              {% endfor %}
            </ul>
          </div>
        {% endif %}
        
        {% comment %} Count appearances {% endcomment %}
        {% assign appearances = site.chapters | where_exp: "chapter", "chapter.characters contains character.slug" %}
        {% if appearances.size > 0 %}
          <div class="appearances-count">
            <strong>Appears in {{ appearances.size }} chapter{% if appearances.size != 1 %}s{% endif %}</strong>
          </div>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-characters">
    <h2>No Characters Yet!</h2>
    <p>Our cast of characters is waiting to be created. Each chapter may introduce new personalities to join the comedy!</p>
    <div class="character-teaser">
      <h3>Coming Soon:</h3>
      <ul>
        <li>🤔 The perpetually confused protagonist</li>
        <li>😏 The sarcastic office veteran</li>
        <li>📋 The overly enthusiastic manager</li>
        <li>🤖 The tech support guru</li>
        <li>☕ The coffee-obsessed intern</li>
      </ul>
    </div>
    <a href="/" class="back-home">← Back to Home</a>
  </div>
{% endif %}

---

## Character Statistics

<div class="character-stats">
  <div class="stats-grid">
    <div class="stat-box">
      <span class="stat-number">{{ characters.size | default: 0 }}</span>
      <span class="stat-label">Total Characters</span>
    </div>
    
    {% assign total_chapters = site.chapters.size %}
    {% if total_chapters > 0 %}
      <div class="stat-box">
        <span class="stat-number">{{ characters.size | times: 100 | divided_by: total_chapters }}%</span>
        <span class="stat-label">Characters per Chapter</span>
      </div>
    {% endif %}
    
    {% assign characters_with_relationships = characters | where_exp: "char", "char[1].relationships.size > 0" %}
    <div class="stat-box">
      <span class="stat-number">{{ characters_with_relationships.size | default: 0 }}</span>
      <span class="stat-label">Have Relationships</span>
    </div>
  </div>
</div>

<style>
.characters-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
}

.character-profile-card {
  background: white;
  border: 1px solid #e1e5e9;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.character-profile-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 12px rgba(0,0,0,0.15);
}

.character-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.character-name {
  margin: 0;
  color: #2c3e50;
  flex: 1;
}

.character-name a {
  color: inherit;
  text-decoration: none;
}

.character-name a:hover {
  color: #3498db;
}

.first-appearance-badge {
  background-color: #e8f4f8;
  color: #3498db;
  padding: 0.3rem 0.8rem;
  border-radius: 12px;
  font-size: 0.8rem;
  font-weight: bold;
  white-space: nowrap;
}

.character-description {
  color: #5a6c7d;
  line-height: 1.5;
  margin-bottom: 1.5rem;
  font-style: italic;
}

.traits-section, .relationships-section {
  margin-bottom: 1rem;
}

.traits-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.5rem;
}

.trait-badge {
  background-color: #3498db;
  color: white;
  padding: 0.3rem 0.7rem;
  border-radius: 15px;
  font-size: 0.8rem;
  font-weight: 500;
}

.catchphrase {
  background-color: #f8f9fa;
  padding: 1rem;
  border-left: 4px solid #e74c3c;
  border-radius: 0 6px 6px 0;
  margin: 1rem 0;
  color: #2c3e50;
  font-size: 1.1rem;
}

.relationships-list {
  list-style: none;
  padding: 0;
  margin-top: 0.5rem;
}

.relationships-list li {
  padding: 0.3rem 0;
  color: #7f8c8d;
}

.relationships-list a {
  color: #3498db;
  text-decoration: none;
  font-weight: 500;
}

.relationships-list a:hover {
  text-decoration: underline;
}

.appearances-count {
  margin-top: 1.5rem;
  padding: 0.8rem;
  background-color: #e8f5e8;
  border-radius: 6px;
  text-align: center;
  color: #27ae60;
  font-size: 0.9rem;
}

.no-characters {
  text-align: center;
  padding: 4rem 2rem;
  background-color: #f8f9fa;
  border-radius: 12px;
  margin: 2rem 0;
}

.no-characters h2 {
  color: #2c3e50;
  margin-bottom: 1rem;
}

.no-characters p {
  color: #7f8c8d;
  font-size: 1.1rem;
  margin-bottom: 2rem;
}

.character-teaser {
  background-color: white;
  padding: 2rem;
  border-radius: 8px;
  margin: 2rem 0;
  border: 2px dashed #e1e5e9;
}

.character-teaser h3 {
  color: #3498db;
  margin-bottom: 1rem;
}

.character-teaser ul {
  text-align: left;
  display: inline-block;
  color: #7f8c8d;
}

.character-teaser li {
  margin-bottom: 0.5rem;
}

.back-home {
  background-color: #3498db;
  color: white;
  padding: 0.8rem 1.5rem;
  border-radius: 6px;
  text-decoration: none;
  font-weight: bold;
  transition: background-color 0.2s ease;
}

.back-home:hover {
  background-color: #2980b9;
  color: white;
  text-decoration: none;
}

.character-stats {
  background-color: #f8f9fa;
  padding: 2rem;
  border-radius: 12px;
  margin-top: 3rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 2rem;
  text-align: center;
}

.stat-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.stat-number {
  font-size: 2.5rem;
  font-weight: bold;
  color: #3498db;
  line-height: 1;
}

.stat-label {
  color: #7f8c8d;
  font-size: 0.9rem;
  margin-top: 0.5rem;
}

@media (max-width: 768px) {
  .characters-grid {
    grid-template-columns: 1fr;
  }
  
  .character-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
}
</style> 
