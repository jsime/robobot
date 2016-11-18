.. _module-types.vector:

types.vector
************

Provides functions for creating and manipulating vectors of values.

.. _function-types.vector-vec:

vec
===

.. code-block:: none

    (vec [<list>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (vec 1 (seq 5 7) 10)
    [1 5 6 7 10]

Converts a list of values into a vector, returning the vector. If no values are provided, an empty vector is returned.

