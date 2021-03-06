
flatten_html = (html) ->
  ((html\gsub "%s+%<", "><")\match("^%s*(.-)%s*$"))

describe "web_sanitize.query.scan", ->
  import replace_html, scan_html from require "web_sanitize.query.scan_html"

  describe "scan_html", ->
    it "scans html with unclosed tag", ->
      visited = {}

      scan_html [[
        <div class="hello">
          </p>
        </div>
        </code>
        <span>
        <ul>hello
        </span>
        <pre>
        hello world
      ]], (stack) ->
        table.insert visited, stack\current!.tag

      -- it should also get the pre
      assert.same {"div", "ul", "span", "pre"}, visited

    it "gets content of dangling tags", ->
      visited = {}

      scan_html [[
        <div>one
        <span>two
      ]], (stack) ->
        table.insert visited,
          flatten_html stack\current!\outer_html!

      assert.same {
        "<span>two",
        "<div>one><span>two"
      }, visited

    it "scans attributes", ->
      expected = {
        div: {
          "data-dad": '"&'
          class: "blue"
          style: "height: 20px"
          readonly: true

          "data-dad"
          "CLASS"
          "style"
          "readonly"
        }
        hr: {
          allowfullscreen: true
          id: "divider"

          "id"
          "allowfullscreen"
        }
      }

      scan_html [[
        <div data-dad="&quot;&amp;" CLASS="blue" style="height: 20px" readonly>
          <hr id="divider" allowfullscreen />
        </div>
      ]], (stack) ->
        node = stack\current!
        assert.same expected[node.tag], node.attr

    it "scans text nodes", ->
      text_nodes = {}

      scan_html(
        "hello <span>world</span>"

        (stack) ->
          node = stack\current!
          if node.type == "text_node"
            table.insert text_nodes, node\inner_html!

        text_nodes: true
      )

      assert.same {
        "hello "
        "world"
      }, text_nodes

  describe "replace_html", ->
    it "replaces tag content", ->
      out = replace_html "<div>hello world</div>", (tag_stack) ->
        t = tag_stack[#tag_stack]
        t\replace_inner_html "%#{t\inner_html!}%"

      assert.same "<div>%hello world%</div>", out

    it "replaces tag content with overlaps, destructive", ->
      -- makes it longer
      out = replace_html "<div>hello <span>zone</span>world</div>", (tag_stack) ->
        t = tag_stack[#tag_stack]
        t\replace_inner_html "%%#{t\inner_html!}%%"

      assert.same "<div>%%hello <span>zone</span>world%%</div>", out

      -- makes it shorter
      out = replace_html "<div>hello <span>zone</span>world</div>", (tag_stack) ->
        t = tag_stack[#tag_stack]
        t\replace_inner_html "X"

      assert.same "<div>X</div>", out

    it "replaces consecutive tags" , ->
      out = replace_html "<div>1</div> <pre>2</pre> <span>3</span>", (tag_stack) ->
        t = tag_stack[#tag_stack]
        t\replace_inner_html "%%#{t\inner_html!}%%"

      assert.same "<div>%%1%%</div> <pre>%%2%%</pre> <span>%%3%%</span>", out

    it "replaces empty tag" , ->
      out = replace_html "<code></code>", (tag_stack) ->
        t = tag_stack[#tag_stack]
        t\replace_inner_html "%%hi%%"

      assert.same "<code>%%hi%%</code>", out

    it "replaces attributes", ->
      out = replace_html "<div>1</div> <pre height=59>2</pre> <span>3</span>", (stack) ->
        stack\current!\replace_attributes { color: "blue", x: [["]] }

      one_of = {
        [[<div x="&quot;" color="blue">1</div> <pre x="&quot;" color="blue">2</pre> <span x="&quot;" color="blue">3</span>]]
        [[<div color="blue" x="&quot;">1</div> <pre color="blue" x="&quot;">2</pre> <span color="blue" x="&quot;">3</span>]]
      }

      for thing in *one_of
        if thing == out
          assert.same thing, out
          return

      assert.same one_of[1], out

    it "replaces attributes with boolean attribute", ->
      out = replace_html "<iframe></iframe>", (stack) ->
        stack\current!\replace_attributes {
          allowfullscreen: true
        }

      assert.same "<iframe allowfullscreen></iframe>", out

    it "replaces attributes on void tag", ->
      out = replace_html "<div><hr /></div>", (stack) ->
        return unless stack\is "hr"
        stack\current!\replace_attributes {
          cool: "zone"
        }

      assert.same '<div><hr cool="zone"></div>', out

    it "mutates existing attributes", ->
      -- also strips the duplicates
      out = replace_html '<div a="b" b="c" a="whw" b="&amp;&quot;"></div>', (stack) ->
        node = stack\current!
        node.attr.color = "green"
        node\replace_attributes node.attr

      assert.same [[<div a="whw" b="&amp;&quot;" color="green"></div>]], out

    it "replaces content in text nodes", ->
      out = replace_html(
        "hello XX <span>worXXld</span>"

        (stack) ->
          node = stack\current!
          if node.type == "text_node"
            node\replace_outer_html node\outer_html!\gsub "XX", "leafo"

        text_nodes: true
      )

      assert.same "hello leafo <span>worleafold</span>", out

    it "converts links", ->
      out = replace_html(
        "one http://leafo and <a href='http://doop'>http://woop <span>http://oop</span></a>"

        (stack) ->
          node = stack\current!
          if node.type == "text_node" and not stack\is("a *, a")
            node\replace_outer_html node\outer_html!\gsub "(http://[^ <\"']+)", "<a href=\"%1\">%1</a>"

        text_nodes: true
      )

      assert.same [[one <a href="http://leafo">http://leafo</a> and <a href='http://doop'>http://woop <span>http://oop</span></a>]], out


  describe "NodeStack", ->
    it "adds slugs ids to headers", ->
      slugify = (str) ->
        (str\gsub("[%s_]+", "-")\gsub("[^%w%-]+", "")\gsub("-+", "-"))\lower!

      document = [[
        <section>
          <h1>Eating the right foods is right</h1>
          <p>How do do something right?/</p>
        </section>

        <section>
          <h2>The death of the gold coast</h2>
          <p>Good day fart</p>
        </section>
      ]]

      out = replace_html document, (stack) ->
        return unless stack\is "h1, h2"
        el = stack\current!
        el\replace_attributes {
          id: slugify el\inner_text!
        }

      assert.same [[
        <section>
          <h1 id="eating-the-right-foods-is-right">Eating the right foods is right</h1>
          <p>How do do something right?/</p>
        </section>

        <section>
          <h2 id="the-death-of-the-gold-coast">The death of the gold coast</h2>
          <p>Good day fart</p>
        </section>
      ]], out

    it "uses is and select", ->
      html = [[
        <div class="hello">
          <code>
            The line:
            <div>
              the <span class="cool">Here!</span>
            </div>
            end
          </code>
        </div>
      ]]

      hits = 0
      misses = 0

      scan_html html, (stack) ->
        if stack\is "span"
          hits += 1
          divs = stack\select "div"
          assert.same 2, #divs
        else
          misses += 1

      assert.same 1, hits
      assert.same 3, misses
