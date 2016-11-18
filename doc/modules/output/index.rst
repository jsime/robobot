.. _module-output:

output
******

Provides string formatting and output/display functions.

.. _function-output-clear:

clear
=====

.. code-block:: none

    (clear)

Clears current contents of the output buffer without displaying them.

This applies only to normal output - error messages will still be dispayed to the user should occur.

.. _function-output-format:

format
======

.. code-block:: none

    (format <format string> [<list>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (format "Random number: %d" (random 100))
    "Random number: 42"

Provides a printf-like string formatter. Placeholders follow the same rules as printf(1).

.. _function-output-format-number:

format\-number
==============

.. code-block:: none

    (format-number <number> [<precision> [<trailing zeroes>]])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5,8

    (format-number 12398123)
    "12,398,123"

    (format-number 3.1459 2)
    "3.14"

    (format-number 5 4 1)
    "5.0000"

Provides numeric formatting for thousands separators, fixed precisions, and trailing zeroes.

By default, numbers are formatted only with thousands separators added. Any decimal places in the original number are preserved without any change in precision.

By specifying a precision only, any decimal places will be truncated to that as a maximum precision. The decimal places will not, however, be padded out with zeroes unless a positive integer (anything > 0) is passed as the third operand.

.. _function-output-join:

join
====

.. code-block:: none

    (join <delimiter string> <list>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (join ", " (seq 1 10))
    "1, 2, 3, 4, 5, 6, 7, 8, 9, 10"

Joins together arguments into a single string, using the first argument as the delimiter.

.. _function-output-lower:

lower
=====

.. code-block:: none

    (lower <string>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (lower "Foo Bar Baz")
    "foo bar baz"

Converts the given string to lower-case.

.. _function-output-print:

print
=====

.. code-block:: none

    (print <value> [<value> ...])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5

    (print "foo")
    "foo"

    (print foo 123 "bar" 456)
    ("foo" 123 "bar" 456)

Prints input arguments. If one argument is given, it is echoed unaltered. If multiple arguments are given they are printed in array notation.

.. _function-output-split:

split
=====

.. code-block:: none

    (split <delimiter> <string>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    "[,\s]+" "1, 2, 3,4,    5"
    (1 2 3 4 5)

Splits a string into a list based on the delimiter provided. Delimiters may be a regular expression or fixed string.

.. _function-output-str:

str
===

.. code-block:: none

    (str [<list>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,5,8

    (str)
    ""

    (str "foo")
    "foo"

    (str foo 123 "bar" 456)
    "foo123bar456"

Returns a single string, either a simple concatenation of all arguments, or an empty string when no argument are given.

.. _function-output-upper:

upper
=====

.. code-block:: none

    (upper <string>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (lower "Foo Bar Baz")
    "FOO BAR BAZ"

Converts the given string to upper-case.

