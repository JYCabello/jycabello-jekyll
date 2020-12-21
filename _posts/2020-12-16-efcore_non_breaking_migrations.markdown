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

I will present the process with an example in Entity Framework Core, but the idea behind it applies to any technology you use. Even if you don't have a proper ORM, if your database migrations are part of your pipeline, this article is for you.

*I'm taking for granted that you know how to have a migrations-enabled project and that you know how to generate a new migration*.

We'll start with this model:

```cs
public class FruitBasket
{
    public string Banana { get; set; } = string.Empty;
    public int ID { get; set; }
    public string Pear { get; set; } = string.Empty;
    public string Zucchini { get; set; } = string.Empty;
}
```

This model is already part of a migration, it represents a fruit basked with a description of three fruits. The problem comes when you realise a Zucchini is not a fruit, so your first impulse would be to remove the Zucchini field:

```cs
public class FruitBasket
{
    public string Banana { get; set; } = string.Empty;
    public int ID { get; set; }
    public string Pear { get; set; } = string.Empty;
}
```

If we do, make a migration and the exiting version tries to read a record from the database, we will see this in the logs:

```log
Microsoft.Data.SqlClient.SqlException
Invalid column name 'Zucchini'.
```

Also, if we remove the field but not generate a migration, we will face this:

```log
Microsoft.Data.SqlClient.SqlException
Cannot insert the value NULL into column 'Zucchini', table 'Fruits.dbo.FruitBaskets'; column does not allow nulls. INSERT fails.
```

So, how do we avoid this? This looks like a chicken-and-egg dilemma, except it does have an answer: Something comes first.

The idea is to make a series of deployments that keep the existing version working while moving us one step forward to the goal.

1. Make the field nullable, handle possible null values and generate no migration. Deploy that version. You are not changing the database, so the previous version will work with no problem, as the assumption that `Zucchini` cannot be `null` remains true. The new version will also work, as the only change is that the system is defensive against a problem that cannot happen.
    ```cs
    public class FruitBasket
    {
        public string Banana { get; set; } = string.Empty;
        public int ID { get; set; }
        public string Pear { get; set; } = string.Empty;
        public string? Zucchini { get; set; } = string.Empty;
    }
    ```
1. Generate a migration and deploy. That makes the column nullable. Code is the same, so both exiting and entering version will work with this database version.
    ```cs
    public partial class NullableZucchini : Migration
    {
        protected override void Down(MigrationBuilder migrationBuilder) =>
            migrationBuilder.AlterColumn<string>(
                "Zucchini",
                "FruitBaskets",
                "nvarchar(max)",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

        protected override void Up(MigrationBuilder migrationBuilder) =>
            migrationBuilder.AlterColumn<string>(
                "Zucchini",
                "FruitBaskets",
                "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");
    }
    ```
1. Remove the field altogether so you are not trying to access the column, no migration. Deploy. The exiting version will still work, as the column exists and is treated as nullable, entering one will ignore the column and inserts will work because the column is nullable.
    ```cs
    public class FruitBasket
    {
        public string Banana { get; set; } = string.Empty;
        public int ID { get; set; }
        public string Pear { get; set; } = string.Empty;
    }
    ```
1. Generate a migration to finally remove the column, deploy and you are done. The exiting version has no reference to the field, so it will work and since the new version has no changes in the code, the entering one will do, too.
    ```cs
    public partial class RemoveZucchini : Migration
    {
        protected override void Down(MigrationBuilder migrationBuilder) =>
            migrationBuilder.AddColumn<string>(
                "Zucchini", 
                "FruitBaskets", 
                "nvarchar(max)", 
                nullable: true);

        protected override void Up(MigrationBuilder migrationBuilder) =>
            migrationBuilder.DropColumn("Zucchini", "FruitBaskets");
    }
    ```
1. Profit.

Same process works on the inverse, if you wanted to introduce a non-nullable field, you would have to take similar steps. Except we would skip one step and we might need to do some data sanitizing in the end.

1. Introduce the field as nullable and generate the migration to introduce the field. Make sure that you don't leave the field out in any insertion.
1. Make the field not nullable, generate a migration with a default value, perhaps a placeholder value if you have to sanitize/seed data later. Try to avoid doing both things in the same step if you can.
1. Do any possible seeding and/or sanitizing, like changing the default values based on the category of the record.

The difficulty with this is that, as developers, backwards compatibility comes naturally to us, as it appears on the wild often, but it's a challenge to think on forward compatibility. Good thing is that we live in an era where most projects that face this kind of challenge have some degree of automated check coverage, so an often effective heuristic is to run your migration locally, checkout the version that doesn't have it and run your suite. Try to be wise about it and do some exploratory testing in the areas of your system that have something to do with the changes at hand.

You can find the sample project [here](https://github.com/JYCabello/ef-examples), I might add some extra migrations on top of it to show relations in another article, mind you. Git history is your ally here.

<span>Photo by <a href="https://unsplash.com/@jnaberle?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Jan-Niclas Aberle</a> on <a href="https://unsplash.com/s/photos/migration?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Unsplash</a></span>