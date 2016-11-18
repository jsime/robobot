.. _module-fakequote:

fakequote
*********

Constructs fake quotes from (fictional?) personalities, based on pre-canned phrases and randomized substitutions.

.. _function-fakequote-add-fake-personality:

add\-fake\-personality
======================

.. code-block:: none

    (add-fake-personality <personality name>)

*Examples:*

.. code-block:: clojure

    (add-fake-personality joe)

Adds a new fake personality with the given name.

New personalities have no phrases and will generate no quotes until at least one has been added with ``(add-fake-quote)``.

.. _function-fakequote-add-fake-quote:

add\-fake\-quote
================

.. code-block:: none

    (add-fake-quote <personality name> <phrase>)

*Examples:*

.. code-block:: clojure

    (add-fake-quote joe "I like {food}!")

Adds a fake quote phrase to the given personality, optionally including placeholders to use for randomized substitutions.

Placeholders take the form of an identifier inside curly braces, such as ``{verb}``. Any time a fake quote is being generated, placeholders are looked for and replaced with a random term of the type specified. There are no forced restrictions on the names for placeholders, other than they cannot contain curly braces.

.. _function-fakequote-add-fake-substitution:

add\-fake\-substitution
=======================

.. code-block:: none

    (add-fake-substitution <personality name> <type> <term> [<term> ...])

*Examples:*

.. code-block:: clojure

    (add-fake-substitution joe food "pizza" "ice cream cones" "hard gravel")

Adds a term to the list of possible substitutions when generating phrases for the name personality.

The ``type`` should match the string used when including placeholders in ``(add-fake-quote)`` phrases. Multiple terms may be specified, as long as they are all for the same ``type``.

.. _function-fakequote-fake-quote:

fake\-quote
===========

.. code-block:: none

    (fake-quote [<personality> [<pattern>]])

*Examples:*

.. code-block:: clojure

    (fake-quote)
    (fake-quote joe)

Generates a fake quote either by the personality specified, otherwise by one chosen at random.

