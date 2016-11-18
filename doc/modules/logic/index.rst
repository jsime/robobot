.. _module-logic:

logic
*****

Exports logic, bitwise, and boolean functions.

.. _function-logic-and:

and
===

.. code-block:: none

    (and <expression> [<expression> ...])

*Examples:*

.. code-block:: clojure

    (and (> 20 1) (> 40 20))

Returns a true value only if all expressions are also true.

.. _function-logic-not:

not
===

.. code-block:: none

    (not <expression>)

*Examples:*

.. code-block:: clojure

    (not (> 1 20))

Returns the logical negation of the value provided.

.. _function-logic-or:

or
==

.. code-block:: none

    (or <expression> [<expression> ...])

*Examples:*

.. code-block:: clojure

    (or (> 20 1) (> 1 20))

Returns a true value if at least one expression is true.

