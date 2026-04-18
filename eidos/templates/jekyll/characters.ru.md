---
layout: default
title: "Персонажи - {{STORY_TITLE_RU}}"
lang: ru
permalink: /characters/
nav_order: 2
---

# Персонажи

Познакомьтесь с командой **{{STORY_TITLE_RU}}** - каждый со своей уникальной личностью, предысторией и ролью в нашем {{STORY_GENRE_DESCRIPTION_RU}}!

{% assign characters = site.characters | where: "lang", page.lang %}

{% if characters and characters.size > 0 %}
{% for character in characters %}
<article>
<header>
<h2>
{% assign character_page = site.characters | where: "slug", character.slug | first %}
{% if character_page %}
<a href="{{ character_page.url }}">{{ character.name }}</a>
{% else %}
<a href="/characters/{{ character.slug | slugify }}">{{ character.name }}</a>
{% endif %}
</h2>
{% if character.first_appearance %}
<p><small>С {{ character.first_appearance }}</small></p>
{% endif %}
</header>

<p>{{ character.description }}</p>

{% if character.personality_traits and character.personality_traits.size > 0 %}
<section>
<h3>Характер</h3>
<ul>
{% for trait in character.personality_traits %}
<li>{{ trait }}</li>
{% endfor %}
</ul>
</section>
{% endif %}

{% if character.catchphrase %}
<aside>
<blockquote>"{{ character.catchphrase }}"</blockquote>
</aside>
{% endif %}

{% if character.relationships and character.relationships.size > 0 %}
<section>
<h3>Связи</h3>
<ul>
{% for relationship in character.relationships %}
{% assign other_char = site.data.characters.ru.characters[relationship.character] %}
{% assign other_char_page = site.characters | where: "slug", relationship.character | first %}
<li>
{% if other_char %}
{% if other_char_page %}
<a href="{{ other_char_page.url }}">{{ other_char.name }}</a>
{% else %}
<a href="/characters/{{ relationship.character | slugify }}">{{ other_char.name }}</a>
{% endif %}
{% else %}
{{ relationship.character }}
{% endif %}
- {{ relationship.type }}
</li>
{% endfor %}
</ul>
</section>
{% endif %}

{% assign appearances = site.chapters | where: "lang", "ru" | where_exp: "chapter", "chapter.characters contains character.slug" %}
{% if appearances.size > 0 %}
<footer>
<p><strong>Появляется в {{ appearances.size }} глав{% if appearances.size == 1 %}е{% elsif appearances.size < 5 %}ах{% else %}ах{% endif %}</strong></p>
</footer>
{% endif %}
</article>
{% endfor %}
{% else %}
<section>
<h2>Пока Нет Персонажей!</h2>
<p>Наша команда персонажей ждет создания. Каждая глава может представить новые личности для участия в комедии!</p>

<section>
<h3>Скоро:</h3>
<ul>
<li>🤔 Вечно озадаченный протагонист</li>
<li>😏 Саркастичный офисный ветеран</li>
<li>📋 Чрезмерно энтузиастичный менеджер</li>
<li>🤖 Гуру технической поддержки</li>
<li>☕ Одержимый кофе стажер</li>
</ul>
</section>
</section>
{% endif %}

---

## Статистика Персонажей

<section>
<h3>Статистика</h3>
<ul>
<li><strong>Всего Персонажей:</strong> {{ characters.size | default: 0 }}</li>

{% assign total_chapters = site.chapters | where: "lang", "ru" | size %}
{% if total_chapters > 0 %}
<li><strong>Персонажей на Главу:</strong> {{ characters.size | times: 100 | divided_by: total_chapters }}%</li>
{% endif %}

{% assign characters_with_relationships = characters | where_exp: "char", "char.relationships.size > 0" %}
<li><strong>Есть Отношения:</strong> {{ characters_with_relationships.size | default: 0 }}</li>
</ul>
</section>
