.. _module-pagerduty:

pagerduty
*********

Exports functions for interacting with PagerDuty API, and subscribing to alarm notices.

API Keys for Pagerduty are currently part of the on-disk configuration file for the bot, and as such there are no functions for adding/removing/changing oncall groups or adding new Pagerduty accounts without restarting the bot. This will likely change in a future release to make things easier for users to manage.

.. _function-pagerduty-pagerduty-groups:

pagerduty\-groups
=================

.. code-block:: none

    (pagerduty-groups)

Displays the list of PagerDuty contact groups which currently have API keys configured.

.. _function-pagerduty-pagerduty-oncall:

pagerduty\-oncall
=================

.. code-block:: none

    (pagerduty-oncall <group> [<message>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2-5

    (pagerduty-oncall netops "I can't get a route from bastion to staging, help!")
    PagerDuty On-Call for Network Operations:
    Primary: Bobby Jo <bobby@nowhere.tld>
    Secondary: Janey Sue <janey@nowhere.tld>
    <Beauford> I can't get a route from bastion to staging, help!

Displays on-call information for the named group, based on the current schedule in PagerDuty. All remaining arguments after the group name, if provided, will be echoed back.

Calls to the on-call scheduling API at Pagerduty are cached briefly (for a few minutes per oncall group) to prevent flooding their servers should anyone in the channel call this function repeatedly.

