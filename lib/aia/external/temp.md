If you want to find out which classes have inherited from a class named `Tool`, you can leverage Ruby's `ObjectSpace` module to iterate through all the classes and select those that are descendants of `Tool`. Here's how you could write the code:

```ruby
class Tool
  # Tool class implementation
end

# Other classes that inherit from Tool
class Hammer < Tool; end
class Screwdriver < Tool; end
class Wrench < Tool; end

# Non-inheriting classes
class RandomClass; end

def find_descendants_of(klass)
  ObjectSpace.each_object(Class).select { |c| c < klass }.map(&:name)
end

# Get the list of class names that inherit from Tool
descendant_classes = find_descendants_of(Tool)

# Format the list as markdown (as required)
markdown_list = descendant_classes.map { |name| "- #{name}" }.join("\n")
puts markdown_list
```

When you run this code, you will get an output similar to the following (the actual order may vary):

```
- Hammer
- Screwdriver
- Wrench
```

This list shows the class names that have inherited from the `Tool` class, and it is formatted as a markdown list without enclosing backticks as requested.

