.. _module-bot:

bot
***

Exports functions returning information about the bot and its environment.

.. _function-bot-channel-list:

channel\-list
=============

.. code-block:: none

    (channel-list [<network name>])

*Examples:*

.. code-block:: clojure

    (channel-list freenode)

Returns a list of the channels on the current network which the bot has joined. If provided a network name, will return the list of channels on that network instead. The network name must be one from the list provided by ``(network-list)``.

.. _function-bot-network-list:

network\-list
=============

.. code-block:: none

    (network-list)

Returns a list of the networks to which the current instance of the bot is connected.

.. _function-bot-version:

version
=======

.. code-block:: none

    (version)

Returns a string with the bot's version number.

