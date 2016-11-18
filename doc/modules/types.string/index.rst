.. _module-types.string:

types.string
************

Provides functions for creating and manipulating string-like values.

.. _function-types.string-index:

index
=====

.. code-block:: none

    (index <str> <match>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5

    (index "The quick brown fox ..." "fox")
    (16)

    (index "The quick brown fox ..." "o")
    (12 17)

Returns the starting position(s) in a list of all occurrences of the substring ``match`` in ``str``. If ``match`` does not exist anywhere in ``str`` then an empty list is returned.

.. _function-types.string-index-n:

index\-n
========

.. code-block:: none

    (index-n)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (index-n "This string has three occurrences of the substring \"str\" in it." "str" 2)
    44

Returns the nth (from 1) starting position of the substring ``match`` in ``str``.

If there are no occurrences of ``match`` in ``str``, or there are less than ``n``, nothing is returned.

.. _function-types.string-substring:

substring
=========

.. code-block:: none

    (substring <str> <position> [<n>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (substring "The quick brown fox ..." 4 5)
    "quick"

Returns ``n`` characters from ``str`` beginning at ``position`` (first character in a string is ``0``).

Without ``n`` will return from ``position`` to the end of the original string.

A negative value for ``n`` will return from ``position`` until ``|n| - 1`` characters prior to the end of the string (``n = -1`` would have the same effect as omitting ``n``).

