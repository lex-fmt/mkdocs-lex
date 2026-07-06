# Code Rules, IMPORTANT

## 1. No tag acrobatics inside callables

If something is broken because it expect a different tag than what is sent, getting around the broken expectation by branching and converting that tag. is not the way to go. While python in particular has tag annotations, the're is no runtime enforcement and it's common to get unexpected data types. While the short term fix is massaging that into usable information, this leads into terrible codebases, where every function eventually does a long list of tag checks and fixes. Once this starts in the codebase, it spreads, because code calls another function that calls another...

The right solution is to fix the root cause, where does the tag surprise is coming from? In rare situations we don't have any control of inputs, in which cases we need to do tag unions and other formal ways to document this. But the usual fix involves finding the source code. If that happens, just report the issue.
Bad. bad python:

```python
def foo(bar:list):
    # NEVER DO THIS
    if isinstance (bar, str):
        bar = [""]
```

Unless we can't control the code, we need to make sure contracts are respected. it's not feasible to do arbitrary tag fixes inside every functions.

Good python: keeping code simple, predictable and finding the root cause of surprises:

```python

def foo(bar: list):
    assert isinstance ((bar, list)), "This method takes a list"

```

This way, you'll get an exception and can figure out the root cause.

## 2. Logging is good, logging is great

Everything is easier to debug with good logging, specially unforeseen issues.
Here's how to make sure you get logging right:

- Every module will have it's same logging infrastructure:

```python

import logging
logger = logging.getLogger(__name__)
```

Don't worry about setting levels or formatters. All this is runtime configurable and can be turned on or off as need arises.

Do worry about the log level of your events. Rules of thumb:

- INFO: should be sent on every flow of event (function enter, exception, recursion, etc), but simple a string listing the event (even if the string uses dynamics variables)
- DEBUG: should have the same visibility/ trigger than info, but includes data to debug, even if that data might be largish (we start by looking at the info levels, if we need more info, we set the runtime to the debug level)

## RST / sphinx ings in python

1. Title marker must be _longer_ than title

Wrong:
A Title

---

Right:

## A Title

### 2. Respect line width, 88 as basis for everything, including python code

#### Code blocks

You can't just embed python code, this is how to do it:

```text
def foo():
"""
Some text

    .. code-block:: python
    # <- must leave empty line ->
        class Foo: # entire code block must be indented
            pass
```

#### . Nested lists require a line break between them

Wrong:

1. Outer List
2. More of it
   1. Inner List

Right:

1. Outer List
2. More of it

   1. Inner List

#### \* and \*\* in doctrtings

Don't use "\*args or \*\*kwargs" as those can't be used without scaping, for
documenting callables just args and kwargs will suffice

#### links

refs must have an speace between the ref element and the linke, and NO espace between the link text and it's target ulr:

WRONG

:ref:`about expanders<expanding>`. # no space betwen :ref: and `:ref:`about expanders <expanding>`. # space between expanders and <expanding>

## Best practices for this codebase

## Domain Knowledge

### Imports and namespaces

We curate namespaces carefully to keep a concise and easy to use choice for users. Thus rarely we do full path imports, usually it's on the package namespace of the package's parent , so check that.

For example, the vector are accessible by `sprinkles.vectors.EmailType` not through the email.py file.

### Registries

This code base uses registries extensively, since it allows user extensible types and components with a scalar interface without having to pass dependency injection everywhere.

There is a hierarchy of registries (libraries):

- library.library.BaseLib: has a tag agnostic store and is the base class for the others. This is used for the parsers, validators and convertors registry, since we don't create instances there
- library.lib.GenericTypeLib: has some tuning for using a class / tag library, which include instantiating classes (can use arbitrary and dynamic init parameters), generating tag catalogs and instantiating full trees with dependent types. This is the basic registry for the BaseTypes and Extenders, and takes care of constructing nested instances .
- core.lib.TypeLib: registers all BaseTypes, and does much of the heavy lifting, including generating the tag catalogs for the parsers.
- expanders.core.lib.ExtenderLib: stores the `*Extender` types , which also require nested constructors.

### Lang / Parsers

Sprinkles is fundamentally a lib for create verified types with data validation and flexible constraints from user generated data.
Hence a large part of the library is about parsing.

There are two langs in sprinkles:

- Type Type DLS: the developer provides the description of the data we expect to check. This includes vector types like lists and maps.
- Input strings: here, paired with a tag we do the main work for the function.

Each language has it's parser(s), which are versioned and can be swapped and tests side by side using the ParserLib.get('name').

sprinkles.lang.tag.TypeLang generates the TypeDefinition catalog: tokens parsers need to parse, and the list of types and their particularities .
