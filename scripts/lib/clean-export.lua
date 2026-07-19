local function env_or(name, default)
  local v = os.getenv(name)
  if v == nil or v == "" then return default end
  return v
end

local REFERENCES_HEADING  = env_or("EXPORT_REFERENCES_HEADING", "References")
local REFERENCES_NUMBERED = env_or("EXPORT_REFERENCES_NUMBERED", "0") == "1"

local function strip_outer_emph(block)
  if block.t ~= "Para" and block.t ~= "Plain" then
    return block
  end

  local new_inlines = {}
  for _, el in ipairs(block.content) do
    if el.t == "Emph" then
      for _, inner in ipairs(el.content) do
        table.insert(new_inlines, inner)
      end
    else
      table.insert(new_inlines, el)
    end
  end

  local ctor = block.t == "Para" and pandoc.Para or pandoc.Plain
  return ctor(new_inlines)
end

local THEOREM_CLASSES = {
  ["definition"] = true, ["theorem"] = true, ["lemma"] = true,
  ["proposition"] = true, ["corollary"] = true, ["example"] = true,
  ["remark"] = true, ["note"] = true,
}

local function is_theorem_div(div)
  for _, c in ipairs(div.classes) do
    if THEOREM_CLASSES[c] then return true end
  end
  return false
end

local BIBLIOGRAPHY_CONTAINER_CLASSES = {
  ["references"] = true, ["csl-bib-body"] = true,
}

local function is_bibliography_container(div)
  for _, c in ipairs(div.classes) do
    if BIBLIOGRAPHY_CONTAINER_CLASSES[c] then return true end
  end
  return false
end

local function is_csl_entry(div)
  for _, c in ipairs(div.classes) do
    if c == "csl-entry" then return true end
  end
  return false
end

local function clean_theorem_block(block)
  if block.t == "BulletList" or block.t == "OrderedList" then
    local new_items = {}
    for _, item in ipairs(block.content) do
      local new_item = {}
      for _, b in ipairs(item) do
        table.insert(new_item, strip_outer_emph(b))
      end
      table.insert(new_items, new_item)
    end
    if block.t == "BulletList" then
      return pandoc.BulletList(new_items)
    else
      return pandoc.OrderedList(new_items)
    end
  end
  return strip_outer_emph(block)
end

local function flatten_csl_spans(inlines)
  local out = {}
  for _, el in ipairs(inlines) do
    if el.t == "Span" then
      local is_left_margin = false
      for _, c in ipairs(el.classes) do
        if c == "csl-left-margin" then is_left_margin = true end
      end
      if is_left_margin and REFERENCES_NUMBERED then
        -- drop the "[1] " marker entirely; the Markdown list supplies it
      else
        for _, inner in ipairs(el.content) do
          table.insert(out, inner)
        end
      end
    else
      table.insert(out, el)
    end
  end
  return out
end

local function flatten_csl_entry_div(div)
  local blocks = {}
  for _, block in ipairs(div.content) do
    if block.t == "Para" or block.t == "Plain" then
      local inlines = flatten_csl_spans(block.content)
      local ctor = block.t == "Para" and pandoc.Para or pandoc.Plain
      table.insert(blocks, ctor(inlines))
    else
      table.insert(blocks, block)
    end
  end
  return blocks
end

function Div(div)
  if is_bibliography_container(div) then
    if REFERENCES_NUMBERED then
      local items = {}
      for _, block in ipairs(div.content) do
        table.insert(items, { block })
      end
      if #items > 0 then
        return pandoc.OrderedList(items)
      end
      return {}
    end

    return div.content
  end

  if is_csl_entry(div) then
    return flatten_csl_entry_div(div)
  end

  if not is_theorem_div(div) then
    return nil
  end

  local new_blocks = {}
  for _, block in ipairs(div.content) do
    table.insert(new_blocks, clean_theorem_block(block))
  end

  return pandoc.BlockQuote(new_blocks)
end

function Header(el)
  if #el.content == 1 and el.content[1].t == "Str"
     and (el.content[1].text == "Bibliography" or el.identifier == "bibliography") then
    return pandoc.Header(el.level, { pandoc.Str(REFERENCES_HEADING) }, el.attr)
  end
  return nil
end

local function strip_html_tags(s)
  local inner = s:match(">(.-)<")
  if not inner then return s end
  inner = inner:gsub("^%[", ""):gsub("%]$", "")
  return inner
end

function RawInline(el)
  if el.format == "html" then
    if el.text:match("^<a ") then
      return pandoc.Str(strip_html_tags(el.text))
    end
    return {}
  end
  if el.format == "latex" then
    local label = el.text:match("\\ref%{(.-)%}")
      or el.text:match("\\autoref%{(.-)%}")
      or el.text:match("\\nameref%{(.-)%}")
      or el.text:match("\\eqref%{(.-)%}")
    if label then
      return pandoc.Str(label)
    end
    if el.text:match("^\\") then
      return {}
    end
  end
  return nil
end

function RawBlock(el)
  if el.format == "html" or el.format == "latex" then
    return {}
  end
  return nil
end

function Link(el)
  local is_crossref = false
  for _, kv in ipairs(el.attributes or {}) do
    if kv[1] == "reference-type" then is_crossref = true end
  end
  if not is_crossref and el.target:match("^#") then
    is_crossref = true
  end
  if is_crossref then
    local content = el.content
    if #content == 1 and content[1].t == "Str" then
      local text = content[1].text
      local bare = text:match("^%[(.-)%]$")
      if bare then
        return pandoc.Str(bare)
      end
    end
    return content
  end

  for _, c in ipairs(el.classes or {}) do
    if c == "uri" then
      return pandoc.Link({ pandoc.Str(el.target) }, el.target, el.title)
    end
  end

  return nil
end
