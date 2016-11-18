.. _module-taskman:

taskman
*******

Provides functions for interacting with OmniTI's task tracking system.

In addition to exported functions, this module inserts a pre-hook into the message processing pipeline which looks for any substrings matching the regular expression ``tid(\d+)`` and automatically replies with a direct link to the Taskman post(s) mentioned.

.. _function-taskman-tid:

tid
===

.. code-block:: none

    (tid <task ID>)

Displays task summary for the given ID.

