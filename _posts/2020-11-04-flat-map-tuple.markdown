---
layout: post
title:  "Flat map tuple - functional patterns"
cover: assets/images/derek-story-Kd7Fdg337Qk-unsplash.jpg
navigation: True
tags: [functional-programming, advanced]
date:   2020-11-04 11:31:13 +0100
class: post-template
author: yeray
comments: true
---

One of the fantastic things about functional programming is that you abstract away the path that took you to the data, mostly with data structures. So when you are processing the `some` state of an `Option`, you know that the object is there. When processing the `right` of an `Either`, you know you have an object that has dodged every error or alternative path. You don't get his benefit for free, as the data structure forces you to handle all of its states, you might see yourself needing three objects, all of them contained in their own instance of such a structure.

I'll follow the process that got me here.

For the examples, I'll go with the `Either` monad and use for C#, [Language-ext](https://github.com/louthy/language-ext) and for Kotlin, [Arrow](https://arrow-kt.io/).

So, let's say we have a insurance system and we want to print a table with the policies that a certain customer has and for that we first need the user details and the customer profile.

These would be the functions getting us the values and the one consuming it.

```cs
public Either<Error, User> GetUser(int id) =>
    new User();

public Either<Error, CustomerProfile> GetProfile(User user) =>
    new CustomerProfile();

public Either<Error, List<Policy>> GetPolicies(CustomerProfile profile) =>
    new List<Policy>();

public Unit Print(User user, CustomerProfile profile, List<Policy> policies)
{
    Console.WriteLine("The actual table");
    return unit;
}

public Unit Print(Error error)
{
    Console.WriteLine("An error");
    return unit;
}
```

```kotlin
fun getUser(id: Int): Either<Error, User> =
    User().right()

fun getProfile(user: User): Either<Error, CustomerProfile> =
    CustomerProfile().right()

fun getPolicies(profile: CustomerProfile): Either<Error, List<Policy>> =
    listOf<Policy>().right()

fun print(user: User, profile: CustomerProfile, policies: List<Policy>): Unit =
    println("The actual table")

fun print(error: Error): Unit =
    println("An error")
```

As you can see, every piece of logic just takes the objects, taking for granted that they are in a valid states an that the program is in a portion of its state that has the objects there.

And I know, the C# bit looks like it got hit in the face by an old boxing champion trying to prove that he still "has it". The syntax is not the reason I like the language. Strap yourselves, though, it gets worse when it's time to actually consume this logic. 

Now onto the ugliness of actually consuming this for user number one:

```cs
public Unit Print() =>
    GetUser(1)
        .Bind(user => GetProfile(user)
            .Bind(profile => GetPolicies(profile)
                .Map(policies => Print(user, profile, policies))
            )
        )
        .BiFold(unit, (s, u) => u, (s, error) => Print(error));
```

```kotlin
fun print(): Unit =
    getUser(1)
        .flatMap { user -> 
            getProfile(user).flatMap { profile -> 
                getPolicies(profile).map { policies -> 
                    print(user, profile, policies) 
                } 
            } 
        }
        .fold(::print, ::identity)
```

_Yikes!_ The Kotlin alternative is definitely cleaner but it's still a proper christmast tree of nested, hard to follow and harder to debug code. Arrow offers us a clean alternative to this, using an `fx` block:

```kotlin
fun printFx(): Unit =
    Either.fx<Error, Unit> {
        val (user) = getUser(1)
        val (profile) = getProfile(user)
        val (policies) = getPolicies(profile)
        print(user, profile, policies)
    }
    .fold(::print, ::identity)
```

Nice. It's like a kitten sleeping on top of cotton. And all the accidental complexity, coming from the possibility of error arising it's contained in the `Either`. Issue is, `fx` blocks encourage implicit information loss, which is one of the big benefits of functional programming. It moves you away from a `fetch, filter, transform, iterate` mindset. Also, they are not available in C# and we still need to do a final fold where the `right` side is just relaying a `unit`. The solution? Tuples:

```cs
public Unit PrintTupled() =>
    GetUser(1)
        .Bind(user => GetProfile(user).Map(profile => (user, profile)))
        .Bind(tuple => GetPolicies(tuple.Item2).Map(policies => (tuple.Item1, tuple.Item2, policies)))
        .BiFold(unit, 
            (s, tuple) => Print(tuple.Item1, tuple.Item2, tuple.Item3), 
            (s, e) => Print(e));
```

```kotlin
fun printTuples(): Unit =
    getUser(1)
        .flatMap { user -> getProfile(user).map { Tuple2(user, it) } }
        .flatMap { (user, profile) -> getPolicies(profile).map { Tuple3(user, profile, it) } }
        .fold(::print, ::print)
```

As you can see, there is a major victory here: You can mock people for not understanding you beautiful abomination.

Also, points to Kotlin for be able to use the `print` function that takes three parameters as if it were taking a tuple.

Besides that, the `fold` is actually folding this time, you are receiving two possible states and handling them instead of passing on the `unit` from the already handled one. You have a separation of the logic fetching the data and the logic actually consuming it.

Still, that tuple construction... even the Kotlin version feels, boilerplater-ish, doesn't it?

Well, the good thing about data structures is that almost all of the structural logic, the accidental complexity, can be abstracted await. `BindTuple/flatMapTuple` to the rescue:

```cs
public static class EitherExtensions
{
    public static Either<TL, (TR, TR2)> BindTuple<TL, TR, TR2>(
        this Either<TL, TR> self,
        Func<TR, Either<TL, TR2>> func
    ) =>
        self.Bind(tr => func(tr).Map(tr2 => (tr, tr2)));

    public static Either<TL, (TR, TR2, TR3)> BindTuple<TL, TR, TR2, TR3>(
        this Either<TL, (TR, TR2)> self,
        Func<(TR, TR2), Either<TL, TR3>> func
    ) =>
        self.Bind(t => func(t).Map(tr2 => (t.Item1, t.Item2, tr2)));
}

public Unit PrintBindTupled() =>
    GetUser(1)
        .BindTuple(GetProfile)
        .BindTuple(tuple => GetPolicies(tuple.Item2))
        .BiFold(unit, 
            (s, tuple) => Print(tuple.Item1, tuple.Item2, tuple.Item3), 
            (s, e) => Print(e));
```

```kotlin
fun <L, R, R2> Either<L, R>.flatMapTuple(
    fn: (R) -> Either<L, R2>
): Either<L, Tuple2<R, R2>> =
    this.flatMap { r -> fn(r).map { Tuple2(r, it) } }

// The JVM is not able to tell apart overloads when the difference in parameters are function types.
@JvmName("flatMapTuple2")
fun <L, R, R2, R3> Either<L, Tuple2<R, R2>>.flatMapTuple(
    fn: (Tuple2<R, R2>) -> Either<L, R3>
): Either<L, Tuple3<R, R2, R3>> =
    this.flatMap { tuple -> fn(tuple).map { Tuple3(tuple.a, tuple.b, it) } }

fun printFlatMapTuple(): Unit =
    getUser(1)
        .flatMapTuple(::getProfile)
        .flatMapTuple { (_, profile) -> getPolicies(profile) }
        .fold(::print, ::print)
```

As you can see, this leads to code that is exclusively doing business logic: fetching, filtering, transforming and iterating. All accidental complexity is in functions that will be usable no matter the type

<span>Header photo by <a href="https://unsplash.com/@derekstory?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Derek Story</a> on <a href="https://unsplash.com/s/photos/train?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText">Unsplash</a></span>