/*
Copyright (c) 2017-2020 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

/**
 * Class-based object ownership system
 *
 * Description:
 * Object ownership system similar to Delphi's. All classes deriving from Owner
 * can store references to objects implementing Owned interface (and other Owner
 * objects as well). When an owner is deleted, its owned objects are also deleted.
 *
 * This module is not compatible with GC-collected objects. It can be used only with
 * dlib.core.memory. Using it with objects allocated any other way will cause application to crash.
 *
 * Copyright: Timur Gafarov 2017-2020.
 * License: $(LINK2 https://boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: Timur Gafarov
 */
module dlib.core.ownership;

import dlib.core.memory;
import dlib.container.array;

/**
 * Interface for objects that can be owned, but not own other objects
 */
interface Owned
{
}

/**
 * Basic owner object class.
 * When you delete it, all owned object are automatically deleted
 */
class Owner: Owned
{
    protected Array!Owned ownedObjects;

    /**
     * Constructor. owner can be null, in this case object won't have an owner.
     * Such objects are called root owners and should be deleted manually.
     */
    this(Owner owner)
    {
        if (owner)
            owner.addOwnedObject(this);
    }

    /// Add owned object. Usually you don't have to do it explicitly, just pass the owner to constructor
    void addOwnedObject(Owned obj)
    {
        ownedObjects.append(obj);
    }

    /// Delete owned object without deleting object itself
    void clearOwnedObjects()
    {
        foreach(i, obj; ownedObjects)
            Delete(obj);
        ownedObjects.free();
    }

    /// Delete particular owned object, if it is there
    void deleteOwnedObject(Owned obj)
    {
        if (ownedObjects.removeFirst(obj))
        {
            Delete(obj);
        }
    }

    /// Destructor
    ~this()
    {
        clearOwnedObjects();
    }
}