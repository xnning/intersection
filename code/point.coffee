fix = (f) ->
  x = () ->
    f x
  x()

compose = (trait1, trait2) ->
  (self) ->
    Object.assign({}, trait1(self), trait2(self))

Point = (x, y) ->
  (self) ->
    { x: () ->
          x
      y: () ->
          self().z()
    }

Z = (z) ->
  (self) ->
    { z: () ->
          self().x()
    }

res = fix(compose(Point(100, 10), Z(1)))
