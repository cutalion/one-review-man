---
layout: default
title: One Review Man
lang: en
permalink: /
---

# One Review Man 🥊💻

> *A programming parody of One-Punch Man*

Welcome to the world of **One Review Man** - where perfect code meets overwhelming boredom, and where every pull request is a masterpiece that requires no revisions.

## About the Story

In a world where code reviews are feared and production bugs terrorize development teams, one programmer stands above all others. His code is flawless. His pull requests are instantly approved. His commits never need to be reverted. 

He is... **One Review Man**.

Just as [Saitama](https://en.wikipedia.org/wiki/Saitama_(One-Punch_Man)) from the legendary manga can defeat any enemy with a single punch, One Review Man can solve any programming challenge with perfect code that passes review on the first try. But with great power comes great boredom - for what joy is there in coding when every solution comes too easily?

### Meet the Characters

**One Review Man** - The protagonist
- Master programmer whose code never needs revision
- Bored by his overwhelming abilities
- Every pull request: "LGTM, merging now"

**The AI-Enhanced Disciple** - The devoted student
- Cyborg programmer with neural interface connections
- Enhanced by AI systems but still can't match the master
- Desperately seeks to learn One Review Man's secrets
- "Master, please teach me your coding techniques!"

## Programming Comedy Themes

Our absurdist tech workplace features:
- 🔧 **Code Review Perfection** - One Review Man's code that never needs changes
- 🐛 **Debug Disasters** - Production emergencies only he can solve
- ⚔️ **Framework Wars** - Technology battles in the development trenches  
- 👥 **Pair Programming Panic** - Colleagues intimidated by perfection
- 🏢 **Tech Culture Satire** - Standup meetings, sprint planning, and startup absurdities
- 📚 **Legacy Code Archaeology** - Ancient codebases threatening civilization
- 🎤 **Conference Comedy** - Tech talks and open source drama

## Story Structure

Each chapter brings new programming challenges that showcase One Review Man's overwhelming abilities while exploring the absurdities of modern software development culture.

---

<div class="nav-buttons">
  <a href="/chapters" class="btn">📖 Read Chapters</a>
  <a href="/characters" class="btn">👥 Meet Characters</a>
  <a href="/index.ru.html" class="btn">🇷🇺 Russian Version</a>
</div>

---

*Inspired by the legendary One-Punch Man manga/anime by ONE and Yusuke Murata*

## Book Status

{% assign book_data = site.data.book_metadata.book %}
{% assign status = site.data.book_metadata.status %}

- **Current Chapter:** {{ status.generation_count | default: 0 }}
- **Target Chapters:** {{ book_data.target_chapters }}
- **Characters Created:** {{ status.characters_created | default: 0 }}
- **Last Generated:** {{ status.last_generated | default: "Not yet started" }}

---

## Quick Navigation

<div class="nav-grid">
  <a href="/chapters" class="nav-card">
    <h3>📖 Read Chapters</h3>
    <p>Dive into the hilarious adventures</p>
  </a>
  
  <a href="/characters" class="nav-card">
    <h3>👥 Meet Characters</h3>
    <p>Get to know our quirky cast</p>
  </a>
  
  <a href="/about" class="nav-card">
    <h3>🤖 About the Project</h3>
    <p>Learn how AI creates comedy</p>
  </a>
</div>

---

## Latest Chapters

{% assign chapters = site.chapters | sort: "chapter_number" | reverse | limit: 3 %}
{% if chapters.size > 0 %}
  <div class="recent-chapters">
    {% for chapter in chapters %}
      <div class="chapter-preview">
        <h3><a href="{{ chapter.url }}">{{ chapter.title }}</a></h3>
        <p class="chapter-meta">Chapter {{ chapter.chapter_number }} • {{ chapter.generated_date | date: "%B %d, %Y" }}</p>
        {% if chapter.summary %}
          <p class="chapter-summary">{{ chapter.summary }}</p>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-content">
    <p>No chapters have been generated yet. The adventure is about to begin! 🚀</p>
  </div>
{% endif %}

---

## Featured Characters

{% assign characters = site.data.characters.characters %}
{% if characters and characters.size > 0 %}
  <div class="featured-characters">
    {% for character_data in characters limit: 4 %}
      {% assign character = character_data[1] %}
      {% include character_card.html character=character %}
    {% endfor %}
  </div>
{% else %}
  <div class="no-content">
    <p>Characters are waiting to be created! Each will have their own unique personality and quirks. 🎭</p>
  </div>
{% endif %}

---

<div class="footer-note">
  <p><em>This book is generated chapter by chapter using AI, creating an ever-evolving story of workplace comedy and absurdist humor. Each chapter builds on the last, with characters developing relationships and getting into increasingly ridiculous situations.</em></p>
</div>

<style>
.nav-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin: 2rem 0;
}

.nav-card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem;
  border-radius: 12px;
  text-decoration: none;
  text-align: center;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.nav-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 8px 15px rgba(0,0,0,0.2);
  color: white;
  text-decoration: none;
}

.nav-card h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1.3rem;
}

.nav-card p {
  margin: 0;
  opacity: 0.9;
}

.recent-chapters {
  display: grid;
  gap: 1.5rem;
  margin: 2rem 0;
}

.chapter-preview {
  padding: 1.5rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  border-left: 4px solid #3498db;
}

.chapter-preview h3 {
  margin: 0 0 0.5rem 0;
  color: #2c3e50;
}

.chapter-preview h3 a {
  color: inherit;
  text-decoration: none;
}

.chapter-preview h3 a:hover {
  color: #3498db;
}

.chapter-meta {
  color: #7f8c8d;
  font-size: 0.9rem;
  margin: 0 0 0.5rem 0;
}

.chapter-summary {
  color: #5a6c7d;
  font-style: italic;
  margin: 0;
}

.featured-characters {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
  margin: 2rem 0;
}

.no-content {
  text-align: center;
  padding: 3rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  color: #7f8c8d;
  font-style: italic;
}

.footer-note {
  margin-top: 3rem;
  padding: 2rem;
  background-color: #e8f4f8;
  border-radius: 8px;
  border-left: 4px solid #3498db;
}

.footer-note p {
  margin: 0;
  color: #5a6c7d;
  line-height: 1.6;
}
</style> 
