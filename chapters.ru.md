---
layout: default
title: "Все Главы - One Review Man"
lang: ru
permalink: /chapters/
---

# Все Главы

{% assign chapters = site.chapters | where: "lang", page.lang | sort: "chapter_number" %}

{% if chapters.size > 0 %}
  <div class="chapters-grid">
    {% for chapter in chapters %}
      <div class="chapter-card">
        <div class="chapter-header">
          <span class="chapter-number">Глава {{ chapter.chapter_number }}</span>
          {% if chapter.generated_date %}
            <span class="chapter-date">{{ chapter.generated_date | date: "%d.%m.%Y" }}</span>
          {% endif %}
        </div>
        
        <h2 class="chapter-title">
          <a href="{{ chapter.url }}">{{ chapter.title }}</a>
        </h2>
        
        {% if chapter.summary %}
          <p class="chapter-summary">{{ chapter.summary }}</p>
        {% endif %}
        
        {% if chapter.characters and chapter.characters.size > 0 %}
          <div class="chapter-characters">
            <strong>Персонажи:</strong>
            {% for character_slug in chapter.characters %}
              {% assign character = site.data.characters.ru.characters[character_slug] %}
              {% if character %}
                <span class="character-tag">{{ character.name }}</span>
              {% endif %}
            {% endfor %}
          </div>
        {% endif %}
        
        {% if chapter.new_characters and chapter.new_characters.size > 0 %}
          <div class="new-characters-badge">
            ✨ Знакомит с {{ chapter.new_characters.size }} новым{% if chapter.new_characters.size > 1 %}и{% endif %} персонаж{% if chapter.new_characters.size > 1 %}ами{% else %}ем{% endif %}
          </div>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-chapters">
    <h2>Пока Нет Глав!</h2>
    <p>История вот-вот начнется. Загляните позже, чтобы прочитать первую главу веселой рабочей комедии!</p>
    <a href="/" class="back-home">← Назад на главную</a>
  </div>
{% endif %}

---

## Прогресс Книги

{% assign book_data = site.data.book_metadata.ru.book %}
{% assign target = book_data.target_chapters | default: 50 %}
{% assign current = chapters.size %}

<div class="progress-section">
  <div class="progress-stats">
    <div class="stat">
      <span class="stat-number">{{ current }}</span>
      <span class="stat-label">Написано Глав</span>
    </div>
    <div class="stat">
      <span class="stat-number">{{ target }}</span>
      <span class="stat-label">Целевое Количество</span>
    </div>
    <div class="stat">
      <span class="stat-number">{{ current | times: 100 | divided_by: target }}%</span>
      <span class="stat-label">Завершено</span>
    </div>
  </div>
  
  <div class="progress-bar">
    <div class="progress-fill" style="width: {{ current | times: 100 | divided_by: target }}%"></div>
  </div>
</div>

<style>
.chapters-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
}

.chapter-card {
  background: white;
  border: 1px solid #e1e5e9;
  border-radius: 12px;
  padding: 1.5rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.chapter-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 12px rgba(0,0,0,0.15);
}

.chapter-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.chapter-number {
  background-color: #3498db;
  color: white;
  padding: 0.3rem 0.8rem;
  border-radius: 15px;
  font-size: 0.9rem;
  font-weight: bold;
}

.chapter-date {
  color: #7f8c8d;
  font-size: 0.9rem;
}

.chapter-title {
  margin: 0 0 1rem 0;
  color: #2c3e50;
}

.chapter-title a {
  color: inherit;
  text-decoration: none;
}

.chapter-title a:hover {
  color: #3498db;
}

.chapter-summary {
  color: #5a6c7d;
  font-style: italic;
  line-height: 1.5;
  margin-bottom: 1rem;
}

.chapter-characters {
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.character-tag {
  background-color: #ecf0f1;
  color: #2c3e50;
  padding: 0.2rem 0.5rem;
  border-radius: 10px;
  font-size: 0.8rem;
  margin-right: 0.5rem;
  display: inline-block;
  margin-bottom: 0.3rem;
}

.new-characters-badge {
  background-color: #e8f5e8;
  color: #27ae60;
  padding: 0.5rem;
  border-radius: 6px;
  font-size: 0.9rem;
  text-align: center;
  border: 1px solid #d5f4e6;
}

.no-chapters {
  text-align: center;
  padding: 4rem 2rem;
  background-color: #f8f9fa;
  border-radius: 12px;
  margin: 2rem 0;
}

.no-chapters h2 {
  color: #2c3e50;
  margin-bottom: 1rem;
}

.no-chapters p {
  color: #7f8c8d;
  font-size: 1.1rem;
  margin-bottom: 2rem;
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

.progress-section {
  background-color: #f8f9fa;
  border-radius: 12px;
  padding: 2rem;
  margin: 3rem 0;
}

.progress-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 2rem;
  margin-bottom: 2rem;
  text-align: center;
}

.stat {
  display: flex;
  flex-direction: column;
  align-items: center;
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

.progress-bar {
  background-color: #ecf0f1;
  border-radius: 20px;
  height: 20px;
  overflow: hidden;
}

.progress-fill {
  background: linear-gradient(90deg, #3498db 0%, #2ecc71 100%);
  height: 100%;
  border-radius: 20px;
  transition: width 0.3s ease;
}

@media (max-width: 768px) {
  .chapters-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .chapter-card {
    padding: 1rem;
  }
  
  .progress-stats {
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
  }
  
  .stat-number {
    font-size: 2rem;
  }
}
</style> 
