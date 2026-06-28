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

local CITEPROC_CLASSES = {
  ["references"] = true, ["csl-bib-body"] = true, ["csl-entry"] = true,
}

local function is_citeproc_div(div)
  for _, c in ipairs(div.classes) do
    if CITEPROC_CLASSES[c] then return true end
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

function Div(div)
  if is_citeproc_div(div) then
    return div.content
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
  if not is_crossref then
    return nil
  end

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