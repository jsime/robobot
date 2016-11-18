.. _module-fortune:

fortune
*******

Exports functions for displaying random selections from the ``fortune`` program commonly found on Un*x-y systems.

The fortunes displayed are generally limited to those under a couple hundred characters.

.. _function-fortune-bofh:

bofh
====

.. code-block:: none

    (bofh)

Returns fortunes from just the BOFH Excuses collection. Useful when production just went down hard and laughter is all you have left before being shown the door.

.. _function-fortune-fortune:

fortune
=======

.. code-block:: none

    (fortune)

Selects at random a collection from a relatively non-offensive list of fortune databases, and returns a random fortune. None of the fortune collections overlap with the more specific functions also exported by this module.

.. _function-fortune-startrek:

startrek
========

.. code-block:: none

    (startrek)

Returns a random Star Trek quote from the fortune database.

.. _function-fortune-zippy:

zippy
=====

.. code-block:: none

    (zippy)

Returns a random Zippy the Pinhead quote from the fotune database.

