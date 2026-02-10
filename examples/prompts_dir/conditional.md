---
parameters:
  audience: developer
---
<% if audience == "developer" %>
Explain how Ruby's garbage collector works.
Include details about generational GC and object marking.
<% elsif audience == "manager" %>
Explain what garbage collection is in programming.
Focus on why it matters for application performance.
Keep it non-technical.
<% else %>
Explain what garbage collection means in programming
as if I were ten years old.
<% end %>

Keep your answer to one paragraph.
