.. _module-github:

github
******

Provides functions for interacting with Github APIs, including watching for repository related events.

A poor man's alternative to simply enabling Github's built-in chat notifiers.

.. _function-github-github-list:

github\-list
============

.. code-block:: none

    (github-list)

Displays the list of Github projects being watched in the current channel.

.. _function-github-github-unwatch:

github\-unwatch
===============

.. code-block:: none

    (github-unwatch <project url>)

*Examples:*

.. code-block:: clojure

    (github-unwatch https://github.com/jsime/robobot)

Removes the watcher for the given Github project in the current channel. If the same project is being watched in other channels as well, it will need to be removed from them separately.

.. _function-github-github-watch:

github\-watch
=============

.. code-block:: none

    (github-watch <project url>)

*Examples:*

.. code-block:: clojure

    (github-watch https://github.com/jsime/robobot)

Adds a watcher for the current channel on the given Github project. The watcher will periodically poll the Github APIs for commit, issue, and other events and report them in the channel when they occur. If multiple events have occurred since the last reporting, they will be bundled together.

