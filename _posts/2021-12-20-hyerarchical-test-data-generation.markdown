---
layout: post
title:  "Hyerarchichal test data generators"
cover: assets/images/edvard-alexander-rolvaag-E75ZuAIpCzo-unsplash.jpg
navigation: True
tags: [dot-net, basic, TDD]
date:   2021-12-20 14:00:00 +0100
class: post-template
author: yeray
comments: true
---

So, you got some massive legacy service methods were mocking your data store is unfeasible or some situation where, for efficiency reasons, it's convenient that your logic is executed in the data store. And you got to write some automated checks to make sure that some of the assumptions you will make on your code are valid. For that, you need real records in a real database.

Thing is, data is complex. You are trying to write some code that works over an order, and the order is related to a customer, a product and a seller. (We will omit every irrelevant field in the entities and have the entities be related exclusively by IDs).

```cs
public class Customer
{
    public int ID { get; set; }
}

public class Product
{
    public int ID { get; set; }
}

public class Seller
{
    public int ID { get; set; }
}

public class Order
{
    public int ID { get; set; }
    public int CustomerID { get; set; }
    public int ProductID { get; set; }
    public int SellerID { get; set; }
}
```

One option is, in order to create every entity, provide all require dependencies (I tend to use static classes for the generators, feel free to break it). I'll write everything as synchronous code to reduce noise. I'm assuming an abstracted away data store
```cs
public static class OrderGenerator
{
    public static Order Generate(Customer customer, Product product, Seller seller)
    {
        var order = new Order 
        {
            CustomerID = customer.ID,
            ProductID = product.ID,
            SellerID = seller.ID
        };
        // I'm assuming this would set the ID on the entity, AKA cutting corners.
        DataStore.Save(order);
        return order;
    }
}
```

This is fine, and consuming it would look like this.
```cs
public class SomeTest
{
    [Fact]
    public void TestSomethingAboutOrders()
    {
        var customer = CustomerGenerator.Generate();
        var product = ProductGenerator.Generate();
        var seller = SellerGenerator.Generate();
        var order = OrderGenerator.Generate(customer, product, seller);
        // ...
    }
}
```

The problem with this, and the reason you are likely reading this, is that as your business logic grows, you will be writing more and more tests and copy pasting these constructs, which will eventually lead to some massive changes when we figure that something in our structure needs to change. Like that for making an order, the seller needs to actually sell the product and have it in stock. Which is perfectly avoidable, as for many of these cases, we just want the default related entities.

It's perfectly fine to stick with this, though, as having these generators become too entangled is usually a signal that your business logic might be a bit too coupled to your data structure and it might be time to move to simplify or even to move to an event driven architecture.

# Introducing Hyerarchical Test Data Generation

This is a pattern I've found useful over the years in order to generate complex entity trees and to be able to switch defaults with ease.
```cs
public static class OrderGenerator
{
    public static OrderSetup Generate(OrderCreation? crt)
    {
        var creation = Fill(crt);
        var order = new Order 
        {
            CustomerID = creation.Customer.ID,
            ProductID = creation.Product.ID,
            SellerID = creation.Seller.ID
        };
        // I'm assuming this would set the ID on the entity, AKA cutting corners.
        DataStore.Save(order);
        return new OrderSetup
        {
            Customer = customer,
            Order = order,
            Product = product,
            Seller = seller
        };
    }

    public static OrderCreationFilled Fill(OrderCreation? crt)
    {
        var creation = crt ?? new OrderCreation();
        var customer = creation.Customer ?? CustomerGenerator.Generate();
        var product = creation.Product ?? ProductGenerator.Generate();
        var seller = creation.Seller ?? SellerGenerator.Generate();

        return new OrderCreationFilled
        {
            Customer = customer,
            Product = product,
            Seller = seller
        };
    }
}

public class OrderCreation
{
    public Customer? Customer { get; init; }
    public Product? Product { get; init; }
    public Seller? Seller { get; init; }
}

public class OrderCreationFilled
{
    public Customer Customer { get; init; }
    public Product Product { get; init; }
    public Seller Seller { get; init; }
}

public class OrderSetup
{
    public Customer Customer { get; init; }
    public Order Order { get; init; }
    public Product Product { get; init; }
    public Seller Seller { get; init; }
}
```

So, in order to create two orders for the same customer but for different products and sellers:
```cs
public class SomeTest
{
    [Fact]
    public void TestSomethingAboutOrders()
    {
        var orderSetup = OrderGenerator.Generate();
        var otherOrderSetup = OrderGenerator.Generate(new OrderCreation { Customer = orderSetup.Customer });
        // ...
    }
}
```

The upside of this is that we can just contain any complexity of relating the data to its parents to the `Fill` and `Create` methods.

It's not a perfect solution and it comes with its own pains and need for discipline, but it has simplified refactoring legacy code for me a great deal. A trade off that was been worth for me in every project I've used it on.

<span>Photo by <a href="https://unsplash.com/@edvardr?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Edvard Alexander Rølvaag</a> on <a href="https://unsplash.com/s/photos/hierarchy?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText">Unsplash</a></span>
