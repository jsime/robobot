.. _module-channellink:

channellink
***********

Allows for echoing messages across different channels, even across networks.

Linked channels require the bot to exist in both. Messages sent by users of one channel will be echoed to the other by the bot. When possible (network features permitting), the names of the original senders will be included in the echoed output.

The linked channels do not need to be on the same network, but they must be connected to by the same instance of the bot.

.. _function-channellink-channel-links:

channel\-links
==============

.. code-block:: none

    (channel-links)

Displays the current list of channels to which the current channel is linked.

.. _function-channellink-link-channels:

link\-channels
==============

.. code-block:: none

    (link-channels <network> <channel>)

*Examples:*

.. code-block:: clojure

    (link-channels freenode #mysecrethideout)

Links the current channel with the named channel, so that all messages appearing in one are echoed to the other.

The link needs to be created only in one of the channels, as all links are bi-directional. Echoed messages will be sent by the bot, but will be prefaced with the string "<$network/$nick>" to indicate the original speaker and their location. The channel name will assume a leading ``#`` in the event you do not provide one (you cannot link one channel with a direct message).

For a list of networks and channels, refer to ``(network-list)`` and ``(channel-list)``, respectively.

.. _function-channellink-unlink-channels:

unlink\-channels
================

.. code-block:: none

    (unlink-channels <network> <channel>)

*Examples:*

.. code-block:: clojure

    (unlink-channels freenode #mysecrethideout)

Removes the link with the named channel. As all links are bi-directional, this function needs to be called only from one side to tear down the full link.

