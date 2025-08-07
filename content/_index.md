---
date: "2022-10-24"
sections:
- block: hero
  content:
    image:
      filename: welcome.jpg
    text: |
      <br>

      The **Wowchemy Research Group** has been a center of excellence for Artificial Intelligence research, teaching, and practice since its founding in 2016.
    title: |
      Wowchemy
      Research Group
- block: collection
  content:
    count: 5
    filters:
      author: ""
      category: ""
      exclude_featured: false
      publication_type: ""
      tag: ""
    offset: 0
    order: desc
    page_type: post
    subtitle: null
    text: null
    title: Latest News
  design:
    columns: "1"
    view: card
- block: markdown
  content:
    subtitle: ""
    text: null
    title: null
  design:
    background:
      image:
        filename: coders.jpg
        filters:
          brightness: 1
        parallax: false
        position: center
        size: cover
        text_color_light: true
    columns: "1"
    css_class: fullscreen
    spacing:
      padding:
      - 20px
      - "0"
      - 20px
      - "0"
- block: collection
  content:
    count: 5
    filters:
      folders:
      - publication
      publication_type: article
    text: ""
    title: Latest Preprints
  design:
    columns: "1"
    view: citation
- block: markdown
  content:
    subtitle: null
    text: |
      {{% cta cta_link="./people/" cta_text="Meet the team →" %}}
    title: null
  design:
    columns: "1"
title: null
type: landing
---
