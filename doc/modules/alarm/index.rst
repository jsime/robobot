.. _module-alarm:

alarm
*****

Exports functions for setting and modifying alarms, which can trigger messages at specified times or intervals.

In addition to the exported functions, this module maintains a collection of persistent AnyEvent timer objects which are used to fire the alarm messages asynchronously from any regular message processing.

.. _function-alarm-delete-alarm:

delete\-alarm
=============

.. code-block:: none

    (delete-alarm <alarm name>)

*Examples:*

.. code-block:: clojure

    (delete-alarm daily-standup)

Permanently removes the named alarm from the current channel. The alarm must be recreated from scratch if you wish to use it again.

.. _function-alarm-list-alarms:

list\-alarms
============

.. code-block:: none

    (list-alarms)

Displays all of the alarms for the current channel, as well as their current state (active or suspended) and their next triggering time. If the alarms are recurring that is noted with the recurrence interval.

.. _function-alarm-resume-alarm:

resume\-alarm
=============

.. code-block:: none

    (resume-alarm <alarm name>)

*Examples:*

.. code-block:: clojure

    (resume-alarm daily-standup)

Resumes a suspended alarm. Does nothing to alarms which are not currently suspended. A non-recurring alarm which had been suspended during the time at which it should have triggered is effectively deleted by resuming it. Recurring alarms will simply skip past any triggering intervals which passed during their suspension.

.. _function-alarm-set-alarm:

set\-alarm
==========

.. code-block:: none

    (set-alarm <alarm name> :first <ISO8601> [:recurring <interval>] [:exclude <pattern>] [<message>])

*Examples:*

.. code-block:: clojure

    (set-alarm daily-standup
      :first     "2016-04-25 10:00:00 US/Eastern"
      :recurring "1 day"
      :exclude   "Day=(Saturday|Sunday)"
      "Daily Standup time! Meet in the large conference room.")

Creates a new alarm in the current channel. The only required parameters are an alarm name and its first occurrence. An optional message may be included, which will be echoed whenever the alarm fires. Its length and formatting are limited only by the features of the network on which the alarm was set (e.g. IRC will generally be a couple hundred characters or less of plain text, whereas Slack would allow several KB of text with formatting).

The initial date and time of the alarm, specified with ``:first`` must be a valid ISO8601 formatted timestamp. The timezone is optional and will default to that of the server on which the bot is running if omitted. It must also be a date and time in the future.

Alarms may be set to recur by specifying an interval with ``:recurring``. The format of the interval (shockingly!) matches that of the interval type in PostgreSQL. Before the alarm is created, a test is performed to ensure that the alarm will not fire too often, as a small measure to prevent abuse. The alarm creation will be rejected if it will emit messages more than a few times an hour.

An exclusion pattern may also be specified with ``:exclude``. Any timestamps from the recurrence interval that match the exclusion patterns will be skipped. The format of the is a comma-separated list of ``<field>=<regular expression>`` and may use any of the PostgreSQL ``to_char(...)`` formatting fields.

.. _function-alarm-show-alarm:

show\-alarm
===========

.. code-block:: none

    (show-alarm <alarm name>)

*Examples:*

.. code-block:: clojure

    (show-alarm daily-standup)

Displays the named alarm and its current settings.

.. _function-alarm-suspend-alarm:

suspend\-alarm
==============

.. code-block:: none

    (suspend-alarm <alarm name>)

*Examples:*

.. code-block:: clojure

    (suspend-alarm daily-standup)

Temporarily suspends the named alarm.

