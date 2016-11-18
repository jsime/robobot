.. _module-locations:

locations
*********

Provides functions for tracking where you are and allowing other users on your chat network to display that information. Channels members may record that they are working remote, or at one campus or another, out on vacation, or many other possibilities. This information is then available for other channel members without having to ping the user directly.

.. _function-locations-set-location:

set\-location
=============

.. code-block:: none

    (set-location <location> [<detailed message>])

*Examples:*

.. code-block:: clojure

    (set-location "Vancouver Campus" "I'll be working out of Vancouver HQ for the week.")

Sets your most recent location, along with an optional message, which others may view with the (where-is) function.

.. _function-locations-where-is:

where\-is
=========

.. code-block:: none

    (where-is <nick>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2-4

    (where-is Beauford)
    Beauford: Vancouver Campus
    I'll be working out of Vancouver HQ for the week.
    Last updated: Thursday, 28th April 2016 at 11:15am

Displays the last-registered location for <nick>, along with any optional message they may have left.

