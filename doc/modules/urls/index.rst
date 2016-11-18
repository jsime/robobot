.. _module-urls:

urls
****

Provides functions related to URLs.

In addition to exported functions, this module inserts a pre-hook into the message processing pipeline which looks for any URLs in messages others have sent. Any URLs that are detected are retrieved automatically and an attempt is made to locate a page title. Redirects are also logged.

If either a page title or any redirects are found, they are displayed back in the channel.

A timeout on all URL retrievals is set to prevent poorly behaving websites from delaying subsequent message processing. If the timeout is reached, all further URL detection and page title lookup is skipped for the current message.

.. _function-urls-shorten-url:

shorten\-url
============

.. code-block:: none

    (shorten-url <url>)

*Examples:*

.. code-block:: clojure
    :emphasize-lines: 2

    (shorten-url "http://images.google.com/really-long-image-url.jpg?with=plenty&of=tracking&arguments=foo123")
    "http://tinyurl.com/foObar42"

Returns a short version of a URL for easier sharing.

