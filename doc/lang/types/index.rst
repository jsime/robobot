.. include:: ../../common.defs

Types
*****

|RB| supports the concept of distinct data types, beyond just free-form strings
and various functions may expect, or only operate on, a given type. There is no
type system in |RB|, certainly not one that allows for type signatures on
functions and macros, so all type checking is loosely performed at run-time.

It is entirely possible to write a macro, for instance, that is provably wrong.
But the proof won't be provided until the macro blows up when you try to use it.

Functions
=========



Macros
======

Numerics
========

Strings
=======

.. _types-symbol:

Symbols
=======

.. _types-vector:

Vectors
=======

Vectors are lists of items, enclosed in square brackets::

    [a b c]

The preceding vector contains 3 items: ``a``, ``b``, and ``c``. Vectors may
contain any other type, even other vectors, as so::

    [a b [1 2 3] c]

There is no hard limit on nesting, nor do the types of every vector entry need
to match.

.. _types-set:

Sets
====

Sets, like :ref:`vectors <types-vector>`, are lists of items - except inside
vertical pipes.  Unlike a vector, a set will not contain any duplicate entries.
Constructing a set with::

    |1 2 3 3 3|

Will result in the set::

    |1 2 3|

Note that, unless quoted, entries are evaluated during assignment. So, creating
a set with a few numbers, for example, and an expression which returns one of
those same numbers, will not result in duplicate values, nor will the expression
itself be in the set (again, unless it was quoted). Thus::

    |1 2 3 (+ 1 2)|

Still results in the set::

    |1 2 3|

.. _types-map:

Maps
====

Lists of key-value pairs -- somewhat similar to dictionaries, hashes, and
associative arrays in other languages -- are supported in |RB| as maps. The map
keys are :ref:`symbols <types-symbol>` and the values may be of any type,
including nested structures that are evaluated according to all the normal
rules.

Maps are enclosed in curly braces::

    { :key-1 "value" :key-2 "another value" }

As mentioned, nested structures for the values are acceptable::

    { :some-key { :another-key (+ 1 2) } }

