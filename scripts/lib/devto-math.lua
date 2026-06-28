function Math(el)
  local src = el.text

  if el.mathtype == "InlineMath" then
    return pandoc.RawInline(
      "markdown",
      "{% katex inline %}" .. src .. "{% endkatex %}"
    )
  else
    return pandoc.RawInline(
      "markdown",
      "{% katex %}" .. src .. "{% endkatex %}"
    )
  end
end