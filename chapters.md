---
layout: default
title: "All Chapters - One Review Man"
lang: en
permalink: /chapters/
nav_order: 1
---

# All Chapters

{% assign chapters = site.chapters | where: "lang", "en" | sort: "chapter_number" %}

{% if chapters.size > 0 %}
  <div class="chapters-grid">
    {% for chapter in chapters %}
      <div class="chapter-card">
        <div class="chapter-header">
          <span class="chapter-number">Chapter {{ chapter.chapter_number }}</span>
          {% if chapter.generated_date %}
            <span class="chapter-date">{{ chapter.generated_date | date: "%m/%d/%Y" }}</span>
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
            <strong>Characters:</strong>
            {% for character_slug in chapter.characters %}
              {% assign character = site.data.characters.characters[character_slug] %}
              {% if character %}
                <span class="character-tag">{{ character.name }}</span>
              {% endif %}
            {% endfor %}
          </div>
        {% endif %}
        
        {% if chapter.new_characters and chapter.new_characters.size > 0 %}
          <div class="new-characters-badge">
            ✨ Introduces {{ chapter.new_characters.size }} new character{% if chapter.new_characters.size != 1 %}s{% endif %}
          </div>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-chapters">
    <h2>No Chapters Yet!</h2>
    <p>The story is about to begin. Check back soon for the first chapter of hilarious workplace comedy!</p>
    <a href="/" class="back-home">← Back to Home</a>
  </div>
{% endif %}

---

## Book Progress

{% assign book_data = site.data.book_metadata.book %}
{% assign target = book_data.target_chapters | default: 50 %}
{% assign current = chapters.size %}

<div class="progress-section">
  <div class="progress-stats">
    <div class="stat">
      <span class="stat-number">{{ current }}</span>
      <span class="stat-label">Chapters Written</span>
    </div>
    <div class="stat">
      <span class="stat-number">{{ target }}</span>
      <span class="stat-label">Target Chapters</span>
    </div>
    <div class="stat">
      <span class="stat-number">{{ current | times: 100 | divided_by: target }}%</span>
      <span class="stat-label">Complete</span>
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
  font-weight: bold;
  transition: background-color 0.2s ease;
}

.back-home:hover {
  background-color: #2980b9;
  color: white;
  text-decoration: none;
}

.progress-section {
  background-color: #f8f9fa;
  padding: 2rem;
  border-radius: 12px;
  margin-top: 3rem;
}

.progress-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
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
  width: 100%;
  height: 12px;
  background-color: #e1e5e9;
  border-radius: 6px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #3498db 0%, #2ecc71 100%);
  transition: width 0.3s ease;
}

@media (max-width: 768px) {
  .chapters-grid {
    grid-template-columns: 1fr;
  }
  
  .progress-stats {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
}
</style> 
