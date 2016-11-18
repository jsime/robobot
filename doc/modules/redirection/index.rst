.. _module-redirection:

redirection
***********

Provides functions for modifying the recipient(s) of function output.

.. _function-redirection-to-channel:

to\-channel
===========

.. code-block:: none

    (to-channel <channel name> <value> [<value> ...])

*Examples:*

.. code-block:: clojure

    (to-channel #boringchannel "Join us over in #superfunchannel!")

Redirects output to a specific channel. Must be on the same server. All input values are passed through unchanged.

.. _function-redirection-to-nick:

to\-nick
========

.. code-block:: none

    (to-nick <recipient name> <value> [<value> ...])

*Examples:*

.. code-block:: clojure

    (to-nick dungeonmaster (join ": " "I roll stealth" (roll 20 1)))

Redirects output to a private message delivered to the given nick. Must be on the same server. All input values are passed through unchanged.

