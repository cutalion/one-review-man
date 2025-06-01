---
layout: default
title: Ванревьюмэн
lang: ru
permalink: /
---

# Ванревьюмэн 🥊💻

> *Программистская пародия на One-Punch Man*

Добро пожаловать в мир **Ванревьюмэн** - где идеальный код встречается с подавляющей скукой, и где каждый pull request - это шедевр, не требующий исправлений.

## О История

В мире, где code review'ы внушают страх, а production баги терроризируют команды разработки, один программист стоит выше всех остальных. Его код безупречен. Его pull request'ы мгновенно одобряются. Его коммиты никогда не нужно откатывать.

Он... **Ванревьюмэн**.

Подобно тому, как [Сайтама](https://en.wikipedia.org/wiki/Saitama_(One-Punch_Man)) из легендарной манги может победить любого врага одним ударом, Ванревьюмэн может решить любую программистскую задачу идеальным кодом, который проходит ревью с первого раза. Но с великой силой приходит великая скука - ведь какая радость в программировании, когда каждое решение дается слишком легко?

### Познакомьтесь с персонажами

**Ванревьюмэн** - Главный герой
- Мастер-программист, чей код никогда не нуждается в исправлениях
- Скучает от своих подавляющих способностей  
- Каждый pull request: "LGTM, мерджу сейчас"

**ИИ-Усиленный Ученик** - Преданный ученик
- Программист-киборг с нейроинтерфейсными подключениями
- Усилен AI-системами, но все еще не может сравниться с мастером
- Отчаянно стремится изучить секреты Ванревьюмэн'а
- "Мастер, пожалуйста, научите меня вашим техникам программирования!"

## Темы программистской комедии

Наш абсурдистский tech workplace включает:
- 🔧 **Совершенство Code Review** - Код Ванревьюмэн'а, который никогда не нуждается в изменениях
- 🐛 **Катастрофы отладки** - Production чрезвычайные ситуации, которые может решить только он
- ⚔️ **Войны фреймворков** - Технологические битвы в траншеях разработки
- 👥 **Паника Pair Programming** - Коллеги, напуганные совершенством
- 🏢 **Сатира на Tech культуру** - Standup встречи, sprint planning и абсурдности стартапов
- 📚 **Археология Legacy кода** - Древние кодовые базы, угрожающие цивилизации
- 🎤 **Комедия конференций** - Tech talks и open source драма

## Структура истории

Каждая глава приносит новые программистские вызовы, которые демонстрируют подавляющие способности Ванревьюмэн'а, исследуя абсурдности современной культуры разработки программного обеспечения.

---

<div class="nav-buttons">
  <a href="/chapters" class="btn">📖 Читать главы</a>
  <a href="/characters" class="btn">👥 Персонажи</a>
  <a href="/" class="btn">🇺🇸 English Version</a>
</div>

---

*Вдохновлено легендарной мангой/аниме One-Punch Man от ONE и Yusuke Murata*

## Статус Книги

{% assign book_data = site.data.book_metadata.ru.book %}
{% assign status = site.data.book_metadata.ru.status %}

- **Текущая Глава:** {{ status.generation_count | default: 0 }}
- **Целевое Количество Глав:** {{ book_data.target_chapters }}
- **Создано Персонажей:** {{ status.characters_created | default: 0 }}
- **Последняя Генерация:** {{ status.last_generated | default: "Ещё не начато" }}

---

## Быстрая Навигация

<div class="nav-grid">
  <a href="/chapters" class="nav-card">
    <h3>📖 Читать Главы</h3>
    <p>Окунитесь в весёлые приключения</p>
  </a>
  
  <a href="/characters" class="nav-card">
    <h3>👥 Знакомство с Персонажами</h3>
    <p>Познакомьтесь с нашим эксцентричным составом</p>
  </a>
  
  <a href="/about" class="nav-card">
    <h3>🤖 О Проекте</h3>
    <p>Узнайте, как ИИ создаёт комедию</p>
  </a>
</div>

---

## Последние Главы

{% assign chapters = site.chapters | where: "lang", "ru" | sort: "chapter_number" | reverse | limit: 3 %}
{% if chapters.size > 0 %}
  <div class="recent-chapters">
    {% for chapter in chapters %}
      <div class="chapter-preview">
        <h3><a href="{{ chapter.url }}">{{ chapter.title }}</a></h3>
        <p class="chapter-meta">Глава {{ chapter.chapter_number }} • {{ chapter.generated_date | date: "%d %B %Y" }}</p>
        {% if chapter.summary %}
          <p class="chapter-summary">{{ chapter.summary }}</p>
        {% endif %}
      </div>
    {% endfor %}
  </div>
{% else %}
  <div class="no-content">
    <p>Главы ещё не сгенерированы. Приключение вот-вот начнётся! 🚀</p>
  </div>
{% endif %}

---

## Избранные Персонажи

{% assign characters = site.data.characters.ru.characters %}
{% if characters and characters.size > 0 %}
  <div class="featured-characters">
    {% for character_data in characters limit: 4 %}
      {% assign character = character_data[1] %}
      {% include character_card.html character=character %}
    {% endfor %}
  </div>
{% else %}
  <div class="no-content">
    <p>Персонажи ждут своего создания! Каждый будет иметь свою уникальную личность и причуды. 🎭</p>
  </div>
{% endif %}

---

<div class="footer-note">
  <p><em>Эта книга генерируется глава за главой с помощью ИИ, создавая постоянно развивающуюся историю офисной комедии и абсурдистского юмора. Каждая глава строится на предыдущей, персонажи развивают отношения и попадают во всё более нелепые ситуации.</em></p>
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
  margin-bottom: 0.5rem;
}

.chapter-summary {
  color: #5a6c7d;
  font-style: italic;
  line-height: 1.5;
}

.featured-characters {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
  margin: 2rem 0;
}

.no-content {
  text-align: center;
  padding: 2rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  color: #7f8c8d;
  font-style: italic;
}

.footer-note {
  background-color: #f8f9fa;
  padding: 2rem;
  border-radius: 8px;
  border-left: 4px solid #3498db;
  margin: 3rem 0;
}

.footer-note p {
  margin: 0;
  color: #5a6c7d;
  line-height: 1.6;
}

.nav-buttons {
  text-align: center;
  margin: 2rem 0;
}

.btn {
  display: inline-block;
  background-color: #3498db;
  color: white;
  padding: 0.8rem 1.5rem;
  margin: 0.5rem;
  border-radius: 6px;
  text-decoration: none;
  font-weight: bold;
  transition: background-color 0.2s ease;
}

.btn:hover {
  background-color: #2980b9;
  color: white;
  text-decoration: none;
}

@media (max-width: 768px) {
  .nav-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .nav-card {
    padding: 1.5rem;
  }
  
  .featured-characters {
    grid-template-columns: 1fr;
  }
}
</style> 
