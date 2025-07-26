---
layout: default
title: "Characters - One Review Man"
lang: en
permalink: /characters/
nav_order: 2
---

# Characters

Meet the quirky cast of **One Review Man** - each with their own unique personality, backstory, and role in our workplace comedy!

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
<p><small>Since {{ character.first_appearance }}</small></p>
{% endif %}
</header>

<p>{{ character.description }}</p>

{% if character.personality_traits and character.personality_traits.size > 0 %}
<section>
<h3>Personality</h3>
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
<h3>Relationships</h3>
<ul>
{% for relationship in character.relationships %}
{% assign other_char = site.data.characters.characters[relationship.character] %}
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

{% assign appearances = site.chapters | where_exp: "chapter", "chapter.characters contains character.slug" %}
{% if appearances.size > 0 %}
<footer>
<p><strong>Appears in {{ appearances.size }} chapter{% if appearances.size != 1 %}s{% endif %}</strong></p>
</footer>
{% endif %}
</article>
{% endfor %}
{% else %}
<section>
<h2>No Characters Yet!</h2>
<p>Our cast of characters is waiting to be created. Each chapter may introduce new personalities to join the comedy!</p>

<section>
<h3>Coming Soon:</h3>
<ul>
<li>🤔 The perpetually confused protagonist</li>
<li>😏 The sarcastic office veteran</li>
<li>📋 The overly enthusiastic manager</li>
<li>🤖 The tech support guru</li>
<li>☕ The coffee-obsessed intern</li>
</ul>
</section>
</section>
{% endif %}

---

## Character Statistics

<section>
<h3>Statistics</h3>
<ul>
<li><strong>Total Characters:</strong> {{ characters.size | default: 0 }}</li>

{% assign total_chapters = site.chapters.size %}
{% if total_chapters > 0 %}
<li><strong>Characters per Chapter:</strong> {{ characters.size | times: 100 | divided_by: total_chapters }}%</li>
{% endif %}

{% assign characters_with_relationships = characters | where_exp: "char", "char.relationships.size > 0" %}
<li><strong>Have Relationships:</strong> {{ characters_with_relationships.size | default: 0 }}</li>
</ul>
</section>
