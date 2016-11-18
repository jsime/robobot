.. _module-skills:

skills
******

Provides functions for managing skillsets and user proficiency levels. These proficiencies can then be queried by other users on the same network to find help or advice.

.. _function-skills-describe-skill:

describe\-skill
===============

.. code-block:: none

    (describe-skill <skill name> <description>)

*Examples:*

.. code-block:: clojure

    (describe-skill PostgreSQL "An object-relational database management system.")

Permits the addition of a description to a skill. Descriptions are free-form strings, limited only by the current network's message length limits and formatting options. Because these descriptions are displayed every single time someone looks up the skill, it's recommended to keep them brief and to the point.

.. _function-skills-idontknow:

idontknow
=========

.. code-block:: none

    (idontknow <skill name>)

*Examples:*

.. code-block:: clojure

    (idontknow Perl)

Unregisters your proficiency in the named skill.

.. _function-skills-iknow:

iknow
=====

.. code-block:: none

    (iknow [<skill name> [<proficiency level>]])

*Examples:*

.. code-block:: clojure

    (iknow Perl novice)

Assigns a proficiency level to yourself for the named skill. If no skill is named, shows a list of all skills you possess (grouped by proficiency levels).

Skills which do not already exist will be automatically created. As such, it is recommended that users attempt to follow local naming conventions whenever possible.

.. _function-skills-relate-skills:

relate\-skills
==============

.. code-block:: none

    (relate-skills <skill name> <related skill name> [<related skill name> ...])

*Examples:*

.. code-block:: clojure

    (relate-skills PostgreSQL SQL)
    (relate-skills Puppet CM Python)

Relating two skills causes the related skill to be shown whenever the other is displayed. Related skills are not displayed with their registered users, but simply referenced as potentially interesting additional skills for the querier to investigate.

Multiple related skills may be listed and they will all, in turn, be connected to the original skill.

.. _function-skills-skill-add:

skill\-add
==========

.. code-block:: none

    (skill-add <skill name>)

*Examples:*

.. code-block:: clojure

    (skill-add Perl)

Adds a new entry to the skills database, without registering any proficiency level on your behalf. If the skill already exists, nothing is done.

Note that only skills with at least one registered user on the current network will be displayed when someone searches or displays the skill list.

.. _function-skills-skill-levels:

skill\-levels
=============

.. code-block:: none

    (skill-levels)

*Examples:*

.. code-block:: clojure

    (skill-levels)

Displays the list of proficiency levels available for use when registering your knowledge of a given skill. The proficiency levels are displayed in increasing order with brief descriptions of each one.

.. _function-skills-skills:

skills
======

.. code-block:: none

    (skills [<search string>])

*Examples:*

.. code-block:: clojure

    (skills)
    (skills sql)

Displays the list of all skills currently registered by at least one person on the current network, if called with no arguments. Each skill in the list will also be shown with the number of people who claim to have some proficiency.

If called with a string argument, that value will be used to display only those skills which contain the value as a substring. Searching is case-insensitive.

.. _function-skills-theyknow:

theyknow
========

.. code-block:: none

    (theyknow <nick>)

*Examples:*

.. code-block:: clojure

    (theyknow Beauford)

Displays all of the registered skills of the named person. You cannot modify another user's skills or proficiencies.

.. _function-skills-whoknows:

whoknows
========

.. code-block:: none

    (whoknows <skill name> [<skill name> ...])

*Examples:*

.. code-block:: clojure

    (whoknows Perl)
    (whoknows Perl Apache PostgreSQL)

For the named skill, displays all the users who have registered a proficiency. Users are grouped together by proficiency level and displayed in order. If the skill has a description or any related skills, those are listed as well.

If multiple skills are provided as arguments, then the intersection of users having registered proficiencies in them will be displayed.

