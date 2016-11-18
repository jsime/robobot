.. _module-spellcheck:

spellcheck
**********

Randomly and annoyingly corrects (often mistakenly) spelling of other channel members. You will disable this plugin soon enough.

.. _function-spellcheck-forget:

forget
======

.. code-block:: none

    (forget <word> [<word> ...])

*Examples:*

.. code-block:: clojure

    (forget Automtomatromaton)

Remove words from the local dictionary. Does not affect words in the global system dictionary.

.. _function-spellcheck-remember:

remember
========

.. code-block:: none

    (remember <word> [<word> ...])

*Examples:*

.. code-block:: clojure

    (remember Automtomatromaton)

Add words to the local dictionary to avoid correcting their spelling in future messages.

