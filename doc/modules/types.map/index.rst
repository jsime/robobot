.. _module-types.map:

types.map
*********

Provides functions for creating and manipulating unordered maps.

.. _function-types.map-assoc:

assoc
=====

.. code-block:: none

    (assoc <map> [<key> [<value>] [<key> [<value>] ...]])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (assoc { :old-key "foo" } :new-key "bar")
    { :old-key "foo" :new-key "bar" }

Returns a new map containing the existing keys and values, as well as any new key-value pairs provided. Values default to undefined, and keys that already exist will have their values replaced.

Multiple key-value pairs may be provided. Providing no new key-value pairs will simply return the existing map.

.. _function-types.map-keys:

keys
====

.. code-block:: none

    (keys <map>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (keys { :first-name "Bobby" :last-name "Sue" })
    (:first-name :last-name)

Returns a list of keys from the given map, in no guaranteed order.

.. _function-types.map-values:

values
======

.. code-block:: none

    (values <map>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (keys { :first-name "Bobby" :last-name "Sue" })
    ("Bobby" "Sue")

Returns a list of values from the given map, in no guaranteed order.

