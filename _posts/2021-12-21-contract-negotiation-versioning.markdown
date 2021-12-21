---
layout: post
title:  "Contract negotiation and versioning"
cover: assets/images/sebastian-herrmann-NbtIDoFKGO8-unsplash.jpg
navigation: True
tags: [advanced, architecture]
date:   2021-12-21 14:00:00 +0100
class: post-template
author: yeray
comments: true
---

Changing the input or output of an API endpoint that is consumed by your front end, changing a field in a database that is coupled to a field in a model in our application. Sometimes, you see yourself making changes in two different systems and it's really tempting to coordinate the release of both systems to keep them in sync.

What happens if one of the releases needs to be rolled back, though? Especially in a situation where the side working fine has already some other functionality released on top of it.

Enter contract negotiation and versioning.

# Versioning

One way to attack the problem in a API/front-end is to provide a new version of the endpoint.

# Contract negotiation

<span>Photo by <a href="https://unsplash.com/@officestock?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Sebastian Herrmann</a> on <a href="https://unsplash.com/s/photos/contract?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a></span>
