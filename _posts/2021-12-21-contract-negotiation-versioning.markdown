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

One way to attack the problem is to provide a new version of the contract while maintaining the current one. This is not about API versioning as it is known, where you release a new version of your public facing API while the previous one is still active, but just about introducing a copy of the endpoint as a transition measure while you update a contract within different moving parts of your system that are deployed independently, be it microservices or background workers.

# Contract negotiation

A problem to solve:

We've found that using decimals for monetary fields causes some rounding problems, in order to keep consistency, we will start sending the field as an integer representing cents:
```cs
// From
public class Product
{
    public decimal Price { get; set; }
    // Other fields ommited for brevity.
}

// To
public class Product
{
    public int Price { get; set; }
    // Other fields ommited for brevity.
}
```

Since you are already in the mindset of looking for trouble in out-of-sync contracts, you probably see the two possible issues with rolling back one of the sides of this contract:
1. When rolling back the client side, a product costing ten euros will be translated as a thousand euros (`(int)1000 => (decimal)1000.00`).
1. When rolling back server side, a product costing ten euros will be translated as ten cents (`(decimal)10.00 => (int)10`).

## Forward and backwards compatibility

In order to prevent this, we version the endpoint and we have the server maintain both versions of it. So clients calling the old endpoint will still work. I will not include code examples of it due to its trivial nature.

On the client side, we follow the pattern that gives the name to this article, we "negotiate" with the server.

I'll write it in an imperative and synchronous way to reduce noise.
```cs
// Client side code
public class Product
{
    public int Price { get; set; }
    // Other fields ommited for brevity.
}

public class ProductLegacy
{
    public decimal Price { get; set; }
    // Other fields ommited for brevity.
}

public Product Get(int id)
{
    try
    {
        return GetWithCents(id);
    }
    catch (EndpointNotFoundException)
    {
        var legacy = GetLegacy(id);
        return new Product
        {
            Price = ConvertDecimalMoneyToCents(legacy.Price)
            // Other fields ommited for brevity.
        };
    }
}
```

An alternative is to indroduce another field in the product, which is not strictly versioning, but leverages the same principle.
```cs
// Server side
public class Product
{
    public decimal Price { get; set; }
    public int PriceCents { get; set; }
    // Other fields ommited for brevity.
}

// Client side
public class ProductDto
{
    public decimal Price { get; set; }
    public int? PriceCents { get; set; }
    // Other fields ommited for brevity.
}

public class Product
{
    public int Price { get; set; }
}

public Product Get(int id)
{
    var dto = GetProduct(id);
    return new Product
    {
        Price = dto.PriceCents ?? ConvertDecimalMoneyToCents(legacy.Price)
        // Other fields ommited for brevity.
    };
}
```

[Non breaking migrations]({% post_url 2020-12-16-efcore_non_breaking_migrations %}) is just a subset of this practice, reminding us once again that we often need to think on our database as just another subsystem in our solution.

If you do event sourcing, you'll find that doing non breaking migrations is as simple as just starting a new table for the new model, making contract negotiation as trivial as it gets.

<span>Photo by <a href="https://unsplash.com/@officestock?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Sebastian Herrmann</a> on <a href="https://unsplash.com/s/photos/contract?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a></span>
