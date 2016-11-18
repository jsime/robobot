.. _module-logging:

logging
*******

Provides basic message logging and recall capabilities.

In addition to the exported functions, this module installs both pre and post hooks into the message processing pipeline for the purposes of logging all incoming and outgoing messages on all connected networks.

Logging functionality is enabled by default wherever the bot is connected, but it may be disabled per-channel using ``(disable-logging)`` and re-enabled by using ``(enable-logging)``. Any messages that occurred while logging was disabled are lost permanently, and any functions which require logging to be active will fail when it is disabled.

.. _function-logging-disable-logging:

disable\-logging
================

.. code-block:: none

    (disable-logging)

Disables logging any activity in the current channel until the ``(enable-logging)`` function is called.

Note that logging is enabled by default. Explicit disabling/enabling of logging is on a per-channel basis.

.. _function-logging-enable-logging:

enable\-logging
===============

.. code-block:: none

    (enable-logging)

Enables logging activity in the current channel if it had been previously turned off via ``(disable-logging)``. Does nothing is logging is already active in the current channel.

Note that logging is enabled by default. Explicit disabling/enabling of logging is on a per-channel basis.

.. _function-logging-last:

last
====

.. code-block:: none

    (last [:include-expressions] [<step>] [<nick>])

*Examples:*

.. code-block:: clojure

    (last)
    (last :include-expressions)
    (last 10 Beauford)

Returns a previous message uttered in the current channel. The ``step`` is how many messages backward to count, with ``1`` assumed and being the most recent message available. A nick is optional, but if provided will limit the messages considered to only those sent by the named user.

By default, any messages which had S-Expressions in them are skipped, but those may be included by adding the ``:include-expressions`` symbol.

.. _function-logging-search:

search
======

.. code-block:: none

    (search <pattern>)

Searches scrollback in the current channel for anything that matches ``pattern`` which may be a simple string or a regular expression. Returns the most recent matching entry.

.. _function-logging-seen:

seen
====

.. code-block:: none

    (seen <nick>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2,3

    (seen Beauford)
    Beauford was last observed on Thursday, April 28th, 2016 at 3:23 PM speaking in #robobot on the freenode network. Their last words were:
    <Beauford> This is a fake message for demonstration purposes only.

Reports the last time the given nick was observed saying something in any channel that has logging enabled.

