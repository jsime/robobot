.. _module-memo:

memo
****

Allows for saving short memos to be delivered to other users when they are next observed by the bot.

.. _function-memo-memo:

memo
====

.. code-block:: none

    (memo <nick> <message>)

*Examples:*

.. code-block:: clojure

    (memo Beauford "update your jira tickets!")

Saves the message as a memo for the given nick, to be delivered to them when the bot next sees them speak.

