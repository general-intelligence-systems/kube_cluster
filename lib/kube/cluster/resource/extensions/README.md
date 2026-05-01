<!--

Mate... I have no idea what the fuck this file is..... or who made it....
I really can't be arsed to read it either....

Someone please read it and let me know what the fuck it is...

-- Nathan K. 2026-05-01

-->

# Resource Extensions

Modules in this directory are dynamically mixed into `Kube::Cluster::Resource` instances at initialization time (via `extend`).

## Why modules instead of subclasses?

`Kube::Cluster["Deployment"]` returns a versioned schema class generated at runtime. Because these classes are versioned and generated dynamically, we can't subclass them directly -- there's no stable class to inherit from.

Instead, we define extension modules here and dynamically insert them when the resource is instantiated. In `Resource#initialize`, after the object is built, the matching extension module is applied:

```ruby
extend Extensions.const_get(kind) if Extensions.const_defined?(kind)
```

This gives us a way to add kind-specific behaviour to resource instances without coupling to any particular schema version.
