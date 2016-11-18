.. _module-core:

core
****

Provides a limited set of special form functions for core syntax and language features.

.. _function-core-let:

let
===

.. code-block:: none

    (let <vector of scoped variables> <list|expression> [<list|expression> ...])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5

    (let [two (+ 1 1)] (* two 4))
    8

    (let [two (+ 1 1)] (let [four (* two two)] (* two four)))
    8

Creates a new scope with one or more variables (as defined in the mandatory vector) and then evaluates all child forms within that scope. Masking is supported, in that conflicting variable names from the outer scope will have their values restored when the scope created by this form is terminated. The return value of this function is that of the last child form evaluated.

The vector of variables must contain an even number of elements. Each pair of elements defines the name of the variable and its value, respectively. The value may be a literal string or numeric, or may be any other valid type or expression which yields a value.

Values are evaluated and bound to the variable at the time of scope initialization and are available for use for the remainder of the scope, including any inner scopes.

