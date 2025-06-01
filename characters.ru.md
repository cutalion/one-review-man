---
layout: default
title: "Персонажи - One Review Man"
lang: ru
permalink: /characters/
---

# Персонажи

Познакомьтесь с эксцентричной командой **One Review Man** - каждый со своей уникальной личностью, предысторией и ролью в нашей рабочей комедии!

{% assign characters = site.data.characters.ru.characters %}

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
              С {{ character.first_appearance }}
            </span>
          {% endif %}
        </div>
        
        <p class="character-description">{{ character.description }}</p>
        
        {% if character.personality_traits and character.personality_traits.size > 0 %}
          <div class="traits-section">
            <strong>Характер:</strong>
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
            <strong>Отношения:</strong>
            <ul class="relationships-list">
              {% for relationship in character.relationships %}
                {% assign other_char = site.data.characters.ru.characters[relationship.character] %}
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
        {% assign appearances = site.chapters | where: "lang", "ru" | where_exp: "chapter", "chapter.characters contains character.slug" %}
        {% if appearances.size > 0 %}
          <div class="appearances-count">
            <strong>Появляется в {{ appearances.size }} глав{% if appearances.size == 1 %}е{% elsif appearances.size < 5 %}ах{% else %}ах{% endif %}</strong>
          </div>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-characters">
    <h2>Пока Нет Персонажей!</h2>
    <p>Наша команда персонажей ждет создания. Каждая глава может представить новые личности для участия в комедии!</p>
    <div class="character-teaser">
      <h3>Скоро:</h3>
      <ul>
        <li>🤔 Вечно озадаченный протагонист</li>
        <li>😏 Саркастичный офисный ветеран</li>
        <li>📋 Чрезмерно энтузиастичный менеджер</li>
        <li>🤖 Гуру технической поддержки</li>
        <li>☕ Одержимый кофе стажер</li>
      </ul>
    </div>
    <a href="/" class="back-home">← Назад на главную</a>
  </div>
{% endif %}

---

## Статистика Персонажей

<div class="character-stats">
  <div class="stats-grid">
    <div class="stat-box">
      <span class="stat-number">{{ characters.size | default: 0 }}</span>
      <span class="stat-label">Всего Персонажей</span>
    </div>
    
    {% assign total_chapters = site.chapters | where: "lang", "ru" | size %}
    {% if total_chapters > 0 %}
      <div class="stat-box">
        <span class="stat-number">{{ characters.size | times: 100 | divided_by: total_chapters }}%</span>
        <span class="stat-label">Персонажей на Главу</span>
      </div>
    {% endif %}
    
    {% assign characters_with_relationships = characters | where_exp: "char", "char[1].relationships.size > 0" %}
    <div class="stat-box">
      <span class="stat-number">{{ characters_with_relationships.size | default: 0 }}</span>
      <span class="stat-label">Есть Отношения</span>
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
  font-weight: bold;
}

.catchphrase {
  background-color: #f8f9fa;
  border-left: 4px solid #3498db;
  padding: 1rem;
  margin: 1rem 0;
  border-radius: 4px;
  color: #2c3e50;
}

.relationships-section {
  background-color: #f1f8ff;
  padding: 1rem;
  border-radius: 6px;
  border: 1px solid #dbeafe;
}

.relationships-list {
  margin: 0.5rem 0 0 0;
  padding-left: 1.2rem;
}

.relationships-list li {
  margin-bottom: 0.3rem;
}

.relationships-list a {
  color: #3498db;
  text-decoration: none;
  font-weight: bold;
}

.relationships-list a:hover {
  text-decoration: underline;
}

.appearances-count {
  background-color: #e8f5e8;
  color: #27ae60;
  padding: 0.5rem;
  border-radius: 6px;
  font-size: 0.9rem;
  text-align: center;
  border: 1px solid #d5f4e6;
  margin-top: 1rem;
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
  border: 1px solid #e1e5e9;
}

.character-teaser h3 {
  color: #3498db;
  margin-bottom: 1rem;
}

.character-teaser ul {
  text-align: left;
  display: inline-block;
  color: #5a6c7d;
}

.back-home {
  background-color: #3498db;
  color: white;
  padding: 0.8rem 1.5rem;
  border-radius: 6px;
  text-decoration: none;
  display: inline-block;
  transition: background-color 0.2s ease;
}

.back-home:hover {
  background-color: #2980b9;
  color: white;
  text-decoration: none;
}

.character-stats {
  background-color: #f8f9fa;
  border-radius: 12px;
  padding: 2rem;
  margin: 3rem 0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 2rem;
  text-align: center;
}

.stat-box {
  background-color: white;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.stat-number {
  display: block;
  font-size: 2.5rem;
  font-weight: bold;
  color: #3498db;
  line-height: 1;
}

.stat-label {
  color: #7f8c8d;
  font-size: 0.9rem;
  margin-top: 0.5rem;
  display: block;
}

@media (max-width: 768px) {
  .characters-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .character-profile-card {
    padding: 1rem;
  }
  
  .character-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .stats-grid {
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 1rem;
  }
  
  .stat-number {
    font-size: 2rem;
  }
}
</style> 
