---
layout: default
title: "All Chapters - One Review Man"
lang: en
permalink: /
nav_order: 1
---

{% assign chapters = site.chapters | where: "lang", "en" | sort: "chapter_number" %}

{% if chapters.size > 0 %}
{% for chapter in chapters %}
<article class="chapter-listing-card">
<header>
<h2><a href="{{ chapter.url }}">Chapter {{ chapter.chapter_number }}: {{ chapter.title }}</a></h2>
{% if chapter.generated_date %}
<time datetime="{{ chapter.generated_date | date: '%Y-%m-%d' }}">{{ chapter.generated_date | date: "%m/%d/%Y" }}</time>
{% endif %}
</header>

{% if chapter.summary %}
<p>{{ chapter.summary }}</p>
{% endif %}
</article>
{% endfor %}
{% else %}
<section>
<h2>No Chapters Yet!</h2>
<p>The story is about to begin. Check back soon for the first chapter of hilarious workplace comedy!</p>
</section>
{% endif %}
