---
layout: post
title:  "Many-to-many relationships in Entity Framework Core 5 and 3"
cover: assets/images/sebastien-goldberg-unsplash.jpg
navigation: True
tags: [dot-net, basic]
date:   2020-12-16 11:00:00 +0100
class: post-template
author: yeray
comments: true
---

Scenario is quite simple, you got two tables and you have to stablish a relation between both. Be it fruit baskets and basket makers. One maker can make many baskets and they can also collaborate, having a basket be made by different people.

In raw SQL we do that with an intermediate table that represents the connection between both, an likewise we will do the same in Entity Framework Core, with some helpful additional abstraction in version 5.

*I will obviate nullability in the examples, to avoid distractions when it comes to defaulting or null management. Also, the entities have no fields beyond their ID.*

Hands on, this is what we will end up having in our SQL schema.

- A table called `FruitBaskets`.
- Another table called `BasketMakers`.
- An intermediate table calle `FruitBasketBasketMaker` or `BasketMakerFruitBasket` (doesn't really matter which, we'll go with the latter).

These are the entities:

```cs
public class BasketMaker
{
    public int ID { get; set; }
}

public class FruitBasket
{
    public int ID { get; set; }
}
```

# Entity Framework 3

Without support to abstract many-to-many relations away, we have to manually add an intermediate entity that will handle the relation, that would be:

```cs
public class BasketMakerFruitBasket
{
    public BasketMaker BasketMaker { get; set; }
    public int BasketMakersID { get; set; }
    public FruitBasket FruitBasket { get; set; }
    public int FruitBasketsID { get; set; }
}
```

Also, the relation has to be made explicit in the entities themselves:

```cs
public class BasketMaker
{
    public int ID { get; set; }
    public ICollection<BasketMakerFruitBasket> BasketMakerFruitBaskets { get; set; }
}

public class FruitBasket
{
    public int ID { get; set; }
    public ICollection<BasketMakerFruitBasket> BasketMakerFruitBaskets { get; set; }
}
```

One would think that that's enough, but we really need to make the DBContext aware of it, too:

```cs
public class FruitsDbContext : DbContext
{
    private const string ConnectionString =
        "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=Fruits;Integrated Security=True";

    public DbSet<FruitBasket> FruitBaskets =>
        Set<FruitBasket>();

    public DbSet<BasketMakerFruitBasket> BasketMakerFruitBasket =>
        Set<BasketMakerFruitBasket>();

    public DbSet<BasketMaker> BasketMakers =>
        Set<BasketMaker>();

    // This is the bit you're looking for:
    protected override void OnModelCreating(ModelBuilder modelBuilder) =>
        modelBuilder.Entity<BasketMakerFruitBasket>(entity =>
            {
                // A combined key, made of the other two entities' keys.
                entity.HasKey(oc => new { BasketMakersID, FruitBasketsID });
                // The reference to the basket maker.
                entity.HasOne<BasketMaker>(oc => oc.BasketMaker)
                    .WithMany()
                    .OnDelete(DeleteBehavior.NoAction);
                // The reference to the basket itself.
                entity.HasOne<FruitBasket>(oc => oc.FruitBasket)
                    .WithMany()
                    .OnDelete(DeleteBehavior.NoAction);
            });

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder) =>
        optionsBuilder.UseSqlServer(new SqlConnection { ConnectionString = ConnectionString });
}
```

Done with a tad of boilerplate, we generate the migration `MakersMakeBaskets`, that would look like this. Heavy, but the machine does it for us, no big deal:
```cs
public partial class MakersMakeBaskets : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "BasketMakerFruitBasket",
            columns: table => new
            {
                BasketMakersID = table.Column<int>(type: "int", nullable: false),
                FruitBasketsID = table.Column<int>(type: "int", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_BasketMakerFruitBasket", x => new { x.BasketMakersID, x.FruitBasketsID });
                table.ForeignKey(
                    name: "FK_BasketMakerFruitBasket_BasketMakers_BasketMakersID",
                    column: x => x.BasketMakersID,
                    principalTable: "BasketMakers",
                    principalColumn: "ID",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_BasketMakerFruitBasket_FruitBaskets_FruitBasketsID",
                    column: x => x.FruitBasketsID,
                    principalTable: "FruitBaskets",
                    principalColumn: "ID",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_BasketMakerFruitBasket_FruitBasketsID",
            table: "BasketMakerFruitBasket",
            column: "FruitBasketsID");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "BasketMakerFruitBasket");
        migrationBuilder.DropTable(name: "BasketMakers");
    }
}
```

And that's it, now we can query our database to get all Baskets made by Maker number 3. Note that the query gets a bit convoluted, too:

```cs
await using var db = new FruitsDbContext();
var baskets = await db.BasketMakers
    .Include(bm => bm.BasketMakerFruitBaskets)
    .ThenInclude(bmfm => bmfm.FruitBasket)
    .Where(bm => bm.ID == 3)
    .Select(bm => bm.BasketMakerFruitBaskets.Select(bmfm => bmfm.FruitBasket))
    .ToListAsync();
```

# Entity Framework 5

You're in for a treat, this is the process to do the same in EF5 starting with the same entities:

```cs
public class BasketMaker
{
    public int ID { get; set; }
}

public class FruitBasket
{
    public int ID { get; set; }
}
```

Add the relations:


```cs
public class BasketMaker
{
    public int ID { get; set; }
    public ICollection<FruitBasket> FruitBaskets { get; set; }
}

public class FruitBasket
{
    public int ID { get; set; }
    public ICollection<BasketMaker> BasketMakers { get; set; }
}
```

Generate the migration `MakersMakeBaskets`, note that it looks the same, Entity Framework 5 has abstracted all of the intermediate table complexities:

```cs
public partial class MakersMakeBaskets : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "BasketMakerFruitBasket",
            columns: table => new
            {
                BasketMakersID = table.Column<int>(type: "int", nullable: false),
                FruitBasketsID = table.Column<int>(type: "int", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_BasketMakerFruitBasket", x => new { x.BasketMakersID, x.FruitBasketsID });
                table.ForeignKey(
                    name: "FK_BasketMakerFruitBasket_BasketMakers_BasketMakersID",
                    column: x => x.BasketMakersID,
                    principalTable: "BasketMakers",
                    principalColumn: "ID",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_BasketMakerFruitBasket_FruitBaskets_FruitBasketsID",
                    column: x => x.FruitBasketsID,
                    principalTable: "FruitBaskets",
                    principalColumn: "ID",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_BasketMakerFruitBasket_FruitBasketsID",
            table: "BasketMakerFruitBasket",
            column: "FruitBasketsID");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "BasketMakerFruitBasket");
        migrationBuilder.DropTable(name: "BasketMakers");
    }
}
```

Profit. Even the queries are quite cleaner:

```cs
await using var db = new FruitsDbContext();
var baskets = await db.BasketMakers
    .Include(bm => bm.FruitBaskets)
    .Where(bm => bm.ID == 3)
    .Select(bm => bm.FruitBaskets)
    .ToListAsync();
```

Hooray for the people behind [Entity Framework Core](https://github.com/dotnet/efcore), make sure to drop there and leave a star.

<span>Photo by <a href="https://unsplash.com/@sebastiengoldberg?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Sébastien Goldberg</a> on <a href="https://unsplash.com/s/photos/migration?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Unsplash</a></span>