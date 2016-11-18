.. _module-factoid:

factoid
*******

Exports functions for managing small snippets of keyword-based knowledge.

In addition to the exported functions, this module inserts a pre-hook which inspects all messages for keywords which match the stored factoids. Messages in the general format of a question which contain matching keywords trigger an automatic response from the bot with the stored factoid.

.. _function-factoid-add-factoid:

add\-factoid
============

.. code-block:: none

    (add-factoid <factoid name> "<description>")

*Examples:*

.. code-block:: clojure

    (add-factoid perl "A language which looks the same before and after encryption.")

Creates a new factoid of ``name`` on the current network with the given description. Descriptions are limited only by the restrictions of the current network.

.. _function-factoid-remove-factoid:

remove\-factoid
===============

.. code-block:: none

    (remove-factoid <factoid name>)

*Examples:*

.. code-block:: clojure

    (remove-factoid perl)

Removes the named factoid.

.. _function-factoid-update-factoid:

update\-factoid
===============

.. code-block:: none

    (update-factoid <factoid name> "<new description>")

*Examples:*

.. code-block:: clojure

    (update-factoid perl "A fine and upstanding member of the interpreted languages ecosystem.")

Updates the description of the named factoid.

