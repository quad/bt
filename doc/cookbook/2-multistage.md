# Recipe 2: A Multi-Stage Build. 

For our next dish, we'll prepare an rspec burrito with a dash of cucumber guacamole. 

## Ingredients

  * A terminal
  * Ruby 1.9.2
    * rspec
    * cucumber

## Preparation

First we need a new project:

        $ mkdir -p burrito/spec 
        $ cd burrito 
        $ git init

And of course, any project needs some files. Using your favorite editor open up `burrito.rb`:

```ruby
class Burrito 
  attr_reader :ingredients

  def add(ingredient)
    @ingredients ||= []
    @ingredients << ingredient
  end
end
```

And do the same for `spec/burrito_spec.rb`:

```ruby
require "./burrito"

describe Burrito do
  let(:burrito) { Burrito.new }

  describe "#add" do
    it "should add a single ingredient to a delicious list" do
      burrito.add "cilantro"
      burrito.ingredients.should include "cilantro"
    end

    it "should add multiple ingredients to a delicious list" do
      burrito.add "cilantro"
      burrito.add "queso"

      burrito.ingredients.should include "cilantro"
      burrito.ingredients.should include "queso"
    end
  end
end
```

Now that some files have been added, let's go ahead and commit them.

        $ git add .
        $ git commit -m "Start the delicious burrito project"

Yay! Our delicious burrito project is underway. Now we've gotta get our `bt` chefs to start cooking those delicious burritos.

To do that, we'll create a `bt` build stage that runs our spec files. The stage won't produce any files and it doesn't rely on any other stages, so it only needs to know what to run.

        $ mkdir stages
        $ echo 'run: rspec spec' > stages/rspecs
        $ git add stages
        $ git commit -m "Added the 'rspecs' stage"
        $ bt-go
        ..

        Finished in 0.00104 seconds
        2 examples, 0 failures
        rspecs: PASS bt loves you (f60c4ca0461dc2a96673fb9252da8a32b1472cc6)

Awesome-sauce (¡que linda salsa!) Our build work and it commited the output of the rspec command as the commit message.

We still need to add that cucumber guacamole that we promised, though. First we'll add the cukes themselves. Let's create the `features` directory and put an acceptance test in it.

        $ mkdir features

edit a simple feature file `features/burrito_cooking_101.feature`:

```ruby
Feature: Burrito building
  In order to build a more perfect burrito
  As a burrito consumer
  I want to add delicious ingredients

  Scenario: Add ingredients
    Given I have a burrito
    When I add "cucumber guacamole" to it
    Then the burrito should have "cucumber guacamole" in it
```

Create a steps file `features/burrito_cooking_101_steps.rb`:

```ruby
require './burrito'

Given /^I have a burrito$/ do
  @burrito = Burrito.new
end

When /^I add "([^"]*)" to it$/ do |ingredient|
  @burrito.add(ingredient)
end

Then /^the burrito should have "([^"]*)" in it$/ do |ingredient|
  @burrito.ingredients.should include ingredient
end
```

Commit everything

        $ git add features
        $ git commit -m "Adding cukes to the kitchen"

Nearly there, we need to add a new stage to the build. This is done by simply adding another file to the stages directory. 

 The names of stages are (by default) simply the file name of that stage. In this case there's `stages/rspecs` and we'd prefer not to execute our acceptance tests unless our specs pass. That's simple enough to do:

        $ cat > stages/cukes <<EOF
        needs: 
        - rspecs
        run: cucumber
        EOF
        $ git add stages/cukes
        $ git commit -m "Added the 'cukes' stage"
        $ bt-go
        ..

        Finished in 0.00105 seconds
        2 examples, 0 failures
        rspecs: PASS bt loves you (11d0b0fe0ad327376293c24c4f18a37c17b8ef97)
        Feature: Burrito building
          In order to build a more perfect burrito
          As a burrito consumer
          I want to add delicious ingredients

          Scenario: Add ingredients                                 # features/burrito_cooking_101.feature:6
            Given I have a burrito                                  # features/burrito_cooking_101_steps.rb:3
            When I add "cucumber guacamole" to it                   # features/burrito_cooking_101_steps.rb:7
            Then the burrito should have "cucumber guacamole" in it # features/burrito_cooking_101_steps.rb:11

        1 scenario (1 passed)
        3 steps (3 passed)
        0m0.002s
        cukes: PASS bt loves you (abc584d900f18f96d40e61df99c9a6482b69a012)

So what happens when a stage fails?

Edit `burrito.rb` so that our specs start failing...

```ruby
class Burrito 
  attr_reader :ingredients

  def add(ingredient)
    @ingredients ||= []
    @ingredients << "cilantro" # Sólo el cilantro es importante !!!11one 
  end
end
```

        $ git commit -a -m "Nom nom nom nom -- Evil Dr. Salazar"
        $ bt-go
        .F

        Failures:

          1) Burrito#add should add multiple ingredients to a delicious list
             Failure/Error: burrito.ingredients.should include "queso"
               expected ["cilantro", "cilantro"] to include "queso"
               Diff:
               @@ -1,2 +1,2 @@
               -queso
               +["cilantro", "cilantro"]
             # ./spec/burrito_spec.rb:16:in `block (3 levels) in <top (required)>'

        Finished in 0.00157 seconds
        2 examples, 1 failure
        rspecs: FAIL bt loves you (0637d88b74adb9ce9d2bf5d0d04977c9a12452af)

Notice that `bt` still created a commit for the failure, but it didn't try to run the cukes stage. We can try to run it manually...

        $ bt-go --stage cukes
        bin/bt-go:40:in `<top (required)>': 8a65d143693c812fd0be759a75202555724693e3/cukes is not ready, it's blocked by rspecs (RuntimeError)
            from bin/bt-go:19:in `load'
            from bin/bt-go:19:in `<main>'

But, of course, it requires the rspecs step to have finished successfully and so it won't run.

## What's Next?

Dynamically stages.
