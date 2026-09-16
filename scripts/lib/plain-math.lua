-- plain-math.lua
--
-- Medium and Reddit render neither LaTeX nor KaTeX/MathJax (confirmed: Medium
-- has no math support at all when pasted, and Reddit has none either). Left
-- untouched, math would show up as raw "$x^2$" delimiters that mean nothing
-- to a reader there. This renders the original TeX source as inline code
-- instead, so it's at least legible as "this is a formula" rather than
-- broken syntax. It is a legibility fallback, not real math typesetting —
-- if precise rendering matters for a given chapter, export that formula as
-- an image instead.

function Math(el)
  return pandoc.Code(el.text)
end