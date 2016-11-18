.. _module-madlibs:

madlibs
*******

Just like being 6 years old and on a family road trip again.

.. _function-madlibs-create-madlib:

create\-madlib
==============

.. code-block:: none

    (create-madlib <madlib text>)

*Examples:*

.. code-block:: clojure

    (create-madlib "The {noun} decided to {verb} a {noun} before {daily event}.")

Creates a new madlib. The only argument should be the content of the madlib, with placeholders marked between curly-braces.

Placeholder names are completely arbitrary, though they will be displayed to anyone who gets your madlib to fill out. By default, every placeholder will solicit a separate word from the user. If you wish to re-use the same word in multiple places (say, a person's name or some other proper noun), you may add index numbers to your placeholders. Any placeholders with the same index number will re-use the same word.

Regular placeholders appear as::

    {word} {word} {word}

Which would request three separate words from the user.

Indexed placeholders are written::

    {word:0} {word:0} {word:1}

Which would request two words from the user, but the first one would be repeated twice. The sequence of index numbers does not matter, just that they are unique (internally, RoboBot will normalize them to a continuous integer sequence beginning at ``0``, but you needn't actually care about that).

You may mix indexed and non-indexed placeholders in the same madlib text. The non-indexed placeholders will automatically be assigned unique index numbers internally.

When a user requests a madlib to fill out, the order of placeholders is randomized each time. Thus, if your madlib requests three verbs, they may not be filled back into the madlib in the same order each time it is filled out.

.. _function-madlibs-madlib:

madlib
======

.. code-block:: none

    (madlib [<id> <word1> ... <wordN>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,3,5

    (madlib)
    A new madlib has been started for you. Please run the following command somewhere on this network to fill it in:
    (madlib 1 "noun" "verb" "noun" "daily event")
    (madlib 1 "user" "fill out" "super boring madlib" "lunch")
    "The user decided to fill out a super boring madlib before lunch."



.. _function-madlibs-show-madlib:

show\-madlib
============

.. code-block:: none

    (show-madlib [<completed madlib ID>])

Given the ID of a completed madlib (shown when a user fills out their madlib), displays the completed madlib, otherwise picks one at random to display. Only finished madlibs will be shown.

