# Recipe 1: A Build

## Ingredients

  * Two terminals in the same directory

## Preparation

In your first terminal:

    $ mkdir r1 && cd r1
    r1 $ git init
    r1 $ echo -e 'output.txt:\n\techo HI > $@' > Makefile
    r1 $ git add Makefile
    r1 $ git commit -m "A wild project appears"

Then in your second terminal:

    $ bt-watch r1

Nothing happens. We can fix that!

Back in your first terminal:

    r1 $ mkdir stages
    r1 $ cat > stages/build <<EOF
    run: make
    results:
      - output.txt
    EOF
    r1 $ git add stages/build
    r1 $ git commit -m "Added a 'build' stage"

Quick, check your second terminal again!

    echo HI > output.txt
    build: PASS bt loves you (ff3f89712c8f8883d7aa75d23baa18de175e20d4) DONE

(Your SHA will be different.)

That was `bt-watch` building your newest commit.

Back to the first terminal:

    r1 $ bt-results
    Results (a2844028d9fa126f09ac55de2b51d05bde4abc46):

    build: PASS bt loves you (ff3f89712c8f8883d7aa75d23baa18de175e20d4)
    r1 $ git show ff3f89712c8f8883d7aa75d23baa18de175e20d4
    commit ff3f89712c8f8883d7aa75d23baa18de175e20d4
    Author: Build Thing <build@thing.invalid>
    Date:   Tue Jul 12 16:17:18 2011 +1000

        PASS bt loves you
        
        echo HI > output.txt

    diff --git a/output.txt b/output.txt
    new file mode 100644
    index 0000000..c1e3b52
    --- /dev/null
    +++ b/output.txt
    @@ -0,0 +1 @@
    +HI

Yes, the `output.txt` has been committed to your respository.
Yes, the console output from `make` is in your commit message.
