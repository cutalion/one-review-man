---
layout: default
title: "Все Главы - One Review Man"
lang: ru
permalink: /
nav_order: 1
---

{% assign chapters = site.chapters | where: "lang", page.lang | sort: "chapter_number" %}

{% if chapters.size > 0 %}
{% for chapter in chapters %}
<article class="chapter-listing-card">
<header>
<h2><a href="{{ chapter.url }}">{{ chapter.title }}</a></h2>
{% if chapter.generated_date %}
<time datetime="{{ chapter.generated_date | date: '%Y-%m-%d' }}">{{ chapter.generated_date | date: "%d.%m.%Y" }}</time>
{% endif %}
</header>

{% if chapter.summary %}
<p>{{ chapter.summary }}</p>
{% endif %}
</article>
{% endfor %}
{% else %}
<section>
<h2>Пока Нет Глав!</h2>
<p>История вот-вот начнется. Загляните позже, чтобы прочитать первую главу веселой рабочей комедии!</p>
</section>
{% endif %}
