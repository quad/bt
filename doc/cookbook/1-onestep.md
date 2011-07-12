# Recipe 1: A Build

## Ingredients

  * A terminal

I bet you got one laying around your desktop.

## Preparation

 1. We need something to build, to build:

        $ mkdir r1 && cd r1
        r1 $ git init
        r1 $ cat > Rakefile <<EOF
        task :default do
          sh 'echo HI > output.txt'
        end
        EOF
        r1 $ git add Rakefile
        r1 $ git commit -m "A wild project appears"

 1. Time to try out `bt`!

        r1 $ bt-go
        r1 $

    Hmm.

 1. We need to teach `bt` how to do what it does so well:

        r1 $ mkdir stages
        r1 $ cat > stages/build <<EOF
        run: rake --verbose
        results:
          - output.txt
        EOF
        r1 $ git add stages/build
        r1 $ git commit -m "Added a 'build' stage"

 1. OK, for reals, time to try out `bt`!

        r1 $ bt-go
        echo HI > output.txt
        build: PASS bt loves you (b9f7850f9799d6c1ab8e7774b7a10f5e84ba2730)

    That. That was `bt` building your newest commit.

 1. **BEHOLD** the results of your works!

        r1 $ bt-results
        Results (6de54d390d3ab8a88f8ffc2294b5022682b124e0):

        build: PASS bt loves you (b9f7850f9799d6c1ab8e7774b7a10f5e84ba2730)

    Yes, those are real `git` SHAs.

        r1 $ git show b9f7850f9799d6c1ab8e7774b7a10f5e84ba2730
        commit b9f7850f9799d6c1ab8e7774b7a10f5e84ba2730
        Author: Build Thing <build@thing.invalid>
        Date:   Tue Jul 12 16:52:34 2011 +1000

            PASS bt loves you

            echo HI > output.txt

        diff --git a/output.txt b/output.txt
        new file mode 100644
        index 0000000..c1e3b52
        --- /dev/null
        +++ b/output.txt
        @@ -0,0 +1 @@
        +HI

    Yes, `output.txt` has been committed to your respository.
    Yes, the console output from `rake` is in your commit message.
