angular.module('app').directive 'catalogGraph', [ '$rootScope', ($rootScope) ->
  d3 = require 'd3'

  # We restrict its use to an element
  # as usually <catalog-graph> is semantically
  # more understandable
  restrict: 'E'

  #this is important,
  #we don't want to overwrite our directive declaration
  #in the HTML mark-up
  replace: false
  scope:
    resources: '='
    edges: '='
    onClick: '&'

  link: (scope, element, attrs) ->
    hashString = (s) ->
      s.split('').reduce ((a, b) ->
        a = ((a << 5) - a) + b.charCodeAt(0)
        a & a
      ), 0
    height = 500
    color = d3.scale.category20()
    svg = d3.select(element[0]).append('svg').attr('height', height)

    # Arrow marker
    svg.append 'defs'
      .append 'marker'
      .attr 'id', 'markerArrow'
      .attr 'viewBox', '0 -5 10 10'
      .attr 'refX', 11
      .attr 'refY', 0
      .attr 'markerWidth', 6
      .attr 'markerHeight', 6
      .attr 'orient', 'auto'
      .append 'path'
      .attr 'd', 'M0,-5L10,0L0,5'
    force = d3.layout.force().charge(-250).linkDistance(60).size([
      svg.node().offsetWidth
      svg.node().offsetHeight
    ]).nodes(scope.resources).links(scope.edges).start()

    link = svg.selectAll '.link'
      .data edges
      .enter()
      .append 'line'
      .attr 'class', (l) ->
        'link ' + l.relationship

    nodes = svg.selectAl '.node'
      .data resources
      .enter()
      .append 'g'
      .attr 'class', 'node'
      .call force.drag

    nodeRects = nodes.append('rect').attr('rx', 5).attr('ry', 5).style('fill', (d) ->
      color hashString(d.type)
    )
    nodeRects.append('title').text (d) ->
      d.type + '[' + d.title + ']'

    nodes.append('text').text (d) ->
      d.type

    nodes.append('text').attr('y', 15).text (d) ->
      d.title

    nodes.on 'click', (r) ->
      scope.onClick item: r

    nodes.each (d) ->
      # Set rect size to fit text content
      textBounds = @getBBox()

      #var textBounds = d3.select(this).selectAll('text').node().getBBox();
      rectWidth = textBounds.width + 8
      rectHeight = textBounds.height + 4
      rect = d3.select(this).select('rect')
      rect.attr 'width', rectWidth
        .attr 'height', rectHeight
        .attr 'x', -rectWidth / 2
        .attr 'y', -10

      # Create line segments for line intersection calculation
      bounds = @getBBox()
      bounds.x2 = bounds.x + bounds.width
      bounds.y2 = bounds.y + bounds.height
      d.edge =
        left: new geo.LineSegment(bounds.x, bounds.y, bounds.x, bounds.y2)
        right: new geo.LineSegment(bounds.x2, bounds.y, bounds.x2, bounds.y2)
        top: new geo.LineSegment(bounds.x, bounds.y, bounds.x2, bounds.y)
        bottom: new geo.LineSegment(bounds.x, bounds.y2, bounds.x2, bounds.y2)

    force.on 'tick', ->
      link.attr('x1', (d) ->
        d.source.x
      ).attr('y1', (d) ->
        d.source.y
      ).each (d) ->
        x = d.target.x
        y = d.target.y
        line = new geo.LineSegment(d.source.x, d.source.y, x, y)
        d.target.edge.forEach (e) ->
          ix = line.intersect(d.target.edge[e].offset(x, y))
          if ix.in1 and ix.in2
            x = ix.x
            y = ix.y

        d3.select(this).attr('x2', x).attr 'y2', y


      #link.attr('x1', function(d) { return d.source.x; })
      #          .attr('y1', function(d) { return d.source.y; })
      #          .attr('x2', function(d) { return d.target.x; })
      #          .attr('y2', function(d) { return d.target.y; });
      nodes.attr 'transform', (d) ->
        'translate(' + d.x + ',' + d.y + ')'
]

angular.module('app').controller 'NodeCatalogCtrl', ($scope, $routeParams, PuppetDB) ->
  resourceIndex = (resources, type, title) ->
    index = undefined
    if resources.some((resource, i, array) ->
      if resource.title is title and resource.type is type
        index = i
        return true
      false
    )
      index
    else
      throw new Error("Resource not found: #{type} #{title}")

  $scope.showDetail = (r) ->
    $scope.$apply ->
      $scope.resource = r
    console.log r

  # normalize the relationship types that are reversed
  PuppetDB.query('catalogs/' + $routeParams.node, {}).success((data) ->
    result = angular.fromJson(data)
    resources = result.data.resources
    edges = result.data.edges.map((edge) ->
      if edge.relationship is 'subscription-of'
        return (
          target: resourceIndex(resources, edge.source.type, edge.source.title)
          source: resourceIndex(resources, edge.target.type, edge.target.title)
          relationship: 'notifies'
          weight: 1
        )
      if edge.relationship is 'required-by'
        return (
          target: resourceIndex(resources, edge.source.type, edge.source.title)
          source: resourceIndex(resources, edge.target.type, edge.target.title)
          relationship: 'before'
          weight: 1
        )
      source: resourceIndex(resources, edge.source.type, edge.source.title)
      target: resourceIndex(resources, edge.target.type, edge.target.title)
      relationship: edge.relationship
      weight: 1
    )
    $scope.resources = resources
    $scope.edges = edges
  ).error (data) ->
    alert data
