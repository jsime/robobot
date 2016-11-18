.. _module-help:

help
****

Provids access to documentation and help-related functions and information for modules, functions, and macros.

.. _function-help-help:

help
====

.. code-block:: none

    (help [ :module <name> | <function> | <macro> ])

*Examples:*

.. code-block:: clojure

    (help)
    (help apply)
    (help :module types.map)

With no arguments, displays general help information about the bot, including instructions on how to access further help.

With the name of a function or a macro (only macros defined on the current network), displays help tailored to the function or macro, including usage details and links to more detailed documentation. In cases where a macro and a function have the same name, the function will always take precedence.

Lastly, module-level help may be displayed by prefacing the name of the module with the symbol ``:module``. Module help displays the full list of exported functions for that module.

