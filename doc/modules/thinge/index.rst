.. _module-thinge:

thinge
******

Provides generalized functions for saving, recalling, and tagging links, funny cat pictures, quotes, or practically anything else that can be put into a chat message.

The type of a thinge is arbitrary, and whenever a new thinge is added with a type that is not yet known, that type is created automatically.

.. _function-thinge-thinge:

thinge
======

.. code-block:: none

    (thinge <type> [<id> | <tag>])

Returns a specific thinge (when the ``id`` is given), a random thinge with a particular tag (when ``tag`` is given), or a random thinge of ``type`` from the collection (when only ``type`` is provided).

.. _function-thinge-thinge-add:

thinge\-add
===========

.. code-block:: none

    (thinge-add <type> <text>)

Saves a thinge to the collection and reports its ID. If there is no ``type`` yet, it is created automatically and a new ID sequence is started for it.

.. _function-thinge-thinge-delete:

thinge\-delete
==============

.. code-block:: none

    (thinge-delete <type> <id>)

Removes the specified thinge from the collection.

.. _function-thinge-thinge-find:

thinge\-find
============

.. code-block:: none

    (thinge-find <type> <pattern>)

Searches through the thinges of a given type for any containing ``pattern``. Patterns may be simple strings or regular expressions.

.. _function-thinge-thinge-search:

thinge\-search
==============

.. code-block:: none

    (thinge-search <type> <pattern> [<limit>])

Like ``(thinge-find)``, will search through the type of thinges specified, but unlike find this function returns a summary of multiple matches. The ``limit`` argument may be used to change the number of matches shown (10 by default).

Search patterns are unanchored, case-insensitive regular expressions.

.. _function-thinge-thinge-tag:

thinge\-tag
===========

.. code-block:: none

    (thinge-tag <type> <id> <tag> [<tag> ...])

Tags the specified thinge with the given list of tags. Tags will also start with a ``#`` character - if you don't supply it, it will be added automatically before saving the tag.

.. _function-thinge-thinge-types:

thinge\-types
=============

.. code-block:: none

    (thinge-types)

Lists the current types of thinges which have collections.

.. _function-thinge-thinge-untag:

thinge\-untag
=============

This function is not yet documented.

