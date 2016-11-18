.. _module-compare:

compare
*******

Exports functions for performing various types of vaue comparisons.

.. _function-compare-!=:

!\=
===

.. code-block:: none

    (!= <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (!= 0.1 1.0)

Numeric inequality test. Returns 1 if both operands are different numbers, 0 otherwise.

.. _function-compare-<:

<
=

.. code-block:: none

    (< <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (< 1 2)

Numeric less-than test. Returns 1 if ``a`` is less than ``b``, 0 otherwise.

.. _function-compare-==:

\=\=
====

.. code-block:: none

    (== <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (== 1 1.0000000)

Numeric equality test. Returns 1 if both operands the same numerically, 0 otherwise.

.. _function-compare->:

>
=

.. code-block:: none

    (> <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (> 50 10)

Numeric greater-than test. Returns 1 if ``a`` is greater than ``b``, 0 otherwise.

.. _function-compare-cmp:

cmp
===

.. code-block:: none

    (cmp <operand a> <operand b>)

String comparison. Returns -1 if ``a`` collates before ``b``, 1 if ``b`` collates first, and 0 if they are equal. Collation uses the locale under which the bot is running.

.. _function-compare-eq:

eq
==

.. code-block:: none

    (eq <operand> <operand>)

String equality test. Returns 1 if both operands are the same in a string context, 0 if they are not.

.. _function-compare-gt:

gt
==

.. code-block:: none

    (gt <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (gt "zyx" "abc")

String ordinality test. Returns 1 if ``a`` sorts after ``b`` according to the collation rules of the locale in which the bot is running. Returns 0 otherwise.

.. _function-compare-lt:

lt
==

.. code-block:: none

    (lt <operand a> <operand b>)

*Examples:*

.. code-block:: clojure

    (lt "abc" "def")

String ordinality test. Returns 1 if ``a`` sorts before ``b`` according to the collation rules of the locale in which the bot is running. Returns 0 otherwise.

.. _function-compare-ne:

ne
==

.. code-block:: none

    (ne <operand a> <operand b>)

String inequaity test. Returns 1 if both operands are different in a string context, 0 otherwise.

