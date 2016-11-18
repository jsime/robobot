.. _module-karma:

karma
*****

Modifies and displays karma/reputation points.

In addition to the exported functions, this module inserts a pre-hook into the message processing pipeline which looks for any karma giving/taking. Any substrings in messages which match ``nick++`` or ``nick--`` are extracted and used to automatically increment or decrement, respectively, the named person's global karma.

A user's karma is calculated using a weighted formula that discourages a single benefactor or detractor from completely dominating their target's reputation. It is not a simple integer. Though this module would be much less obtuse if it were, because karma currently calculates pretty weirdly in some circumstances. The end goal is for the number of distinct benefactors/detractors to matter more than the number of grants/revokes performed by a single entity. Stated another way, "more distinct people liking me is more powerful than one person really hating me."

.. _function-karma-++karma:

\+\+karma
=========

.. code-block:: none

    (++karma <nick>)

The explicit function call version of incrementing the named person's karma.

.. _function-karma---karma:

\-\-karma
=========

.. code-block:: none

    (--karma <nick>)

The explicit function call version of decrementing the named person's karma.

.. _function-karma-karma:

karma
=====

.. code-block:: none

    (karma [<nick> [<nick> ...]])

Displays the named person's current karma. Multiple nicks may be provided and they will all have their karma displayed.

.. _function-karma-karma-leaders:

karma\-leaders
==============

.. code-block:: none

    (karma-leaders)

Displays the highest reputation users on the current network. Any ties are sorted alphabetically.

