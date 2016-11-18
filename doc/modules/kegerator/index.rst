.. _module-kegerator:

kegerator
*********

Provides functions for monitoring and querying kegerator status. Currently only supports OmniTI Kegerator API.

.. _function-kegerator-ontap:

ontap
=====

.. code-block:: none

    (ontap [<tap number>])

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2-5,8

    (ontap)
    Tap 1: Tasmanian IPA (TIPA) (IPA - American) by Schlafly - The Saint Louis Brewery, Saint Louis, MO - 7.2% ABV, 93% remaining
    Tap 2: Resurrection (Brown Ale - Belgian) by The Brewer's Art, Baltimore, MD - 7.0% ABV, 97% remaining
    Tap 3: K-9 Cruiser Winter Ale (Winter Ale) by Flying Dog Brewery, Frederick, MD - 7.4% ABV, 84% remaining
    Tap 4: Crisp Apple (Cider) by Angry Orchard Cider Company, Cincinnati, OH - 5.0% ABV, 69% remaining

    (ontap 3)
    Tap 3: K-9 Cruiser Winter Ale (Winter Ale) by Flying Dog Brewery, Frederick, MD - 7.4% ABV, 84% remaining

Invoked with no arguments, displays the list of beers currently on tap. When invoked with a tap number, displays detailed information on the beer available on that tap.

