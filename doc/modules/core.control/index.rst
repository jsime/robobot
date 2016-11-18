.. _module-core.control:

core.control
************

Exports a selection of control structure functions and special forms.

Most of these functions and forms operate on the principle of "truthiness" which may not be self-evident to users of languages that have strict concepts of ``True`` and ``False`` (and sometimes nil/null/etc.). RoboBot follows the somewhat more expansive concept of truthiness that the Perl language uses, in which anything that isn't a negative number, the literal number ``0``, undefined, an empty string, or a string of nothing but a single zero character is considered to be true. Thus, an empty Map would be true; a String containing two or more zeroes but nothing else would be true; even the String ``"false"`` would be true. But a comparison operator that returns the numeric ``0``, or a string with a single zero character, or a ``nil`` would be false.

.. _function-core.control-apply:

apply
=====

.. code-block:: none

    (apply <function> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (apply + (seq 1 5))
    (2 3 4 5 6)

Repeatedly applies the function to each element of the list, in the order provided by the list, returning a new list of the results.

.. _function-core.control-cond:

cond
====

.. code-block:: none

    (cond <condition> <expression> [<condition> <expression> ...] [<fallback>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 4,9,14

    (cond
      (== 1 2) "No way this gets evaluated."
      (> 10 5) "Ten is a bigger number than five.")
    "Ten is a bigger number than five."

    (cond
      (eq "foo" "bar") "Inequal strings. This won't happen."
      (print "Fallback expression being evaluated."))
    "Fallback expression being evaluated."

    (cond
      (!= 1 2) "These are indeed different numbers!"
      (!= 3 4) "We never get this far, because the first condition was true.")
    "These are indeed different numbers!"

Similar to ``if``, this form evaluates a condition and if it yields a truthy value, evluates the expression immediately following the condition. Unlike ``if``, this form accepts an arbitrary number of condition-expression pairs. The first pair whose condition is true will have its expression evaluated and the ``cond`` form will terminate without any further evaluations.

If none of the conditions from the pairs yields a truthy value, and there are an odd number of operands provided, the last one will be used as a default expression to evaluate and its value will be returned by ``cond`` instead.

The return value of the ``cond`` is that of the single expression which was evaluated.

.. _function-core.control-if:

if
==

.. code-block:: none

    (if <condition> <true expression> [<false expression>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (if (< 1 2) "One is less than two." "This will never evaluate.")
    "One is less than two."

Evaluates the given condition, which if truthy leads to the evaluation of the ``<true expression>``. If the condition did not yield a truthy value and a third operand is present, that is evaluated instead.

Neither of the true or false expressions need to be quoted to prevent their initial evaluation, as this is a special form. Only one of the expressions will ever be evaluated on any invocation of the ``if`` form.

.. _function-core.control-repeat:

repeat
======

.. code-block:: none

    (repeat <count> <list|expression>)

*Examples:*

.. code-block:: clojure

    (repeat 3 (upper "foo"))

Repeats the evaluation of the given list/expression ``count`` times, returning a list of all the results.

.. _function-core.control-while:

while
=====

.. code-block:: none

    (while <condition> <expression>)

*Examples:*

.. code-block:: clojure

    (while (< 5 (random 10)) (print "Rolled over 5."))

Evaluates the given condition repeatedly, evaluating the expression each time that the condition is true. Completes only when the condition eventualy returns a false value (or the internal loop limit is reached).

Note that is the condition has side-effects, they will occur on every single iteration until the ``while`` itself terminates.

