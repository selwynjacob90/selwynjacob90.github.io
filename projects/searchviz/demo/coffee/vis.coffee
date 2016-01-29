
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 600

    @tooltip = CustomTooltip("search_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}

    @width_offset = 240
    @category_centers = {
      "People": {x: (@width / 10) + @width_offset, y: @height / 2.42},
      "Events": {x: (2 * @width / 10) + @width_offset, y: @height / 2.38},
      "Athletes": {x: (3 * @width / 10) + @width_offset, y: @height / 2.4},
      "Electronics": {x: (4 * @width / 10) + @width_offset, y: @height / 2.43},
      "Movies": {x: (@width / 10) + @width_offset, y: @height / 1.59},
      "Artists": {x: (2 * @width / 10) + @width_offset, y: @height / 1.59},
      "TV": {x: (3 * @width / 10) + @width_offset, y: @height / 1.59}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.12
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain(["low", "medium", "high"])
      .range(["#d84b2a", "#beccae", "#7aa25c"])

    # Using just one color for now
    @node_color = "#d1e0f3"

    @node_colors = {
      "People": "#8dd3c7",
      "Events": "#ffffb3",
      "Athletes": "#bebada",
      "Electronics": "#fb8072",
      "Movies": "#80b1d3",
      "Artists": "#fdb462",
      "TV": "#b3de69"
    }

    # use the max total_amount in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> parseInt(d.Points))
    @radius_scale = d3.scale.pow().exponent(0.5).domain([0, max_amount]).range([2, 45])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      node = {
        id: d.id
        radius: @radius_scale(parseInt(d.Points))
        value: d.Points
        name: d.Phrase
        rank: d.Rank
        category: d.Category
        queries: d.Queries
        x: Math.random() * 900
        y: Math.random() * 800
      }
      @nodes.push node

    @nodes.sort (a,b) -> b.value - a.value


  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    @labels = @vis.selectAll("text")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) -> that.node_colors[d.category] )
      .attr("stroke-width", 0)
      .attr("opacity", 0.8)
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    @labels.enter().append("text")
      .attr("fill", "black")
      .attr("text-anchor", "middle")
      .attr("font-family", "georgia")
      .text((d) -> d.name)

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)
    @labels.transition().duration(2000)
       .attr("font-size", (d) -> d.radius * .3) 
       .attr("textLength", (d) -> d.radius * 1.5)
       .attr("lengthAdjust", "spacingAndGlyphs")

  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.7)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)

        @labels.each(this.move_towards_center(e.alpha))
          .attr("x", (d) -> d.x)
          .attr("y", (d) -> d.y)
    @force.start()

    this.hide_categories()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each year. Does this by calling move_towards_category
  display_by_category: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.6)
      .on "tick", (e) =>
        @circles.each(this.move_towards_category(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
        @labels.each(this.move_towards_category(e.alpha))
          .attr("x", (d) -> d.x)
          .attr("y", (d) -> d.y)
    @force.start()

    this.display_categories()

  # move all circles to their associated @category_centers 
  move_towards_category: (alpha) =>
    (d) =>
      target = @category_centers[d.category]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display year titles
  display_categories: () =>
    
    cat_x = {
      "People": @width/6, 
      "Events": 2 * @width / 5, 
      "Athletes": 3.1 * @width /5,
      "Electronics": 4.3 * @width /5,
      "Movies" :@width/6,
      "Artists": 2 * @width / 5,
      "T.V" : 3.3 * @width /5
    }
    cat_data = d3.keys(cat_x)
    categories = @vis.selectAll(".categories")
      .data(cat_data)

    categories.enter().append("text")
      .attr("class", "categories")
      .attr("x", (d) => cat_x[d] )
      .attr("y", (d,i) => if i<4 then 40 else @height/1.7)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide year titiles
  hide_categories: () =>
    categories = @vis.selectAll(".categories").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Phrase:</span><span class=\"value\"> #{data.name}</span><br/>"
    content +="<span class=\"name\">Rank:</span><span class=\"value\"> #{addCommas(data.rank)}</span><br/>"
    content +="<span class=\"name\">Category:</span><span class=\"value\"> #{addCommas(data.category)}</span><br/>"
    content +="<span class=\"name\">Related Queries:</span><span class=\"value\"> #{data.queries}</span>"
    @tooltip.showTooltip(content,d3.event)


  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@node_color).darker())
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()
  root.display_cat = () =>
    chart.display_by_category()
  root.toggle_view = (view_type) =>
    if view_type == 'year'
      root.display_cat()
    else
      root.display_all()

  d3.csv "data/search.csv", render_vis
