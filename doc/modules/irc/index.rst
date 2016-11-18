.. _module-irc:

irc
***

Provides a variety of functions for performing IRC-related actions like channel topics, oper promotion/demotion, etc.

.. _function-irc-topic:

topic
=====

.. code-block:: none

    (topic [<new topic>])

*Examples:*

.. code-block:: clojure

    (topic "Super Awesome Channel Fun Times")

When a new topic string is given, changes the channel\'s topic to that string. In all uses, returns the channel topic as a string.

