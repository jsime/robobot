.. _module-achievements:

achievements
************

Exports functions for creating and viewing chat achievements, which are much like the ridiculous fake-internet-point badges from video games.

Each achievement has a name, a description, and a SQL query which is run to determine whether a specific user has met the requirements to earn the badge.

In addition to the xported functions, the module inserts a post-hook into the message processing pipeline of RoboBot which retrieves the list of achievements not yet earned by the user whose message was just processed, executes each achievement's associated SQL query, and if the query returns a true value in the first column of the first row the hook then awards the achievement to the user and notifies them with a congratulatory message. For this reason, the queries used to determine achievement eligibility must execute quickly.

.. _function-achievements-achievements:

achievements
============

.. code-block:: none

    (achievements [<nick>])

*Examples:*

.. code-block:: clojure

    (achievements)
    (achievements Beauford)

Displays the achievements earned by the named user (or the current user if no name is supplied). The date on which the achievement was earned is displayed next to each one.

.. _function-achievements-add-achievement:

add\-achievement
================

.. code-block:: none

    (add-achievement <name> <description> <query>)

*Examples:*

.. code-block:: clojure

    (add-achievement
      Chatterbox
      "You love the sound of your own keyboard. You've sent 10,000 messages!"
      "select count(*) >= 10000 from logger_log where nick_id = ?")

Creates a new achievement. Achievements must have a name, a description, and a SQL query which is used to determine a person's eligibility. The query must return a true value in the first column of the first row to indicate that the user may earn the achievement. Anything else will consider the user ineligible at that time.

Achievements are currently earned only a single time. There is no support for recurring achievements (tiers/levels which increment).

Because the SQL query is executed every time a message is processed from a user who has not yet earned the achievement, they must be written for speed. The SQL query will receive a single bind variable: the ``nick_id`` of the user whose message was just processed.

.. _function-achievements-list-achievements:

list\-achievements
==================

.. code-block:: none

    (list-achievements)

Displays all achievements available, along with the number of people on the current network who have earned each one.

.. _function-achievements-show-achievement:

show\-achievement
=================

.. code-block:: none

    (show-achievement <achievement name>)

*Examples:*

.. code-block:: clojure

    (show-achievement Chatterbox)

Displays the details of the named achievement, along with a list of the people who have earned it and when they did so.

