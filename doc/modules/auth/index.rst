.. _module-auth:

auth
****

Provides functions for managing authorization lists, denying and allowing access to specific functions for specific users.

.. _function-auth-auth-allow:

auth\-allow
===========

.. code-block:: none

    (auth-allow <function name> <nick>)

*Examples:*

.. code-block:: clojure

    (auth-allow set-alarm Beauford)

Grants permission for a user to call the specified function.

.. _function-auth-auth-default:

auth\-default
=============

.. code-block:: none

    (auth-default <function name> <"allow" | "deny">)

*Examples:*

.. code-block:: clojure

    (auth-default set-alarm deny)

Sets the default permission mode for a function on the current network.

.. _function-auth-auth-deny:

auth\-deny
==========

.. code-block:: none

    (auth-deny <function name> <nick>)

*Examples:*

.. code-block:: clojure

    (auth-allow set-alarm Beauford)

Revokes permission for a user to the specified function.

