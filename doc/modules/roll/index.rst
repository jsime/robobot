.. _module-roll:

roll
****

Random number generator, including functionality for obtaining numbers in the style of arbitrary-sided dice-rolling.

.. _function-roll-random:

random
======

.. code-block:: none

    (random [<max>])

*Examples:*

.. code-block:: clojure

    (random 10)

Returns a random integer between ``0`` and ``max`` (defaults to 1).

.. _function-roll-roll:

roll
====

.. code-block:: none

    (roll <die size> [<roll count>])

*Examples:*

.. code-block:: clojure

    (roll 20)
    (roll 4 3)

Given a die-size and a number of rolls, returns the summed result of all those rolls. Each roll is effectively a call to ``(random n)`` where ``n`` is your die size.

Assumes a single roll if you don't specify otherwise.

