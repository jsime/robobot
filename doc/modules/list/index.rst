.. _module-list:

list
****

Provides functions which generate and operate on lists.

.. _function-list-any:

any
===

.. code-block:: none

    (any <string> <list>)

Returns ``1`` if ``string`` matches any element of ``list``, ``0`` otherwise.

.. _function-list-count:

count
=====

.. code-block:: none

    (count <list>)

Returns the number of elements in the provided list.

.. _function-list-filter:

filter
======

.. code-block:: none

    (filter <function> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (filter (match "a" %) "Jon" "Jane" "Frank" "Zoe")
    ("Jane" "Frank")

Returns a list of elements from the input list which, when aliased to ``%`` and applied to ``function``, result in a true evaluation.

.. _function-list-first:

first
=====

.. code-block:: none

    (first <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (first "James" "Alice" "Frank")
    "James"

Returns the first element of the given list, discarding all remaining elements.

.. _function-list-last:

last
====

.. code-block:: none

    (last <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (last "James" "Alice" "Frank" "Janet")
    "Janet"

Returns the last element of the list, discard all elements preceding it.

.. _function-list-map:

map
===

.. code-block:: none

    (map <function> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (map (* 2 %) (seq 1 5))
    (2 4 6 8 10)

Applies ``function`` to every element of the input list and returns a list of the results, preserving order. Each element of the input list is aliased to ``%`` within the function being applied.

.. _function-list-nth:

nth
===

.. code-block:: none

    (nth <n> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (nth 3 "James" "Alice" "Frank" "Janet")
    "Frank"

Returns the ``n``th entry from the given list. Lists are considered ``1``-indexed and negative numbers count backwards from the end of the list. If ``n`` is larger than the size of the list, no value is returned.

.. _function-list-reduce:

reduce
======

.. code-block:: none

    (reduce <function> <accumulator> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (reduce (* $ %) 1 (seq 1 10))
    3628800

Returns the result of repeatedly applying ``function`` to the ``accumulator``, aliased as ``$``, and each element of the input list, aliased as ``%``.

Reductions may be performed on any type, but you should ensure that you provide an initial value for the accumulator that is appropriate to the function you will be applying. In the example provided, a simple factorial was performed by initializing the accumulator to ``1`` and then applying a continuous sequence of integers beginning at 1 to the product function. It would have made no sense to initialize the accumulator in that example with a string value.

.. _function-list-seq:

seq
===

.. code-block:: none

    (seq <first> <last> <step>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5

    (seq 1 10)
    (1 2 3 4 5 6 7 8 9 10)

    (seq 2 20 2)
    (2 4 6 8 10 12 14 16 18 20)

Generates and returns a list of numeric elements, beginning with the number ``first`` and ending with ``last``. By default, numbers increment by ``1``, but a custom increment may be supplied via ``step``.

.. _function-list-shuffle:

shuffle
=======

.. code-block:: none

    (shuffle <list>)

Returns the full list of elements in a randomized order.

.. _function-list-sort:

sort
====

.. code-block:: none

    (sort <list>)

Returns the full list of elements, sorted.

