.. _module-markov:

markov
******

Analyzes channel messages and allows for creating markov chains based off chat history.

.. _function-markov-markov:

markov
======

.. code-block:: none

    (markov <nick | "*"> [<seed phrase>])

Creates a sentence using HMM heuristics, based on selected nick(s) chat history. Resulting grammar will be stilted, and the sentence will likely be nonsensical, but should roughly resemble the style of the chosen target. If no seed is chosen, a random one will be selected first from the chat history.

If the supplied nick is an asterisk ``*`` then markov modeling from all channel participants will contribute to the final output.

This function currently uses a very poorly implemented modeller and produces pretty awful output. Better implementations are welcome!

