.. _module-macro:

macro
*****

Provides functionality for defining and managing macros. Macros defined by this plugin are available to all users in all channels on the current network, and persist across bot restarts.

.. _function-macro-defmacro:

defmacro
========

.. code-block:: none

    (defmacro <macro name> <vector of arguments> <macro body expression>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 3,7

    (defmacro plus-one [a] '(+ a 1))
    (plus-one 5)
    6

    (defmacro grep-for-foo [&rest my-list] '(filter (match "foo" %) my-list))
    (grep-for-foo "foo" "bar" "baz" "food")
    ("foo" "food")

Macros are user-defined functions, and any channel members with permission to call ``(defmacro)`` may define their own macros. Name collisions between macros and builtin functions are always resolved in favor of the functions.

Macro names may contain any valid identifier characters, including many forms of punctuation and Unicode glyphs (as long as your chat network supports their transmission). The primary restrictions on macro names are:

* They cannot begin with a colon ``:`` character (that is reserved for Symbols).

* They cannot contain whitespace.

* They cannot be a valid Numeric (have an optional leading dash, include a decimal separator, and otherwise consist only of numbers).

* They cannot contain a slash ``/`` as that is the function namespace separator.

The macro argument list is a vector of names to which arguments will be bound whenever the macro is invoked. The may be used repeatedly within the macro body, but bear in mind they are replaced during macro expansion with the value of the argument. They are not mutable variables.

Unless otherwise indicated, all macro arguments are considered mandatory, and calling the macro without them will result in an error. To mark arguments as optional, they must follow a ``&optional`` symbol in the argument vector. In addition to optional arguments, you may mark a single argument as the target for all remaining arguments that may have been passed to the macro, after all of the explicit arguments are bound. This is done by placing the name to which they will be bound as a list after the ``&rest`` symbol in the argument vector.

Finally, the macro body expression may be any valid quoted expression and as such may invoke other macros. The names from your argument vector will be available for use within the entire macro body.

.. _function-macro-list-macros:

list\-macros
============

.. code-block:: none

    (list-macros [<pattern>])

Displays a list of all registered macros. Optional pattern will limit list to only those macros whose names match.

.. _function-macro-lock-macro:

lock\-macro
===========

.. code-block:: none

    (lock-macro <macro name>)

Locks a macro from further modification or deletion. This function is only available to the author of the macro.

.. _function-macro-show-macro:

show\-macro
===========

.. code-block:: none

    (show-macro <macro name>)

Displays a macro's definition and who authored it.

.. _function-macro-undefmacro:

undefmacro
==========

.. code-block:: none

    (undefmacro <macro name>)

Undefines the named macro. This is a permanent action and if the named macro is desired again, it must be recreated from scratch.

If the macro has been locked by its author, only they may undefine it. Anyone else attempting to remove the macro will receive an error explaining that it is currently locked.

.. _function-macro-unlock-macro:

unlock\-macro
=============

.. code-block:: none

    (unlock-macro <macro name>)

Unlocks a previously locked macro, allowing it to once again be modified or deleted. This function is only available to the author of the macro.

