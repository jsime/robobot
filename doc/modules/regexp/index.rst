.. _module-regexp:

regexp
******

Regular expression matching and substitution functions.

.. _function-regexp-match:

match
=====

.. code-block:: none

    (match <pattern> <text>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (match "\d+" "The year 2014 saw precisely 10 things happen.")
    ("2014" "10")

Returns a list of matches from the given text for the supplied pattern. PCRE modifiers ``/ig`` are implied.

.. _function-regexp-replace:

replace
=======

.. code-block:: none

    (replace <pattern> <replacement> <text>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (replace "hundred" "billion" "You have won a hundred dollars!")
    "You have won a billion dollars!"

Replaces any matches of pattern in the given text with the given string. PCRE modifiers ``/ig`` are implied.

