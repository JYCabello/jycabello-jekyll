---
layout: post
title:  "Doing non-breaking migrations in Entity Framework Core"
cover: assets/images/jan-niclas-aberle-h5ZqVoCDgys-unsplash.jpg
navigation: True
tags: [dot-net, advanced]
date:   2020-12-16 11:00:00 +0100
class: post-template
author: yeray
comments: true
---

So, you're using an Object Relational Mapper of any kind and you have to, let's say, remove a field from one of your models. This is a breaking change, as your contract with the database is going to break. If you have a small project that you can just take down for every release, that's not a big deal, but:

Add an insult by having a CD pipeline that will do a gradual rollout, having two versions of your solution running: One with the field, and one without it.

Insult, meet injury: The migrations are run as part of the pipeline and not the project startup (I will write an article on how to do this bit with EF Core + Azure Pipelines, cause it got some nasty caveats to sort). This step should not have any impact on the complexity of the migration, but it does, as there is the possibility that the migration will run, but the deployment will crash, leaving you out cold in the water.

- This adds a layer of security, by having your app get only limited read/write access to the database instead of the capacity to [drop tables](https://xkcd.com/327/).
- Makes the startup faster, as you know that the database is always in the latest version.

I will present the process with an example in Entity Framework Core, but the idea behind it applies to any technology you use. Even if you don't have a proper ORM, if your database migrations are part of your pipeline, this article is for you. I'm taking for granted that you know how to have a migrations-enabled project and that you know how to generate a new migration.

We'll start with this model:

```cs
public class FruitBasket
{
    public string Banana { get; set; } = string.Empty;

    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int ID { get; set; }

    public string Pear { get; set; } = string.Empty;
    public string Zucchini { get; set; } = string.Empty;
}
```

This model is already part of a migration, it represents a fruit basked with a description of three fruits. The problem comes when you realise a Zucchini is not a fruit, so your first impulse would be to make remove the Zucchini field, but if we do, make a migration and the exiting version tries to insert a record in the database, we will see this in the logs:

Also, if we remove the field but not generate a migration, we will face this:

```log
Microsoft.Data.SqlClient.SqlException
Cannot insert the value NULL into column 'Zucchini', table 'Fruits.dbo.FruitBaskets'; column does not allow nulls. INSERT fails.
```

So, how do we avoid this? First, we need a running version that does not depend on the field whatsoever.

<span>Photo by <a href="https://unsplash.com/@jnaberle?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Jan-Niclas Aberle</a> on <a href="https://unsplash.com/s/photos/migration?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Unsplash</a></span>